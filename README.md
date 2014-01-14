[![Build Status](https://travis-ci.org/justincormack/rumprun.png)](https://travis-ci.org/justincormack/rumprun)

This is a small experimental wrapper for running programs that were written for a normal POSIX (NetBSD) system to run them under rump kernel.

For more information about the rump kernel see [https://www.netbsd.org/docs/rump/](https://www.netbsd.org/docs/rump/).

It takes NetBSD program (see Makefile) and compiles it using the NetBSD ABI, and then dynamically opens it in a rump kernel environment.

To build & run, e.g.: 
````
./buildnb.sh
make
export LD_LIBRARY_PATH=.:rumpdyn/lib
./rumprun ifconfig -a
````

Currently tested on Linux and FreeBSD, so should be generally portable. (FreeBSD needs a few tweaks to Makefile).

Binaries currently built:
* ```cat```
* ```cp```
* ```df```
* ```ifconfig```
* ```ls```
* ```mkdir```
* ```mount_ffs```
* ```mount``` mount -vv will not work as it forks
* ```mv```
* ```ping``` [needs patches for random number support](https://github.com/anttikantee/buildrump.sh/issues/61)
* ```ping6``` ditto, and another issue
* ```rm```
* ```route```
* ```sysctl```

There is also a LuaJIT interactive shell which runs libraries in the program directory:

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

