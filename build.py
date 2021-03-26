#!/usr/bin/env python

# Try not to use any packages that aren't included with Python, please.

import argparse
import errno
import os
import subprocess
import sys

DEFAULT_KICAD_GIT_URL = "https://gitlab.com/kicad/code/kicad.git"

def print_and_flush(s):
    # sigh, in Python3 this is build in... :/
    print(s)
    sys.stdout.flush()


def get_number_of_cores():
    return int(subprocess.check_output("sysctl -n hw.ncpu", shell=True).strip())


def get_local_macos_version():
    return subprocess.check_output("sw_vers -productVersion | cut -d. -f1-2", shell=True).decode('utf-8').strip()


def parse_args(args):
    docs_tarball_url_default = "https://docs.kicad.org/kicad-doc-HEAD.tar.gz"

    parser = argparse.ArgumentParser(description='Build and package KiCad for macOS. Part of kicad-mac-builder.',
                                     epilog="Further details are available in the README file.")
    parser.add_argument("--build-dir",
                        help="Path that will store the build files. Will be created if possible if it doesn't exist. Defaults to \"build/\" next to build.py.",
                        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "build"),
                        required=False)
    parser.add_argument("--dmg-dir",
                        help="Path that will store the output dmgs for packaging targets.  Defaults to \"dmg/\" in the build directory.",
                        required=False)
    parser.add_argument("--jobs",
                        help="Tell make to build using this number of parallel jobs. Defaults to the number of cores.",
                        type=int,
                        required=False,
                        default=get_number_of_cores()
                        )
    parser.add_argument("--release",
                        help="Build for a release.",
                        action="store_true"
                        )
    parser.add_argument("--extra-version",
                        help="Sets the version to the git version, a hyphen, and then this string.",
                        required=False)
    parser.add_argument("--build-type",
                        help="Build type passed to CMake like Debug, Release, or RelWithDebInfo.  Defaults to RelWithDebInfo, unless --release is set."
                        )
    parser.add_argument("--kicad-git-url",
                        help="KiCad source code git url.  Defaults to {}. Conflicts with --kicad-source-dir.".format(DEFAULT_KICAD_GIT_URL))
    parser.add_argument("--kicad-ref",
                        help="KiCad source code git tag, commit, or branch to build from. Defaults to origin/master.",
                        )
    parser.add_argument("--kicad-source-dir",
                        help="KiCad source directory to use as-is to build from.  Will not be patched, and cannot create a release.",
                        )
    parser.add_argument("--symbols-ref",
                        help="KiCad symbols git tag, commit, or branch to build from. Defaults to origin/master.",
                        )
    parser.add_argument("--footprints-ref",
                        help="KiCad footprints git tag, commit, or branch to build from. Defaults to origin/master.",
                        )
    parser.add_argument("--packages3d-ref",
                        help="KiCad packages3d git tag, commit, or branch to build from. Defaults to origin/master.",
                        )
    parser.add_argument("--templates-ref",
                        help="KiCad templates git tag, commit, or branch to build from. Defaults to origin/master.",
                        )
    parser.add_argument("--docs-tarball-url",
                        help="URL to download the documentation tar.gz from. Defaults to {}".format(
                            docs_tarball_url_default),
                        )
    parser.add_argument("--skip-docs-update",
                        help="Skip updating the docs, if they've already been downloaded. Cannot be used to create a release.",
                        action="store_true"
                        )
    parser.add_argument("--release-name",
                        help="Overrides the main component of the DMG filename.",
                        )
    parser.add_argument("--macos-min-version",
                        help="Minimum macOS version to build for. You must have the appropriate XCode SDK installed. "
                             " Defaults to the macOS version of this computer.",
                        default=get_local_macos_version(),
                        )
    parser.add_argument("--no-retry-failed-build",
                        help="By default, if make fails and the number of jobs is greater than one, build.py will "
                             "rebuild using a single job to create a clearer error message. This flag disables that "
                             "behavior.",
                        action='store_false',
                        dest="retry_failed_build"
                        )
    parser.add_argument("--target",
                        help="List of make targets to build. By default, downloads and builds everything, but does "
                             "not package any DMGs. Use package-kicad-nightly for the nightly DMG, "
                             "package-extras for the extras DMG, and package-kicad-unified for the all-in-one "
                             "DMG. See the documentation for details.",
                        nargs="+",
                        )
    parser.add_argument("--extra-bundle-fix-dir",
                        dest="extra_bundle_fix_dir",
                        help="Extra directory to pass to fixup_bundle for KiCad.app.")

    parsed_args = parser.parse_args(args)

    if parsed_args.target is None:
        parsed_args.target = []

    if parsed_args.release and parsed_args.kicad_source_dir:
        parser.error("KiCad source directory builds cannot be release builds.")

    if parsed_args.release and parsed_args.skip_docs_update:
        parser.error("Release builds cannot skip docs updates.")

    if (parsed_args.kicad_ref or parsed_args.kicad_git_url) and parsed_args.kicad_source_dir:
        parser.error("KiCad source directory builds cannot also specify KiCad git details.")

    if parsed_args.kicad_source_dir:
        parsed_args.kicad_source_dir = os.path.realpath(parsed_args.kicad_source_dir)
    elif not parsed_args.kicad_git_url:
        parsed_args.kicad_git_url = DEFAULT_KICAD_GIT_URL

    if parsed_args.release:
        if parsed_args.build_type is None:
            parsed_args.build_type = "Release"
        elif parsed_args.build_type != "Release":
            parser.error("Release builds imply --build-type Release.")

        if parsed_args.kicad_ref is None or \
                parsed_args.symbols_ref is None or \
                parsed_args.footprints_ref is None or \
                parsed_args.packages3d_ref is None or \
                parsed_args.templates_ref is None or \
                parsed_args.docs_tarball_url is None or \
                parsed_args.release_name is None:
            parser.error(
                "Release builds require --kicad-ref, --symbols-ref, --footprints-ref, --packages3d-ref, "
                "--templates-ref, --docs-tarball-url, and --release-name.")
    else:
        # not stable

        default_refs = ["symbols_ref", "footprints_ref", "packages3d_ref", "templates_ref"]

        if not parsed_args.kicad_source_dir:
            default_refs.append("kicad_ref")

        # handle dedaults--can't do in argparse because they're conditionally required
        for ref in default_refs:
            if getattr(parsed_args, ref) is None:
                setattr(parsed_args, ref, "origin/master")
        if parsed_args.docs_tarball_url is None:
            parsed_args.docs_tarball_url = docs_tarball_url_default
        if parsed_args.build_type is None:
            parsed_args.build_type = "RelWithDebInfo"

    # Before Python 3.4, __file__ might not be absolute, so let's lock this down before we do any chdir'ing

    parsed_args.kicad_mac_builder_cmake_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kicad-mac-builder")

    return parsed_args


def get_make_command(args):
    make_command = ["make", "-j{}".format(args.jobs)]
    if args.target:
        make_command.extend(args.target)

    return make_command

def build(args, new_path):

    try:
        os.makedirs(args.build_dir)
    except OSError as exception:
        if exception.errno != errno.EEXIST:
            raise

    os.chdir(args.build_dir)

    cmake_command = ["cmake",
                     "-DMACOS_MIN_VERSION={}".format(args.macos_min_version),
                     "-DDOCS_TARBALL_URL={}".format(args.docs_tarball_url),
                     "-DFOOTPRINTS_TAG={}".format(args.footprints_ref),
                     "-DPACKAGES3D_TAG={}".format(args.packages3d_ref),
                     "-DSYMBOLS_TAG={}".format(args.symbols_ref),
                     "-DTEMPLATES_TAG={}".format(args.templates_ref),
                     "-DKICAD_CMAKE_BUILD_TYPE={}".format(args.build_type),
                     ]

    if args.kicad_source_dir:
        cmake_command.append("-DKICAD_SOURCE_DIR={}".format(args.kicad_source_dir))
    else:
        if args.kicad_git_url:
            cmake_command.append("-DKICAD_URL={}".format(args.kicad_git_url))
        if args.kicad_ref:
            cmake_command.append("-DKICAD_TAG={}".format(args.kicad_ref))

    if args.skip_docs_update:
        cmake_command.append("-DSKIP_DOCS_UPDATE=ON")

    if args.dmg_dir:
        cmake_command.append("-DDMG_DIR={}".format(args.dmg_dir))

    if args.extra_version:
        cmake_command.append("-DKICAD_VERSION_EXTRA={}".format(args.extra_version))

    if args.extra_bundle_fix_dir:
        cmake_command.append("-DMACOS_EXTRA_BUNDLE_FIX_DIRS={}".format(args.extra_bundle_fix_dir))

    if args.release_name:
        cmake_command.append("-DRELEASE_NAME={}".format(args.release_name))

    cmake_command.append(args.kicad_mac_builder_cmake_dir)

    print_and_flush("Running {}".format(" ".join(cmake_command)))
    try:
        subprocess.check_call(cmake_command, env=dict(os.environ, PATH=new_path))
    except subprocess.CalledProcessError:
        print_and_flush("Error while running cmake. Please report this issue if you cannot fix it after reading the README.")
        raise

    make_command = get_make_command(args)
    print_and_flush("Running {}".format(" ".join(make_command)))
    try:
        subprocess.check_call(make_command, env=dict(os.environ, PATH=new_path))
    except subprocess.CalledProcessError:
        if args.retry_failed_build and args.jobs > 1:
            print_and_flush("Error while running make.")
            print_summary(args)
            print_and_flush("Rebuilding with a single job. If this consistently occurs, " \
                            "please report this issue. ")
            args.jobs = 1
            make_command = get_make_command(args)
            print_and_flush("Running {}".format(" ".join(make_command)))
            try:
                subprocess.check_call(make_command, env=dict(os.environ, PATH=new_path))
            except subprocess.CalledProcessError:
                print_and_flush("Error while running make after rebuilding with a single job. Please report this issue if you " \
                      "cannot fix it after reading the README.")
                print_summary(args)
                raise
        else:
            print_and_flush("Error while running make. It may be helpful to rerun with a single make job. Please report this " \
                  "issue if you cannot fix it after reading the README.")
            print_summary(args)
            raise

    had_package_targets = any(target.startswith("package-") for target in args.target)
    if had_package_targets:
        dmg_location = args.dmg_dir
        if dmg_location is None:
            dmg_location = os.path.join(args.build_dir, "dmg")
        print_and_flush("Output DMGs should be located in {}".format(dmg_location))

    print_and_flush("Build complete.")

def print_summary(args):
    print_and_flush("build.py argument summary:")
    for attr in sorted(args.__dict__):
        print_and_flush("{}: {}".format(attr, getattr(args, attr)))

def main():
    parsed_args = parse_args(sys.argv[1:])
    print_summary(parsed_args)
    gettext_path = "{}/bin".format(subprocess.check_output("brew --prefix gettext", shell=True).decode('utf-8').strip())
    bison_path = "{}/bin".format(subprocess.check_output("brew --prefix bison", shell=True).decode('utf-8').strip())
    new_path = ":".join((gettext_path, bison_path, os.environ["PATH"]))
    print(new_path)

    print_and_flush("\nYou can change these settings.  Run ./build.py --help for details.")
    print_and_flush("\nDepending upon build configuration, what has already been downloaded, what has already been built, " \
          "the computer and the network connection, this may take multiple hours and approximately 40G of disk space.")
    print_and_flush("\nYou can stop the build at any time by pressing Control-C.\n")
    build(parsed_args, new_path)


if __name__ == "__main__":
    main()
