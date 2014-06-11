#!/bin/sh

# process options

STDJ='-j4'
JUSTCHECKOUT=false
BUILDRUMP=false
TESTS=false

# XXX TODO set FLAGS from -F options here to pass to buildrump.sh

for arg in "$@"
do
	[ ${arg} = "justcheckout" ] && JUSTCHECKOUT=true
	[ ${arg} = "buildrump" ] && BUILDRUMP=true
	[ ${arg} = "-q" ] && BUILD_QUIET=-q
	[ ${arg} = "tests" ] && TESTS=true
done

# figure out where gmake lies or if the system just lies
if [ -z "${MAKE}" ]; then
	MAKE=make
	type gmake >/dev/null && MAKE=gmake
fi
${MAKE} --version | grep -q 'GNU Make'
if [ $? -ne 0 ]; then
	echo ">> ERROR: GNU Make required, \"${MAKE}\" is not"
	echo ">> Please install GNU Make and/or set \${MAKE} to point to it"
	exit 1
fi

# modified version of buildxen.sh from https://github.com/rumpkernel/rumpuser-xen

# Just a script to run the handful of commands required to build NetBSD libc, headers

LIBLIBS="c crypt ipsec m npf pthread prop rmt util pci y z"
MORELIBS="external/bsd/flex/lib
	crypto/external/bsd/openssl/lib/libcrypto
	crypto/external/bsd/openssl/lib/libdes
	crypto/external/bsd/openssl/lib/libssl
	external/bsd/libpcap/lib"

LIBS=""
for lib in ${LIBLIBS}; do
	LIBS="${LIBS} rumpsrc/lib/lib${lib}"
done
for lib in ${MORELIBS}; do
	LIBS="${LIBS} rumpsrc/${lib}"
done

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

${JUSTCHECKOUT} && { echo ">> $0 done" ; exit 0; }

# Build rump kernel if requested
${BUILDRUMP} && ./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${STDJ} ${FLAGS} \
    -s rumpsrc -T rumptools -o rumpdynobj -d rumpdyn -V MKSTATICLIB=no fullbuild

# Now build a static libc.

# build tools
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${STDJ} ${FLAGS} -s rumpsrc \
    -T rumptools -o rumpobj -N -k -V MKPIC=no -V BUILDRUMP_SYSROOT=yes tools

RMAKE=`pwd`/rumptools/rumpmake
RMAKE_INST=`pwd`/rumptools/_buildrumpsh-rumpmake

#
# install full set of headers.
#
# first, "mtree" (TODO: fetch/use nbmtree)
INCSDIRS='adosfs altq arpa crypto dev filecorefs fs i386 isofs miscfs
	msdosfs net net80211 netatalk netbt netinet netinet6 netipsec
	netisdn netkey netmpls netnatm netsmb nfs ntfs openssl pcap ppath prop
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

./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${FLAGS} \
    -s rumpsrc -T rumptools -o rumpobj install

if ${BUILDRUMP}; then
	export PATH=${PATH}:${PWD}/rumpdyn/bin
	export LIBRARY_PATH=${PWD}/rumpdyn/lib
	export LD_LIBRARY_PATH=${PWD}/rumpdyn/lib
fi

${MAKE} && if ${TESTS}; then tests/test.sh; fi
