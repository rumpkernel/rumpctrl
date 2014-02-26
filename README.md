[![Build Status](https://travis-ci.org/rumpkernel/rumprun.png)](https://travis-ci.org/rumpkernel/rumprun)

This is a small experimental wrapper for running programs that were written for a normal POSIX (NetBSD) system to run them under rump kernel.  Rumprun is especially useful for running NetBSD configuration tools on non-NetBSD systems for the purposes of configuring rump kernels.

For more information about the rump kernel see [http://www.rumpkernel.org/](http://www.rumpkernel.org/)

Rumprun takes NetBSD program (see Makefile) and compiles it using the NetBSD ABI, and then dynamically opens the compiled program.  The system calls that the program makes are being served by a rump kernel instead of the host kernel.

Currently tested on Linux and FreeBSD, so should be generally portable. (FreeBSD needs a few tweaks to Makefile).

Building
========

To build, run: 
````
./buildnb.sh
make
```

This will automatically fetch and build all dependencies, so assuming you
have build tools (compiler etc.) installed, you are good to go.

Running
=======

There are two ways to use rumprun, via `rumprun` or `rumpremote`.
The latter resembles the model used by a regular operating system,
and we will describe it first.

`rumpremote`
------------

When using `rumpremote`, you run the rump kernel in a separate process
from the NetBSD applications run with the help of `rumpremote`.

The most straightforward way to use `rumpremote` is in conjuction
with the readily available `rump_server` program.  The method
will be briefly described, with more documentation available from
http://www.rumpkernel.org/.

First, we run the server, for example with IP networking components:

````
$ export LD_LIBRARY_PATH=rumpdyn/lib
$ export LD_DYNAMIC_WEAK=1 #required on glibc systems
$ ./rumpdyn/bin/rump_server -lrumpnet -lrumpnet_net -lrumpnet_netinet6 -lrumpnet_shmif unix://csock
$
````

Now we can make system calls to `rump_server` via the local domain
socket (`unix://csock`).  We control the location that `rumpremote`
accesses by setting the env variable `$RUMP_SERVER`.

To configure one shmif interface:

````
$ export LD_LIBRARY_PATH=.:rumpdyn/lib
$ export RUMP_SERVER=unix://csock
$ ./rumpremote ifconfig shmif0 create
$ ./rumpremote ifconfig shmif0 linkstr busmem
$ ./rumpremote ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00
$ ./rumpremote ifconfig shmif0
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

`rumprun`
---------

As opposed to `rumpremote`, `rumprun` runs both the rump kernel and
application in the same process.

````
export LD_LIBRARY_PATH=.:rumpdyn/lib
./rumprun ifconfig -a
````

Note that operations from one `rumprun` invocation to the next
will not persist, given that the rump kernel is hosted in the
same process as `rumprun`.

There is also a LuaJIT interactive shell which runs libraries in the
program directory.  It has the advantage of being able to execute
multiple commands, somewhat akin to what is possible with `rumpremote`.

````
luajit -e "require 'rumprun'" -i
LuaJIT 2.0.2 -- Copyright (C) 2005-2013 Mike Pall. http://luajit.org/
Copyright (c) 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
    The NetBSD Foundation, Inc.  All rights reserved.
Copyright (c) 1982, 1986, 1989, 1991, 1993
    The Regents of the University of California.  All rights reserved.

NetBSD 6.99.23 (RUMP-ROAST) #0: Wed Jan  1 19:18:07 GMT 2014
	justin@brill:/home/justin/rump/rumprun/rumpobj/lib/librump
total memory = unlimited (host limit)
timecounter: Timecounters tick every 10.000 msec
timecounter: Timecounter "rumpclk" frequency 100 Hz quality 0
cpu0 at thinair0: rump virtual cpu
cpu1 at thinair0: rump virtual cpu
root file system type: rumpfs
JIT: ON CMOV SSE2 SSE3 SSE4.1 fold cse dce fwd dse narrow loop abc sink fuse
> ifconfig()
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 33648
	inet6 ::1 prefixlen 128
	inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
	inet 127.0.0.1 netmask 0xff000000
> ifconfig("lo1", "create")
> ifconfig()
lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 33648
	inet6 ::1 prefixlen 128
	inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
	inet 127.0.0.1 netmask 0xff000000
lo1: flags=8048<LOOPBACK,RUNNING,MULTICAST> mtu 33648
````

You might want to install a nicer Lua shell with readline support like https://github.com/jdesgats/ILuaJIT or http://www.nongnu.org/techne/lua/luaprompt/


Supported programs
==================

Binaries currently built listed here. Not all are fully tested yet and
there may be some unlisted caveats.  Generally speaking, supporting a
program is a matter of pulling in the unmodified NetBSD source code and
adding the name of the program to `Makefile`, so if you have requests,
do not hesitate to file an issue.  The manual page for each command
is available from http://man.NetBSD.org/,
e.g. [`cat`](http://man.NetBSD.org/cgi-bin/man-cgi?cat++NetBSD-current).

* ```cat```
* ```cgdconfig``` not fully tested; uses `getrusage()` for key len calcuation
* ```cp```
* ```dd```
* ```disklabel```
* ```df```
* ```dump```
* ```fsck```
* ```fsck_ffs```
* ```ifconfig```
* ```ktrace``` there is no kdump support yet but you can cat to host
* ```ln```
* ```ls```
* ```mkdir```
* ```mknod```
* ```modstat```
* ```mount_ffs```
* ```mount``` mount -vv will not work as it forks
* ```mv```
* ```ndp```
* ```newfs```
* ```npfctl``` requires rump kernel component to be built without `_NPF_TESTING`
* ```pcictl``` for future use, no pci bus yet
* ```ping```
* ```ping6``` uses signals not timeouts so only first ping working
* ```raidctl```
* ```rm```
* ```rndctl```
* ```route```
* ```sysctl```
* ```umount```
* ```vnconfig```

For programs that fork, you need to run under rumpremote and it will fork the provided host binary, so for ktrace you must do ```./rumpremote ktrace /home/justin/rump/rumprun/rumpremote ls```.
