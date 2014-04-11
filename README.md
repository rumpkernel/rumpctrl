[![Build Status](https://travis-ci.org/rumpkernel/rumprun.png?branch=master)](https://travis-ci.org/rumpkernel/rumprun)

Rumprun facilitates compiling and running userspace programs against rump
kernels.  It is especially useful for the configuration of rump kernels.
This repository provides both the rumprun framework and a selection of
familiar utilities such as `ifconfig`, `mount`, `sysctl`, and more.

To build, run:

````
./buildnb.sh
make
````

This will automatically fetch and build all dependencies. This requires GNU make (gmake).

See [the wiki](http://wiki.rumpkernel.org/Repo:-rumprun) for more
information and instructions.
