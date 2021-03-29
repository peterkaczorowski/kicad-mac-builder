# Python 3 Migration Scratch Document

# Overview

There were a few complications migrating from Python 2 to Python 3 for KiCad on macOS.

It is my intent to first get Python 3 and wx 3.1 working with KiCad on macOS, and then to improve the developer
experience.  I wrote a wrapper script (dyldstyle) that does a bunch of dynamic linker things, and I hope to remove it as
soon as we can. :)  I'd love for it to not need to exist, and if it does need to exist, I'd love for CMake to do it, in KiCad itself.

# Tests

Before we are finished, all of the following things should work:

* pcbnew scripting console from pcbnew.app: Open up pcbnew.app, and open up the Python scripting console.  Type `import pcbnew` and press enter.  It shouldn't show an error.  Verify that the build date of Python is the same as the build date of the package.

* pcbnew scripting onsole from KiCad.app: Open up KiCad.app, open up pcbnew, and open up the Python scripting console. Type `import pcbnew` and press enter.  It shouldn't show an error.  Verify that the build date of Python is the same as the build date of the package.

* Open up the terminal, and run `kicad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3`.  It shouldn't show an error.  Verify that the build date of Python is the same as the build date of the package.

* Open up the terminal, and run `cd kicad.app/Contents/Frameworks/Python.framework/Versions/3.8/lib/python3.8/site-packages; ../../Python.framework/Versions/Current/bin/python3 -m pcbnew`.  It shouldn't show an error.  

* Copy example_action_plugin.py into ~/Library/Preferences/kicad/5.99/scripting/plugins/.  Open up pcbnew, both via KiCad.app and Pcbnew.app, and add a label with the text '$date`  Go to Tools ⇒ External plugins. You should see Add Date on PCB.  Click it, and you should see the label change to something like '$date$ 2021-03-29'.

* TODO: add test for eeschema bom export plugin.

* TODO: test for footprint wizard.

For notarization purposes, we will want to move most of Python that isn't the Framework into Content/Resources, but we have to go one step at a time.
