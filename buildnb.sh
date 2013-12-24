#!/bin/sh

# modified version of buildxen.sh from https://github.com/anttikantee/xen-nblibc

# Just a script to run the handful of commands required to build NetBSD libc, headers

STDJ='-j4'

set -e

if [ "${1}" != 'nocheckout' ]; then
	git submodule update --init --recursive
	./buildrump.sh/buildrump.sh -s rumpsrc checkout
	( cd nblibs
		ln -sf ../rumpsrc/common
		ln -sf ../../libexec/ld.elf_so/rtld.h lib/libc
		ln -sf ../../libexec/ld.elf_so/rtldenv.h lib/libc
	)
fi

# Build dynamic libs

./buildrump.sh/buildrump.sh -${BUILD_QUIET:-q} ${STDJ} \
    -s rumpsrc -T rumptools -o rumpobj -d rumpdyn fullbuild

# Now build a static but -fPIC libc.

rm -rf rumptools rumpobj

# We force -fPIC so we can link into a shared library
export BUILDRUMP_CFLAGS=-fPIC
export BUILDRUMP_AFLAGS=-fPIC
export BUILDRUMP_LDFLAGS=-fPIC

# build tools
./buildrump.sh/buildrump.sh -${BUILD_QUIET:-q} ${STDJ} -k \
    -s rumpsrc -T rumptools -o rumpobj -N -V RUMP_KERNEL_IS_LIBC=1 tools
./buildrump.sh/buildrump.sh -k -s rumpsrc -T rumptools -o rumpobj setupdest
# FIXME to be able to specify this as part of previous cmdline
# I think this was a Xen restriction, default is 64k
# echo 'CPPFLAGS+=-DMAXPHYS=32768' >> rumptools/mk.conf

RMAKE=`pwd`/rumptools/rumpmake

#
# install full set of headers.
#
# first, "mtree" (TODO: fetch/use nbmtree)
INCSDIRS='adosfs altq arpa crypto dev filecorefs fs i386 isofs miscfs
	msdosfs net net80211 netatalk netbt netinet netinet6 netipsec
	netisdn netkey netmpls netnatm netsmb nfs ntfs ppath prop
	protocols rpc rpcsvc ssp sys ufs uvm x86'
for dir in ${INCSDIRS}; do
	mkdir -p rump/include/$dir
done

# then, install
echo '>> Installing headers.  please wait (may take a while) ...'
(
  # sys/ produces a lot of errors due to missing tools/sources
  # "protect" the user from that spew
  cd rumpsrc/sys
  ${RMAKE} -k obj >/dev/null 2>&1
  ${RMAKE} -k includes >/dev/null 2>&1
)

# rpcgen lossage
( cd rumpsrc/include && ${RMAKE} -k includes > /dev/null 2>&1)

# other lossage
( cd nblibs/lib/libc && ${RMAKE} includes >/dev/null 2>&1)
( cd nblibs/lib/libpthread && ${RMAKE} includes >/dev/null 2>&1)

echo '>> done with headers'

# build rump kernel
./buildrump.sh/buildrump.sh -k -s rumpsrc -T rumptools -o rumpobj build install

makekernlib ()
{
	lib=$1
	OBJS=`pwd`/rumpobj/$lib
	mkdir -p ${OBJS}
	( cd ${lib}
		${RMAKE} MAKEOBJDIRPREFIX=${OBJS} obj
		${RMAKE} MAKEOBJDIRPREFIX=${OBJS} dependall
		${RMAKE} MAKEOBJDIRPREFIX=${OBJS} install
	)
}

makeuserlib ()
{
	lib=$1

	OBJS=`pwd`/rumpobj/lib/$1
	( cd nblibs/lib/$1
		${RMAKE} MAKEOBJDIR=${OBJS} obj
		${RMAKE} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no \
		    NOGCCERROR=1 MAKEOBJDIR=${OBJS} ${STDJ} dependall
		${RMAKE} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no \
		    MAKEOBJDIR=${OBJS} install
	)
}
makeuserlib libc
makeuserlib libm

