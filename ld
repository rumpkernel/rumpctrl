#!/bin/sh

set -e

fail () { echo >&2 "stunt ld: $*"; exit 127; }

noshift () { fail "no arg for $a"; }

echo "stunt ld: $*"

ALLARGS=$*

CC=${REALCC:-cc}
LD=${LD:-ld}
OBJCOPY=${OBJCOPY:-objcopy}

LIBC=false

while [ $# != 0 ]; do
	a=$1; shift
	case "$a" in
	-m)
		march="$1"; shift || noshift
		outargs="$outargs $a $march"
		;;
	-o)
        	outfile="$1"; shift || noshift
        	;;
	--as-needed|--no-as-needed)
		;;
	--stunt-intermediate)
        	inter1="$1"; shift || noshift
        	inter2="$1"; shift || noshift
        	;;
	-lc)
		LIBC=true
		;;
	-lgcc|-lgcc_s)
		# added later
		;;
	[^-]*|-L*|-l*|--whole-archive|--no-whole-archive)
		outargs="$outargs $a"
		;;
	*crt1.o|*crti.o|*crtbegin.o)
		CRTS="${CRTS} $a"
		;;
	*crtend.o|*crtn.o)
		CRTE="${CRTE} $a"
		;;
	*.o|*.ro|*.a)
		INFILES="${INFILES} $a"
		;;
	*)
		outargs="$outargs $a"
		;;
	esac
done

if [ x"$outfile" = x ]; then outfile=a.out; fi

mkremote()
{

set -x

# TODO should use /tmp this is for debug
OBJDIR="obj-rr"
# XXX temp just reusing old script
NAME=ldscript
# -lrt not always needed TODO work out at build time
UNAME=$(uname -s)
[ ${UNAME} = Linux ] && DLFLAG="-ldl -lrt"
# XXX embed LIBRARY_PATH and LIBC into script
LIBRARY_PATH=/home/justin/rump/rumprun/rumpdyn/lib
RUMPCLIENT="-L${LIBRARY_PATH} -Wl,-R${LIBRARY_PATH} -lrumpclient ${DLFLAG}"
LIBC=rump/lib/libc.a

${CC} ${LDFLAGS} -Wl,-r -nostdlib ${INFILES} -o ${OBJDIR}/${NAME}.o
${OBJCOPY} --redefine-syms=host.map ${OBJDIR}/${NAME}.o ${OBJDIR}/tmp0_${NAME}.o
${CC} ${LDFLAGS} -Wl,-r ${OBJDIR}/tmp0_${NAME}.o netbsd_init.o -nostdlib ${LIBC} -o ${OBJDIR}/tmp1_${NAME}.o 2>/dev/null
${OBJCOPY} --redefine-syms=namespace.map ${OBJDIR}/tmp1_${NAME}.o
${OBJCOPY} --redefine-syms=extra.map ${OBJDIR}/tmp1_${NAME}.o
${OBJCOPY} --redefine-syms=rump.map ${OBJDIR}/tmp1_${NAME}.o
${OBJCOPY} --redefine-syms=weakasm.map ${OBJDIR}/tmp1_${NAME}.o
${OBJCOPY} --redefine-syms=readwrite.map ${OBJDIR}/tmp1_${NAME}.o
${OBJCOPY} --redefine-syms=emul.map ${OBJDIR}/tmp1_${NAME}.o
${OBJCOPY} --redefine-syms=netbsd.map ${OBJDIR}/tmp1_${NAME}.o
${CC} ${LDFLAGS} -Wl,-r -nostdlib -Wl,-dc ${OBJDIR}/tmp1_${NAME}.o _lwp.o readwrite.o -o ${OBJDIR}/tmp2_${NAME}.o  2>/dev/null
${OBJCOPY} --redefine-syms=errno.map ${OBJDIR}/tmp2_${NAME}.o
${OBJCOPY} -w --localize-symbol='*' ${OBJDIR}/tmp2_${NAME}.o
${OBJCOPY} -w --globalize-symbol='_netbsd_*' ${OBJDIR}/tmp2_${NAME}.o
#${LD} ${outargs} ${CRTS} ${OBJDIR}/tmp2_${NAME}.o emul.o rumpclient.o remoteinit.o ${RUMPCLIENT} -lgcc --as-needed -lgcc_s --no-as-needed -lc -lgcc --as-needed -lgcc_s --no-as-needed ${CRTE} -o ${outfile}
${CC} ${OBJDIR}/tmp2_${NAME}.o emul.o rumpclient.o remoteinit.o ${RUMPCLIENT} -o ${outfile}
}

if ${LIBC}
then
	mkremote
else
	${LD} ${ALLARGS}
fi


