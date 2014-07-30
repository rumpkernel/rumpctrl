[![Build Status](https://travis-ci.org/rumpkernel/rumprun.png?branch=master)](https://travis-ci.org/rumpkernel/rumprun)

Rumprun-posix facilitates compiling and running programs against rump
kernels on POSIX-like userspace platform.  Rumprun-posix is especially
useful for the configuration of userspace rump kernels.  This repository
provides both the build framework and a selection of familiar utilities
such as `ifconfig`, `mount`, `sysctl`, and more.

Quickstart, run the following commands:

````
./buildnb.sh
. ./rumpremote.sh
rumpremote_listcmds
````

This will fetch and build dependencies and list bundled commands.

See [the wiki](http://wiki.rumpkernel.org/Repo:-rumprun-posix) for more
information and instructions.
