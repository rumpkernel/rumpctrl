DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
CFLAGS=-nostdinc -nostdlib -I../rump/include -I. -O2 -g -Wall -fPIC ${DEFUNDEF} -DINET6
LP=../rump/lib
LIBS=${LP}/libutil.a ${LP}/libprop.a

SRCS=af_atalk.c af_inetany.c af_link.c carp.c ether.c ifconfig.c parse.c tunnel.c vlan.c af_inet6.c af_inet.c agr.c env.c ieee80211.c ifconfig_hostops.c media.c util.c

OBJS=$(SRCS:.c=.o)

all:	ifall.o

dummy.o:	dummy.c

ifall.o:	${OBJS} dummy.o
		${CC} -Wl,-r -nostdlib ${OBJS} ${LIBS} dummy.o -o $@

clean:		
		rm -f *.o *.so *~ libutil/*.o libprop/*.o
