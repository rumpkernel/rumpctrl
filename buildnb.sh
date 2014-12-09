#!/bin/sh

die ()
{

	echo '>> ERROR:' >&2
	echo ">> $*" >&2
	exit 1
}

if ! ${CC:-cc} --version | grep -q 'Free Software Foundation'; then
	die '>> rumprun-posix currently requires CC=gcc'
fi

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
BUILDZFS=false
BUILDFIBER=false

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
	"-qq")
		BUILD_QUIET=-qq
		;;
	"tests")
		TESTS=true
		;;
	"clean")
		${MAKE} distcleanrump
		exit 0
		;;
	"zfs")
		BUILDZFS=true
		;;
	"fiber")
		BUILDFIBER=true
		;;
	*)
		RUMPLOC=${arg}
		BUILDRUMP=false
		;;
	esac
done
export BUILDZFS
export BUILDFIBER

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

${BUILDZFS} && \
    ZFSLIBS="$(ls -d rumpsrc/external/cddl/osnet/lib/lib* | grep -v libdtrace)"
LIBS="$(stdlibs rumpsrc) ${ZFSLIBS}"

${BUILDFIBER} && FIBERFLAGS="-V RUMPUSER_THREADS=fiber -V RUMP_CURLWP=hypercall"

# Build rump kernel if requested
${BUILDRUMP} && ./buildrump.sh/buildrump.sh ${BUILD_QUIET} \
    ${EXTRAFLAGS} ${FLAGS} ${FIBERFLAGS} \
    -s rumpsrc -T rumptools -o rumpdynobj -d rumpdyn -V MKSTATICLIB=no \
    $(${BUILDZFS} && echo -V MKZFS=yes) fullbuild

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
userincludes rumpsrc ${LIBS} rumpsrc/lib/librumpclient rumpsrc/external/bsd/libelf

for lib in ${LIBS}; do
	makeuserlib ${lib}
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

mkdir -p bin

${MAKE} && if ${TESTS}; then tests/test.sh; fi

echo
echo ">> $0 ran successfully"
exit 0
