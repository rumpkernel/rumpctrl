#!/bin/sh

# process options

appendconfig ()
{

	echo $1=\"$(eval echo \${$1})\" >> ./config.sh
	echo $1=$(eval echo \${$1}) >> ./config.mk
}

STDJ='-j4'
EXTRAFLAGS="${STDJ}"
CHECKOUT=true
JUSTCHECKOUT=false
BUILDRUMP=true
TESTS=false
BUILDZFS=false
BUILDFIBER=false
RUMPSRC=rumpsrc

# figure out where gmake lies
if [ -z "${MAKE}" ]; then
	MAKE=make
	type gmake >/dev/null && MAKE=gmake
fi

# XXX TODO set FLAGS from -F options here to pass to buildrump.sh

while getopts '?Hqs:' opt; do
	case "$opt" in
	"H")
		EXTRAFLAGS="${EXTRAFLAGS} -H"
		;;
	"q")
		BUILD_QUIET=${BUILD_QUIET:=-}q
		;;
	"s")
		RUMPSRC=${OPTARG}
		;;
	"?")
		exit 1
	esac
done
shift $((${OPTIND} - 1))

for arg in "$@"; do
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
	"pthread")
		BUILDFIBER=false
		;;
	*)
		RUMPLOC=${arg}
		BUILDRUMP=false
		;;
	esac
done

[ ! -f ./buildrump.sh/subr.sh ] && git submodule update --init buildrump.sh
. ./buildrump.sh/subr.sh

if ! ${CC:-cc} --version | grep -q 'Free Software Foundation'; then
	die 'rumprun-posix currently requires CC=gcc'
fi

${MAKE} --version | grep -q 'GNU Make' \
    || die GNU Make required, '$MAKE' "(${MAKE})" is not

set -e

# get sources
if ${CHECKOUT}; then
	if git submodule status ${RUMPSRC} | grep -q '^-' ; then
		git submodule update --init --recursive ${RUMPSRC}
	fi
fi
${JUSTCHECKOUT} && { echo ">> $0 done" ; exit 0; }

rm -f ./config.mk ./config.sh

${BUILDZFS} && \
    ZFSLIBS="$(ls -d ${RUMPSRC}/external/cddl/osnet/lib/lib* | grep -v libdtrace)"
LIBS="$(stdlibs ${RUMPSRC}) ${ZFSLIBS}"

appendconfig BUILDZFS
appendconfig ZFSLIBS
appendconfig BUILDFIBER
appendconfig RUMPSRC

${BUILDFIBER} && FIBERFLAGS="-V RUMPUSER_THREADS=fiber -V RUMP_CURLWP=hypercall"

# Build rump kernel if requested
${BUILDRUMP} && ./buildrump.sh/buildrump.sh ${BUILD_QUIET} \
    ${EXTRAFLAGS} ${FLAGS} ${FIBERFLAGS} \
    -s ${RUMPSRC} -T rumptools -o rumpdynobj -d rumpdyn -V MKSTATICLIB=no \
    $(${BUILDZFS} && echo -V MKZFS=yes) fullbuild

# build tools (for building libs)
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${EXTRAFLAGS} ${FLAGS} -s ${RUMPSRC} \
    -T rumptools -o rumpobj -F CFLAGS="-nostdinc -isystem ${PWD}/rump/include" \
    -N -k -V MKPIC=no -V BUILDRUMP_SYSROOT=yes \
    tools kernelheaders install

# set some special variables currently required by libpthread.  Doing
# it this way preserves the ability to compile libpthread during development
# cycles with just "rumpmake"
cat >> rumptools/mk.conf << EOF
.if defined(LIB) && \${LIB} == "pthread"
.PATH:	$(pwd)
PTHREAD_CANCELSTUB=no
PTHREAD_MAKELWP=pthread_makelwp_rumprunposix.c
CPPFLAGS+=      -D_PTHREAD_GETTCB_EXT=_lwp_rumprun_gettcb
.endif  # LIB == pthread
EOF

# set rumpmake
RUMPMAKE=$(pwd)/rumptools/rumpmake
appendconfig RUMPMAKE

usermtree rump
userincludes ${RUMPSRC} ${LIBS} ${RUMPSRC}/lib/librumpclient ${RUMPSRC}/external/bsd/libelf

for lib in ${LIBS}; do
	makeuserlib ${lib}
done

if ${BUILDRUMP}; then
	RUMPLOC=${PWD}/rumpdyn
fi

if [ -n ${RUMPLOC} ]; then
	LIBRARY_PATH=${RUMPLOC}/lib
	LD_LIBRARY_PATH=${RUMPLOC}/lib
	RUMPRUN_CPPFLAGS=-I${RUMPLOC}/include

	appendconfig LIBRARY_PATH
	appendconfig LD_LIBRARY_PATH
	appendconfig RUMPRUN_CPPFLAGS
fi

mkdir -p bin

${MAKE}
if ${TESTS}; then
	[ -n "${RUMPLOC}" ] || die need rump kernel for tests
	export PATH=${RUMPLOC}/bin:${PATH}
	if ${BUILDFIBER}; then
		tests/test.sh fiber
	else
		tests/test.sh pthread
	fi
fi

echo
echo ">> $0 ran successfully"
exit 0
