KiCad Mac Builder
=================

If you are looking to run KiCad on your Mac, please use the instructions at http://kicad.org/download/osx/.

If you are looking to compile KiCad or improve KiCad packaging on MacOS, kicad-mac-builder may be able to help you.

To build KiCad 5.1, use the 5.1 branch of this repository.

Setup
=====
kicad-mac-builder requires a 10.14+ Mac and at least 40G of disk space free.  The instructions assume you are capable of using the command line but they are not intended to require arcane deep knowledge.

The documentation assumes you are using Homebrew on your Mac.  The automated builds use `./ci/src/bootstrap.sh` to install Homebrew and the kicad-mac-builder dependencies.

Please use a terminal to run the following command to install the dependencies:

`./ci/src/bootstrap.sh`

Usage
=====
To get up and running the absolute fastest, use `build.py`.  It expects to be run from the directory it is in, like;

`./build.py`

It builds everything and uses "reasonable" settings.  If you want something special, check `./build.py --help`, and if that doesn't help, read the rest of this documentation.  Failing that, run `cmake` and `make` by hand.  Better documentation is definitely welcomed!

By default, dependencies are built once, and unless their build directories are cleaned out, or their source is updated, they will not be built again.  The KiCad files, like the footprints, symbols, 3D models, and KiCad itself, are, by default, built from origin/master of their respective repositories or re-downloaded, ensuring you have the most up-to-date KiCad.

If you'd like to build KiCad from sources instead of from git, you can use the --kicad-source-dir option.  This can be useful for testing KiCad changes.

* `build.py --target kicad` builds KiCad and its source code dependencies, but packages nothing.  This is the same for any other CMake targets.
* `build.py --target package-kicad-nightly` creates a DMG of everything except the 3D models and docs.
* `build.py --target package-extras` creates a DMG of the 3D models.
* `build.py --target package-kicad-unified` creates a DMG of everything.
* `build.py` downloads and builds everything, but does not package any DMGs.

During the build, some DMGs may be mounted and Finder may open windows while the script runs.  Unmounting or ejecting the DMGs while the script runs is likely to damage the output DMG.

The output DMGs from `build.py` go into `dmg/` in the build directory.  Both the build directory and dmg directory can be specified at the command line.

KiCad Mac Builder does not install KiCad onto your Mac or modify your currently installed KiCad.

Building on Big Sur (macOS 11)
==============================

At the moment, building on Big Sur requires additional steps.

1. Download the Xcode 11.3.1 to obtain the OSX 10.15 SDK (obtainable from Apple Developer Downloads [here](https://download.developer.apple.com/Developer_Tools/Xcode_11.3.1/Xcode_11.3.1.xip))
2. Unpack the SDK in to the expected location `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk`
3. Set the environment variable `SDKROOT` to the path in step 2
4. Run `build.py` as above, passing the `--macos-min-version 10.15` option

There will likely be warnings raised about dependencies having been built with a later SDK; for development purposes these warnings can be ignored.

Improving Big Sur support is on the near-term roadmap.

Signing and Notarization
========================
kicad-mac-builder supports optional signing and notarization of build outputs.  kicad-mac-builder expects you are using a Developer ID certificate.  Details on creating one are available at https://developer.apple.com/developer-id/. kicad-mac-builder also expects you have stored your Apple developer account password in your keychain.  See `man altool` for details.

Setting up a KiCad Build Environment
====================================

You can use kicad-mac-builder to setup a KiCad build environment on macOS.  The `setup-kicad-dependencies` target will build all of the KiCad dependencies, and then print the CMake arguments it would use against KiCad's CMake configuration.

Run `./build.py --target setup-kicad-dependencies`.  At the end, you'll see some output that starts with `CMake arguments for KiCad:`.  Save that.

Check out the KiCad source somewhere on your system.

If you're building at the command line, go into the KiCad source, and do something like the following:

```
mkdir build
cd build
cmake (All those arguments you copied go here, which should be a series of -DVARIABLENAME=value...) ../ # don't forget that ../ at the end!
make
make install
```

If you're using CLion, open CLion, and open the KiCad source directory.  Go into Preferences > Build, Execution, Deployment > CMake, and put the copied CMake arguments (the series of -DVARIABLENAME=value -DOTHERVARIABLENAME=othervalue..) into CMake Options.

CLion will likely need to reindex the project.  When that is complete, you should have a series of outputs in the top right corner, by the green arrow play button ("Run"). Choose `kicad | Debug` and press "Run". This should start a build, and TODO: finish

Now, you can open Finder to the location specified in `CMAKE_INSTALL_PREFIX` in the CMake arguments, and you should see KiCad.app and the rest of the suite.

Built like this, KiCad should work but may not be relocatable or distributable.  There are additional steps required to be able to move the bundle or use it on a different machine.

(Developers, we'd love to hear how this went for you!)

Issues
======

Depending on if the issues are with KiCad or kicad-mac-builder, issues may be found at either https://gitlab.com/kicad/packaging/kicad-mac-builder/-/issues or https://gitlab.com/kicad/code/kicad/-/issues?label_name=macos.

Making changes to kicad-mac-builder
===================================

New Dependencies
----------------
You cannot assume brew uses default paths, as at least one of the build machines has multiple brew installations.  See `build.py` for examples.

Make sure you add any new dependencies to this README, as well as to the ci/ scripts.  If you don't, the builds from a clean VM will certainly fail.

Linting
-------
To prescreen your changes for style issues, install shellcheck and cmakelint and run the following from the same directory as this README:

`find . -path ./build -prune -o -name \*.sh -exec shellcheck {} \;`

`cmakelint --filter=-linelength,-readability/wonkycase kicad-mac-builder/CMakeLists.txt`

`find . -path ./build -prune -o -name \*.cmake -exec cmakelint --filter=-linelength,-readability/wonkycase {} \;`

Test Procedure
==============
Before big releases, we should check to make sure all the component pieces work.

Remove the build/ directory, and run `build.py`.  Then, rerun `build.py`, to make sure that everything works with both new and incremental builds.

Basics
------
* Open up KiCad.app, and then open up each of the applications like Pcbnew and the calculator.
* Open up each of the apps in standalone mode.

Templates
---------
* Open up KiCad.app, and click File -> New -> Project from Template.  You should see a new window pop up with options like STM32 and Raspberry Pi.  Select one, and click OK.  It will ask you where to save.  Make a new directory somewhere, and select it.  You should see no errors.

Python
------
* Open up pcbnew.app, and open up the Python scripting console.  Type `import pcbnew` and press enter.  It shouldn't show an error.  Verify that the build date of Python is the same as the build date of the package.
* Open up KiCad.app, open up pcbnew, and open up the Python scripting console. Type `import pcbnew` and press enter.  It shouldn't show an error.  Verify that the build date of Python is the same as the build date of the package. (This currently doesn't work when KiCad.app is opened via Finder.)
* Open up the terminal, and run `kicad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3`.  It shouldn't show an error.  Verify that the build date of Python is the same as the build date of the package.
* Open up the terminal, and run `cd kicad.app/Contents/Frameworks/Python.framework/Versions/Current/lib/python*/site-packages; ../../Python.framework/Versions/Current/bin/python3 -m pcbnew`.  It shouldn't show an error.
* Copy example_action_plugin.py into ~/Library/Preferences/kicad/5.99/scripting/plugins/.  Open Pcbnew.app. Add a label with the text '$date`  Go to Tools ⇒ External plugins. You should see Add Date on PCB.  Click it, and you should see the label change to something like '$date$ 2021-03-29'.
* Copy example_action_plugin.py into ~/Library/Preferences/kicad/5.99/scripting/plugins/.  Open KiCad.app. Create a new project.  Open Pcbnew.  Add a label with the text '$date`  Go to Tools ⇒ External plugins. You should see Add Date on PCB.  Click it, and you should see the label change to something like '$date$ 2021-03-29'.

Footprint Wizards
-----------------
* Open up Pcbnew.app, and open up the footprint editor. Click the "New Footprint Using Footprint Wizard" button. Click the "Select Wizard" button.  Select BGA.  Click OK.  Click the "Export footprint to editor" button.  You should see a footprint on the editor screen, and you should see no errors.
* Open up KiCad.app, and open up the footprint editor. Click the "New Footprint Using Footprint Wizard" button. Click the "Select Wizard" button.  Select BGA.  Click OK.  Click the "Export footprint to editor" button.  You should see a footprint on the editor screen, and you should see no errors.

Localization
------------
* Open up KiCad.app, and change the language via Preferences -> Language.  You should see the text in the menubars change.

3D Models
---------
* Open up KiCad.app, and open up demos/pic_programmer/pic_programmer.pro.  Open up Pcbnew.  Click View->3D Viewer.  A new window opens.  It should show a PCB with mostly populated components, including LEDs, sockets, resistors, and capacitors.  At least one connector appears to be missing.
* Open up Pcbnew.app, and open up demos/pic_programmer/pic_programmer.pro.  Click View->3D Viewer.  A new window opens.  It should show a PCB with mostly populated components, including LEDs, sockets, resistors, and capacitors.  At least one connector appears to be missing.

OCC
---
* Open up KiCad.app, and open up demos/pic_programmer/pic_programmer.pro.  Open up Pcbnew.  Click File->Export->STEP.  Click OK on the Export Step dialog.  The output should print "Info: STEP file has been created successfully.".  Currently, I see a lot warnings but these appear to be related to models not being set up.
* Open up Pcbnew.app, and open up demos/pic_programmer/pic_programmer.kicad_pcb.  Click File->Export->STEP.  Click OK on the Export Step dialog.  The output should print "Info: STEP file has been created successfully.".  Currently, I see a lot warnings but these appear to be related to models not being set up.

Help
----
* Open up KiCad.app, and open up the help documents via Help -> KiCad Manual and Help -> Getting Started in KiCad.  You should see a browser open with the documentation.
* Open up KiCad.app, and change the languages to something not English via Preferences -> Language.  Then open up the manual via Help -> KiCad Manual.  You should see a browser open with the documentation in the matching language.

Tips
----
When debugging dylib stuff, the environment vaiables DYLD_PRINT_LIBRARIES and DYLD_PRINT_LIBRARIES_POST_LAUNCH are helpful.  For instance:

`DYLD_PRINT_LIBRARIES=YES DYLD_PRINT_LIBRARIES_POST_LAUNCH=YES  /Users/wolf/KiCad/KiCad.app/Contents/Applications/pcbnew.app/Contents/MacOS/pcbnew`
