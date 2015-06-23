#!/bin/sh

appendconfig ()
{

	echo $1=\"$(eval echo \${$1})\" >> ./config.sh
	echo $1=$(eval echo \${$1}) >> ./config.mk
}

STDJ='-j4'
EXTRAFLAGS="${STDJ}"
TESTS=false
BUILDZFS=false
BUILDFIBER=false
BUILDLOCAL=false
RUMPSRC=src-netbsd

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
	"local")
		BUILDLOCAL=true
		;;
	*)
		RUMPLOC=${arg}
		;;
	esac
done

[ ! -f ./buildrump.sh/subr.sh ] && git submodule update --init buildrump.sh
. ./buildrump.sh/subr.sh

${MAKE} --version | grep -q 'GNU Make' \
    || die GNU Make required, '$MAKE' "(${MAKE})" is not

set -e

# Check sources
if git submodule status ${RUMPSRC} 2>/dev/null | grep -q '^-' \
    || git submodule status buildrump.sh 2>/dev/null | grep -q '^-'
then
	echo '>>'
	echo '>> submodules missing.  run "git submodule update --init"'
	echo '>>'
	exit 1
fi
if git submodule status ${RUMPSRC} 2>/dev/null | grep -q '^+' \
    || git submodule status buildrump.sh 2>/dev/null | grep -q '^+'
	then
	echo '>>'
	echo '>> Your git submodules are out-of-date'
	echo '>> Forgot to run "git submodule update" after pull?'
	echo '>> (sleeping for 5s, press ctrl-C to abort)'
	echo '>>'
	echo -n '>>'
	for x in 1 2 3 4 5; do echo -n ' !' ; sleep 1 ; done
fi


rm -f ./config.mk ./config.sh

${BUILDZFS} && \
    ZFSLIBS="$(ls -d ${RUMPSRC}/external/cddl/osnet/lib/lib* | grep -v libdtrace)"
LIBS="$(stdlibs ${RUMPSRC}) ${ZFSLIBS}"

appendconfig BUILDZFS
appendconfig BUILDFIBER
appendconfig RUMPSRC

${BUILDFIBER} && FIBERFLAGS="-V RUMPUSER_THREADS=fiber -V RUMP_CURLWP=hypercall"

#
# We build tools twice: once to create a host version of librumpclient
# and another time to build all of the other libs.  Technically,
# the difference is just a bit of mk.conf, but it's a lot easier to
# build twice than start poking in the general mk.conf file.
#

# host lib tools (for building librumpclient)
./buildrump.sh/buildrump.sh ${BUILD_QUIET} \
    ${EXTRAFLAGS} ${FLAGS} ${FIBERFLAGS} \
    -s ${RUMPSRC} -T hosttools -o hostobj -d hostlib -V MKSTATICLIB=no \
    tools

# tools and headers for clientside libs
./buildrump.sh/buildrump.sh ${BUILD_QUIET} ${EXTRAFLAGS} ${FLAGS} -s ${RUMPSRC} \
    -T rumptools -o rumpobj -F CFLAGS="-nostdinc -isystem ${PWD}/rump/include" \
    -k -V MKPIC=no -V BUILDRUMP_SYSROOT=yes \
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

#
# Build host bits.  There's no real infra for this, so it's mostly
# a matter of running rumpmake in the right places with the right args.
#
RUMPMAKE=$(pwd)/hosttools/rumpmake
mkdir -p hostlib/include/rump
mkdir -p hostlib/lib
(
	# librumpclient dependency
	cd ${RUMPSRC}/lib/librumpuser
	${RUMPMAKE} includes
)
(
	# librumpclient dependency
	cd ${RUMPSRC}/sys/rump/include
	${RUMPMAKE} includes
)
(
	cd ${RUMPSRC}/lib/librumpclient
	${RUMPMAKE} includes \
	    && ${RUMPMAKE} MKMAN=no dependall \
	    && ${RUMPMAKE} MKMAN=no install
)

# set rumpmake
RUMPMAKE=$(pwd)/rumptools/rumpmake
appendconfig RUMPMAKE

usermtree rump
userincludes ${RUMPSRC} ${LIBS} ${RUMPSRC}/external/bsd/libelf
( cd ${RUMPSRC}/lib/librumpclient && ${RUMPMAKE} includes )

for lib in ${LIBS}; do
	makeuserlib ${lib}
done

appendconfig BUILDLOCAL

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
