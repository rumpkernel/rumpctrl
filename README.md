[![Build Status](https://travis-ci.org/rumpkernel/rumprun.png?branch=master)](https://travis-ci.org/rumpkernel/rumprun)

Rumprun is a wrapper for running programs that were written for a normal POSIX (NetBSD) system to run them under a rump kernel.  Rumprun is especially useful for running NetBSD configuration tools on non-NetBSD systems for the purposes of configuring rump kernels.

For more information about the rump kernel see [http://www.rumpkernel.org/](http://www.rumpkernel.org/)

Rumprun takes NetBSD program (see Makefile) and compiles it using the NetBSD ABI.  The system calls that the program makes are being served by a rump kernel instead of the host kernel.

Currently tested on Linux and NetBSD, and should be generally
portable. A good deal of NetBSD utilities will already work
(see end of this file for list of ones built out-of-the-box).

Building
========

To build, run: 
````
./buildnb.sh
make
```

This will automatically fetch and build all dependencies, so assuming you
have build tools (compiler etc.) installed, you are good to go. This requires GNU
make (gmake).

Running
=======

There are two ways to use rumprun, either linking into your program,
or using a rump server to provide the rump kernel service.
The latter resembles the model used by a regular operating system,
and we will describe it first.

Server mode
-----------

When using server mode, you run the rump kernel in a separate process
from the NetBSD applications.

The most straightforward way to do this is in conjuction
with the readily available `rump_server` program.  The method
will be briefly described, with more documentation available from
http://www.rumpkernel.org/.

First, we run the server, for example with IP networking components:

````
$ export LD_DYNAMIC_WEAK=1 #required on glibc systems
$ ./rumpdyn/bin/rump_server -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_shmif unix://csock
$
````

Now we can make system calls to `rump_server` via the local domain
socket (`unix://csock`).  We control the location that programs
access by setting the env variable `$RUMP_SERVER`.

To configure one shmif interface:

````
$ export RUMP_SERVER=unix://csock
$ ./bin/ifconfig shmif0 create
$ ./bin/ifconfig shmif0 linkstr busmem
$ ./bin/ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00
$ ./bin/ifconfig shmif0
shmif0: flags=8043<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500
	address: b2:a0:37:26:d3:2e
	linkstr: busmem
	inet 1.2.3.4 netmask 0xffffff00 broadcast 1.2.3.255
````

The interface will persist until `rump_server` is killed or halted,
like in a regular system an interface will persist until the
system is rebooted.

You can also use a custom application instead of `rump_server`.  Consult
http://www.rumpkernel.org/ for the documentation on how to do that.

Linking to your binary
----------------------

As opposed to server mode, you can both the rump kernel and
application in the same process.

This is under development and there will be examples shortly. The build process is
similar but you link in the rump kernel instead of just the rumpclient library.


Supported programs
==================

Binaries currently built listed here. Not all are fully tested yet and
there may be some unlisted caveats.  Generally speaking, supporting a
program is a matter of pulling in the unmodified NetBSD source code and
adding the name of the program to `Makefile`, so if you have requests,
do not hesitate to file an issue.  The manual page for each command
is available from http://man.NetBSD.org/,
e.g. [`cat`](http://man.NetBSD.org/cgi-bin/man-cgi?cat++NetBSD-current).

* ```arp```
* ```cat```
* ```cgdconfig```
* ```cp```
* ```dd```
* ```disklabel```
* ```df```
* ```dump```
* ```dumpfs```
* ```fsck```
* ```fsck_ext2fs```
* ```fsck_ffs```
* ```fsck_lfs```
* ```fsck_msdos```
* ```fsck_v7fs```
* ```ifconfig```
* ```ktrace``` there is no kdump support yet. you can cat `ktrace.out` to host
* ```ln```
* ```ls```
* ```makefs```
* ```mkdir```
* ```mknod```
* ```modstat```
* ```mount``` mount -vv needs some more work (it fork+exec's)
* ```mount_ffs```
* ```mv```
* ```ndp```
* ```newfs```
* ```newfs_ext2fs```
* ```newfs_lfs```
* ```newfs_msdos```
* ```newfs_sysvbfs```
* ```newfs_udf```
* ```newfs_v7fs```
* ```npfctl```
* ```pax```
* ```pcictl``` for future use, no pci bus support in userspace rump kernels yet
* ```ping```
* ```ping6``` uses signals not timeouts so only first ping working
* ```raidctl```
* ```reboot``` not working due to signals; there is a simple ```halt``` available.
* ```rm```
* ```rmdir```
* ```rndctl```
* ```route```
* ```sysctl```
* ```umount```
* ```vnconfig``` the vnd kernel driver is not provided by rumprun ;)

For programs that fork and exec, the rumpclient library will fork the provided host binary, so for ktrace you must do ```./bin/ktrace ./bin/ls```.
