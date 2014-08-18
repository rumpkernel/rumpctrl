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
EXTRAFLAGS="${STDJ}"
CHECKOUT=true
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
	"-H")
		EXTRAFLAGS="${EXTRAFLAGS} -H"
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
[ ! -f ./buildrump.sh/subr.sh ] && git submodule update --init buildrump.sh
. ./buildrump.sh/subr.sh

# get sources
if ${CHECKOUT}; then
	if git submodule status rumpsrc | grep -q '^-' ; then
		git submodule update --init --recursive rumpsrc
	fi
fi
${JUSTCHECKOUT} && { echo ">> $0 done" ; exit 0; }

# user libs to build
MORELIBS="external/bsd/flex/lib
	crypto/external/bsd/openssl/lib
	external/bsd/libpcap/lib"
LIBS="$(ls -d rumpsrc/lib/lib* | grep -v librump)"
for lib in ${MORELIBS}; do
	LIBS="${LIBS} rumpsrc/${lib}"
done

# Build rump kernel if requested
${BUILDRUMP} && ./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${EXTRAFLAGS} ${FLAGS} \
    -s rumpsrc -T rumptools -o rumpdynobj -d rumpdyn -V MKSTATICLIB=no fullbuild

# build tools (for building libs)
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${EXTRAFLAGS} ${FLAGS} -s rumpsrc \
    -T rumptools -o rumpobj -F CFLAGS="-nostdinc -isystem ${PWD}/rump/include" \
    -N -k -V MKPIC=no -V BUILDRUMP_SYSROOT=yes \
    tools kernelheaders install

# set some special variables currently required by libpthread.  Doing
# it this way preserves the ability to compile libpthread during development
# cycles with just "rumpmake"
cat >> rumptools/mk.conf << EOF
.if defined(LIB) && \${LIB} == "pthread"
PTHREAD_CANCELSTUB=no
CPPFLAGS+=      -D_PLATFORM_MAKECONTEXT=_lwp_rumprun_makecontext
CPPFLAGS+=      -D_PLATFORM_GETTCB=_lwp_rumprun_gettcb
.endif  # LIB == pthread
EOF

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
	export LD_LIBRARY_PATH=${RUMPLOC}/lib
	export RUMPRUN_CPPFLAGS=-I${RUMPLOC}/include
fi

${MAKE} && if ${TESTS}; then tests/test.sh; fi

mkdir -p bin

echo
echo ">> $0 ran successfully"
exit 0
