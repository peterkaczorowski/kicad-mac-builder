#!/usr/bin/env python3
import argparse
import glob
import json
import logging
import os
import subprocess
import tempfile
from collections import namedtuple
import time
import sys
from urllib.request import urlopen

# Adam Wolf, Wayne and Layne

NotarizationStatus = namedtuple('NotarizationStatus', ['in_progress', 'success', 'logfile_url'])
# Why don't we use --deep when signing?
# From Apple: "Important: While the --deep option can be applied to a signing operation, this is not recommended. We recommend that you sign code inside out in individual stages (as Xcode does automatically). Signing with --deep is for emergency repairs and temporary adjustments only."

# TODO https vs http on timestamp server
# $ codesign --sign 19979257B20DF8A23378093D7F6A76EC209B82BE --deep --force --options runtime --timestamp=https://timestamp.apple.com/ts01 /Users/wolf/wnl/kicad/kicad-mac-builder/codesign-test2/test4/kicad.app/Contents/MacOS/dxf2idf
# /Users/wolf/wnl/kicad/kicad-mac-builder/codesign-test2/test4/kicad.app/Contents/MacOS/dxf2idf: replacing existing signature
# [1]    26015 segmentation fault  codesign --sign 19979257B20DF8A23378093D7F6A76EC209B82BE --deep --force

# https://stackoverflow.com/questions/56890749/macos-notarize-in-script
# https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution/resolving_common_notarization_issues
# https://developer.apple.com/library/archive/technotes/tn2206/_index.html
# See https://glyph.twistedmatrix.com/2018/01/shipping-pygame-mac-app.html

# If you get segfaults when adding timestamps, try using the hex ID of your certificate, rather than the name.



logging.basicConfig()


def get_kicad_paths_for_signing(dotapp_path):
    to_sign = []
    for root, dirnames, filenames in os.walk(dotapp_path):
        for filename in filenames:
            if filename.endswith(".so") or filename.endswith(".dylib"):
                to_sign.append(os.path.join(root, filename))

    to_sign.extend(glob.glob(os.path.join(dotapp_path, "Contents/PlugIns/*.kiface")))
    to_sign.extend(glob.glob(os.path.join(dotapp_path, "Contents/PlugIns/sim/ngspice/*.cm")))
    to_sign.extend(glob.glob(os.path.join(dotapp_path, "Contents/PlugIns/sim/ngspice/scripts/*")))
    to_sign.append(os.path.join(dotapp_path,
                                "Contents/Frameworks/Python.framework/Versions/Current/bin/python2.7"))
    to_sign.append(os.path.join(dotapp_path,
                                "Contents/Frameworks/Python.framework/Versions/Current/lib/python2.7/config/libpython2.7.a"))
    to_sign.append(
        os.path.join(dotapp_path, "Contents/Frameworks/Python.framework/Versions/Current/bin/pythonw2.7"))
    to_sign.append(os.path.join(dotapp_path,
                                "Contents/Frameworks/Python.framework/Versions/Current/Resources/Python.app/Contents/MacOS/Python"))
    to_sign.append(
        os.path.join(dotapp_path, "Contents/Frameworks/Python.framework/Versions/Current/Resources/Python.app"))
    to_sign.append(os.path.join(dotapp_path, "Contents/Frameworks/Python.framework"))

    with os.scandir(os.path.join(dotapp_path, "Contents", "MacOS")) as entries:
        # we have to sign kicad last
        kicad_entry = None
        for entry in entries:
            if entry.name == "kicad":
                kicad_entry = entry
                continue
            to_sign.append(entry.path)
        if kicad_entry:
            to_sign.append(kicad_entry.path)
    to_sign.append(dotapp_path)

    return to_sign


def sign(dotapp_path, key_label, entitlements_path=None, timestamp_url=None):
    logging.info("Signing {}".format(dotapp_path))
    start_time = time.monotonic()
    for path in get_kicad_paths_for_signing(dotapp_path):
        sign_file(path, key_label, entitlements_path, timestamp_url)
    elapsed_time = time.monotonic() - start_time
    logging.debug("Signing took {} seconds".format(elapsed_time))


def sign_file(path, key_label, entitlements_path=None, timestamp_url=None):
    cmd = ["codesign", "--sign", key_label, "--force", "--options", "runtime"]
    if entitlements_path:
        cmd.extend(["--entitlements", entitlements_path])
    if timestamp_url:
        cmd.append("--timestamp={}".format(timestamp_url))
    cmd.append(path)
    logging.debug("Running {}".format(" ".join(cmd)))
    subprocess.run(cmd, check=True)


def has_secure_timestamp(path):
    logging.info("Checking {} has a secure timestamp".format(path))
    cmd = ["codesign", "-dvv", path]
    logging.debug("Running {}".format(" ".join(cmd)))
    completed = subprocess.run(cmd, capture_output=True, check=True)

    stderr = completed.stderr.decode('utf-8')
    if "Signed Time" in stderr:
        return False
    if "Timestamp=" not in stderr:
        return False
    return True


def make_zip(dotapp_path, output_path=None):
    if not output_path:
        tempdir = tempfile.mkdtemp()
        output_path = os.path.join(tempdir, "{}.zip".format(os.path.basename(dotapp_path)))

    logging.info("Making zip for submitting {} to Apple for notarization ({}).".format(dotapp_path, output_path))
    cmd = ["zip", "-r", output_path, dotapp_path]
    logging.debug("Running {}".format(" ".join(cmd)))
    subprocess.run(cmd, check=True)
    return output_path


def verify_signing(dotapp_path):
    logging.info("Verifying signing of {}".format(dotapp_path))
    logging.debug("Verifying with --strict")
    cmd = ["codesign", "-vvv", "--deep", "--strict", dotapp_path]
    logging.debug("Running {}".format(" ".join(cmd)))
    subprocess.run(cmd, check=True)

    check_timestamps = [dotapp_path]
    with os.scandir(os.path.join(dotapp_path, "Contents", "MacOS")) as entries:
        for entry in entries:
            check_timestamps.append(entry.path)
    for path in check_timestamps:
        if not has_secure_timestamp(path):
            raise Exception("{} does not have a secure timestamp".format(path))
        else:
            logging.debug("{} has a secure timestamp".format(path))


def submit_for_notarization(upload_path, primary_bundle_id, apple_developer_username,
                            apple_developer_keychain_password_name):
    # DO NOT PASS YOUR PASSWORD HERE!  Aim it at keychain using @keychain:entryname
    logging.info("Submitting {} for notarization.".format(upload_path))
    logging.info("This uploads it to Apple, and may take a few minutes depending upon size and upload speed.")

    cmd = ["xcrun", "altool", "--notarize-app",
           "--primary-bundle-id", primary_bundle_id,
           "--username", apple_developer_username,
           "--password", "@keychain:{}".format(apple_developer_keychain_password_name),
           "--file", upload_path]

    logging.debug("Running {}".format(" ".join(cmd)))
    start_time = time.monotonic()
    completed = subprocess.run(cmd, capture_output=True, check=True)
    elapsed_time = time.monotonic() - start_time
    logging.debug("It took {} seconds.".format(elapsed_time))
    stderr = completed.stderr.decode('utf-8')
    stdout = completed.stdout.decode('utf-8')

    if not stdout.startswith("No errors uploading "):
        raise Exception("Error submitting for notarization.")

    for line in stdout.splitlines():
        if line.startswith("RequestUUID = "):
            return line.split("=", maxsplit=1)[1].strip()
    raise Exception("No request UUID found in notarization submission response.")


def get_notarization_status(request_uuid, apple_developer_username, apple_developer_keychain_password_name):
    # DO NOT PASS YOUR PASSWORD HERE!  Aim it at keychain using @keychain:entryname
    logging.info("Checking notarization status for {}.".format(request_uuid))

    cmd = ["xcrun", "altool", "--notarization-info", request_uuid,
           "--username", apple_developer_username,
           "--password", "@keychain:{}".format(apple_developer_keychain_password_name)]

    logging.debug("Running {}".format(" ".join(cmd)))
    completed = subprocess.run(cmd, capture_output=True, check=True)
    stderr = completed.stderr.decode('utf-8')
    stdout = completed.stdout.decode('utf-8')

    if "Status: in progress" in stdout:
        return NotarizationStatus(in_progress=True, success=None, logfile_url=None)

    succeeded = None
    if "Status: success" in stdout:
        succeeded = True
    else:
        succeeded = False

    logfile_url = None
    for line in stdout.splitlines():
        if "LogFileURL:" in line:
            logfile_url = line.split(":", maxsplit=1)[1].strip()
            break

    return NotarizationStatus(in_progress=False, success=succeeded, logfile_url=logfile_url
                              )


def get_log(logfile_url):
    logging.info("Getting log from {}".format(logfile_url))
    logfile_bytes = urlopen(logfile_url).read()
    logfile_text = logfile_bytes.decode('utf-8')
    apple_log = json.loads(logfile_text)
    return apple_log


def wait_for_notarization(request_uuid, apple_developer_username, apple_developer_keychain_password_name):
    # DO NOT PASS YOUR PASSWORD HERE!  Aim it at keychain using @keychain:entryname
    delay = 30
    logging.info("Checking on notarization every {} seconds.".format(delay))
    start_time = time.monotonic()
    try:
        status = get_notarization_status(request_uuid, apple_developer_username, apple_developer_keychain_password_name)
    except subprocess.CalledProcessError:
        logging.warning("Error while checking notarization status.  This can happen if we check too soon after "
                        "submitting.")
        status = NotarizationStatus(in_progress=True, success=False, logfile_url=None)

    while status.in_progress:
        logging.debug("Notarization still in progress, waiting {} seconds...".format(delay))
        time.sleep(delay)
        status = get_notarization_status(request_uuid, apple_developer_username, apple_developer_keychain_password_name)
    elapsed_time = time.monotonic() - start_time
    logging.debug(
        "After {} seconds of checking, the notarization status is no longer 'in progress'. ".format(elapsed_time))

    if status.success:
        logging.info("Notarization successful.")
        apple_log_level = logging.DEBUG
    else:
        logging.info("Notarization FAILED.")
        apple_log_level = logging.ERROR

    apple_log = get_log(status.logfile_url)

    pretty_log = json.dumps(apple_log, indent=2)
    logging.log(apple_log_level, "Full notarization log: {}".format(pretty_log))

    if apple_log['issues']:
        logging.warning("Issues found: {}".format(json.dumps(apple_log["issues"], indent=2)))

    if not status.success:
        raise Exception("Notarization failed.")


def staple(dotapp_path):
    "xcrun stapler staple Example.app"
    logging.info("Stapling notarization to {}".format(dotapp_path))
    cmd = ["xcrun", "stapler", "staple", dotapp_path]
    logging.debug("Running {}".format(" ".join(cmd)))
    start_time = time.monotonic()
    completed = subprocess.run(cmd, capture_output=True, check=True)
    elapsed_time = time.monotonic() - start_time
    logging.debug("It took {} seconds.".format(elapsed_time))


def verify_notarization(dotapp_path):
    logging.info("Verifying notarization of {}".format(dotapp_path))
    cmd = ["xcrun", "stapler", "validate", dotapp_path]
    logging.debug("Running {}".format(" ".join(cmd)))
    start_time = time.monotonic()
    completed = subprocess.run(cmd, capture_output=True, check=True)
    elapsed_time = time.monotonic() - start_time
    logging.debug("It took {} seconds.".format(elapsed_time))
    logging.info("{} is notarized".format(dotapp_path))


def main(dotapp_path, certificate_id, primary_bundle_id, apple_developer_username,
         apple_developer_keychain_password_name):
    certificate_hex_id = "19979257B20DF8A23378093D7F6A76EC209B82BE"
    timestamp_server = "http://timestamp.apple.com/ts01"
    primary_bundle_id = "com.kicad.kicad.zip"
    apple_developer_username = "wayneandlayne@wayneandlayne.com"
    apple_developer_keychain_password_name = "KiCad Notarization"


def parse_args(arg_list=sys.argv[1:]):
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", help="modify output verbosity",
                        action="store_true")
    parser.add_argument("-q", "--quiet", help="Reduce output",
                        action="store_true")

    subparsers = parser.add_subparsers(dest='subparser_name',
                                       help='sub-command help')
    sign_parser = subparsers.add_parser('sign')
    sign_parser.add_argument("--certificate-id",
                             required=True,
                             help="Signing certificate ID.  It is best if this is the 40 character hex ID from "
                                  "`security find-identity -v`.")
    sign_parser.add_argument("--entitlements", help="Optional path to entitlements plist.")
    sign_parser.add_argument("--timestamp-url",
                             default="http://timestamp.apple.com/ts01",
                             help="Override URL to timestamp server")
    sign_parser.add_argument("path", help="Path to the .app")

    notarize_parser = subparsers.add_parser('notarize')
    notarize_parser.add_argument("--apple-developer-username", required=True,
                                 help="Username for the Apple developer account")
    notarize_parser.add_argument("--apple-developer-password-keychain-name", required=True,
                                 help="Create an app-specific password for your Apple account, and put it in your "
                                      "Keychain. This argument is the name of that Keychain entry.  (This is the "
                                      "Apple recommended way to sign and notarize from the command line.)")
    notarize_parser.add_argument("--primary-bundle-id", required=True,
                                 help="This is used to identify the notarization request and "
                                      "doesn't actually need to match the contents of the notarization request.")
    notarize_parser.add_argument("path", help="Path to the .app")

    args = parser.parse_args(arg_list)

    if args.verbose and args.quiet:
        raise argparse.ArgumentError("--verbose and --quiet cannot be specified at the same time.")

    return args


def handle_signing(dotapp_path, certificate_hex_id, entitlements_path, timestamp_url):
    sign(dotapp_path, certificate_hex_id, entitlements_path, timestamp_url)
    verify_signing(dotapp_path)
    print("Done. Signed and verified {}".format(dotapp_path))


def handle_notarization(dotapp_path,
                        primary_bundle_id,
                        apple_developer_username,
                        apple_developer_keychain_password_name):
    zip_path = make_zip(dotapp_path)
    request_uuid = submit_for_notarization(zip_path,
                                           primary_bundle_id,
                                           apple_developer_username,
                                           apple_developer_keychain_password_name)
    wait_for_notarization(request_uuid,
                          apple_developer_username,
                          apple_developer_keychain_password_name)
    staple(dotapp_path)
    verify_notarization(dotapp_path)
    print("Done. Submitted {} for notarization, waited for it to be notarized, stapled the notarization to the "
          "original .app, and verified notarization.".format(dotapp_path))


def main():
    args = parse_args()
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    if args.quiet:
        logging.getLogger().setLevel(logging.WARNING)
    else:
        logging.getLogger().setLevel(logging.INFO)

    if args.subparser_name == "sign":
        handle_signing(args.path,
                       args.certificate_id,
                       args.entitlements,
                       args.timestamp_url)
    elif "notarize" == args.subparser_name:
        handle_notarization(args.path,
                            args.primary_bundle_id,
                            args.apple_developer_username,
                            args.apple_developer_password_keychain_name)


if __name__ == "__main__":
    main()
