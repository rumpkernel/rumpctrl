#!/bin/sh

die ()
{

	echo '>> ERROR:' >&2
	echo ">> $*" >&2
	exit 1
}

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

# process options

STDJ='-j4'
JUSTCHECKOUT=false
BUILDRUMP=true
TESTS=false

# XXX TODO set FLAGS from -F options here to pass to buildrump.sh

for arg in "$@"
do
	case ${arg} in
	"justcheckout")
		JUSTCHECKOUT=true
		;;
	"buildrump")
		BUILDRUMP=true
		;;
	"nobuildrump")
		BUILDRUMP=false
		;;
	"-q")
		BUILD_QUIET=-q
		;;
	"tests")
		TESTS=true
		;;
	"clean")
		${MAKE} distcleanrump
		exit 0
		;;
	*)
		RUMPLOC=${arg}
		BUILDRUMP=false
		;;
	esac
done

set -e
. ./buildrump.sh/subr.sh

# get sources
docheckout rumpsrc nbusersrc
${JUSTCHECKOUT} && { echo ">> $0 done" ; exit 0; }

# user libs to build
MORELIBS="external/bsd/flex/lib
	crypto/external/bsd/openssl/lib
	external/bsd/libpcap/lib"
LIBS="$(echo nbusersrc/lib/lib* | sed 's/nbusersrc/rumpsrc/g')"
for lib in ${MORELIBS}; do
	LIBS="${LIBS} rumpsrc/${lib}"
done

# Build rump kernel if requested
${BUILDRUMP} && ./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${STDJ} ${FLAGS} \
    -s rumpsrc -T rumptools -o rumpdynobj -d rumpdyn -V MKSTATICLIB=no fullbuild

# Now build a static libc.

# build tools
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${STDJ} ${FLAGS} -s rumpsrc \
    -T rumptools -o rumpobj -N -k -V MKPIC=no -V BUILDRUMP_SYSROOT=yes \
    tools kernelheaders install

# set rumpmake
RUMPMAKE=$(pwd)/rumptools/rumpmake

usermtree rump
userincludes ${RUMPMAKE} rumpsrc ${LIBS} rumpsrc/lib/librumpclient

for lib in ${LIBS}; do
	makeuserlib ${RUMPMAKE} ${lib}
done

if ${BUILDRUMP}; then
	RUMPLOC=${PWD}/rumpdyn
fi

if [ -n ${RUMPLOC} ]; then
	export PATH=${RUMPLOC}/bin:${PATH}
	export LIBRARY_PATH=${RUMPLOC}/lib
	export RUMPRUN_CPPFLAGS=-I${RUMPLOC}/include
fi

${MAKE} && if ${TESTS}; then tests/test.sh; fi
