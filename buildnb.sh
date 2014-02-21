#!/bin/sh

# modified version of buildxen.sh from https://github.com/rumpkernel/rumpuser-xen

# Just a script to run the handful of commands required to build NetBSD libc, headers

LIBLIBS="c crypt ipsec m pthread prop util pci y"
MORELIBS="external/bsd/flex/lib crypto/external/bsd/openssl/lib/libcrypto"
LIBS=""
for lib in ${LIBLIBS}; do
	LIBS="${LIBS} rumpsrc/lib/lib${lib}"
done
for lib in ${MORELIBS}; do
	LIBS="${LIBS} rumpsrc/${lib}"
done

STDJ='-j4'
: ${BUILD_QUIET:=-q}

set -e

# ok, urgh, we need just one tree due to how build systems work (or
# don't work).  So here's what we'll do for now.  Checkout rumpsrc,
# checkout nbusersrc, and copy nbusersrc over rumpsrc.  Obviously, we cannot
# update rumpsrc except manually after the copy operation, but that's
# a price we're just going to be paying for now.
if [ ! -d rumpsrc ]; then
	git submodule update --init --recursive
	./buildrump.sh/buildrump.sh -s rumpsrc checkout
	cp -Rp nbusersrc/* rumpsrc/
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
	netisdn netkey netmpls netnatm netsmb nfs ntfs openssl ppath prop
	protocols rpc rpcsvc ssp sys ufs uvm x86'
for dir in ${INCSDIRS}; do
	mkdir -p rump/include/$dir
done
# XXX
mkdir -p rumpobj/dest.stage/usr/lib/pkgconfig

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
	( cd ${lib} && ${RMAKE} includes >/dev/null 2>&1)
done
( cd rumpsrc/lib/librumpclient && ${RMAKE} includes >/dev/null 2>&1)

echo '>> done with headers'

makeuserlib ()
{

	( cd $1
		${RMAKE} obj
		${RMAKE} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no \
		    NOGCCERROR=1 ${STDJ} dependall
		${RMAKE_INST} MKMAN=no MKLINT=no MKPROFILE=no MKYP=no install
	)
}
for lib in ${LIBS}; do
	makeuserlib ${lib}
done

./buildrump.sh/buildrump.sh ${BUILD_QUIET} \
    -s rumpsrc -T rumptools -o rumpobj install
