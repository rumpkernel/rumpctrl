#!/bin/sh

# modified version of buildxen.sh from https://github.com/anttikantee/xen-nblibc

# Just a script to run the handful of commands required to build NetBSD libc, headers

LIBS="c pthread prop util"

STDJ='-j4'
: ${BUILD_QUIET:=-q}

set -e

if [ "${1}" != 'nocheckout' ]; then
	git submodule update --init --recursive
	./buildrump.sh/buildrump.sh -s rumpsrc checkout
	( cd nblib
		ln -sf ../rumpsrc/common
		ln -sf ../../libexec/ld.elf_so/rtld.h lib/libc
		ln -sf ../../libexec/ld.elf_so/rtldenv.h lib/libc
	)
fi

# Build rump kernel
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${STDJ} \
    -s rumpsrc -T rumptools -o rumpdynobj -d rumpdyn -V MKSTATICLIB=no fullbuild

# Now build a static but -fPIC libc.
# We force -fPIC so we can link into a shared library
export BUILDRUMP_CFLAGS=-fPIC
export BUILDRUMP_AFLAGS=-fPIC
export BUILDRUMP_LDFLAGS=-fPIC

# build tools
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${STDJ} -s rumpsrc \
    -T rumptools -o rumpobj -N -k -V MKPIC=no tools

RMAKE=`pwd`/rumptools/rumpmake
RMAKE_INST=`pwd`/rumptools/_buildrumpsh-rumpmake

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
for lib in ${LIBS}; do
	( cd nblib/lib/lib${lib} && ${RMAKE} includes >/dev/null 2>&1)
done
( cd rumpsrc/lib/librumpclient && ${RMAKE} includes >/dev/null 2>&1)

echo '>> done with headers'

makeuserlib ()
{

	OBJS=`pwd`/rumpobj/lib/$1
	( cd nblib/lib/$1
		${RMAKE} MAKEOBJDIR=${OBJS} obj
		${RMAKE} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no \
		    NOGCCERROR=1 MAKEOBJDIR=${OBJS} ${STDJ} dependall
		${RMAKE_INST} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no \
		    MAKEOBJDIR=${OBJS} install
	)
}
for lib in ${LIBS}; do
	makeuserlib lib${lib}
done

./buildrump.sh/buildrump.sh ${BUILD_QUIET} \
    -s rumpsrc -T rumptools -o rumpobj install
