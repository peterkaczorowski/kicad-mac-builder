# Python 3 Migration Scratch Document

# Overview

There were a few complications migrating from Python 2 to Python 3 for KiCad on macOS.

It is my intent to first get Python 3 and wx 3.1 working with KiCad on macOS, and then to improve the developer
experience.  I wrote a wrapper script (dyldstyle) that does a bunch of dynamic linker things, and I hope to remove it as
soon as we can. :)  I'd love for it to not need to exist, and if it does need to exist, I'd love for CMake to do it, in KiCad itself.

# Tests

Before we are finished, all of the Python tests from README.md should work, along with the following:

* TODO: add test for eeschema bom export plugin.

* TODO: test for footprint wizard.

For notarization purposes, we will want to move most of Python that isn't the Framework into Content/Resources, but we have to go one step at a time.
