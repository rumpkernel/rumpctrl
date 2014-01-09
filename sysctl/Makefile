DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
CFLAGS=-nostdinc -nostdlib -I../rump/include -I. -O2 -g -Wall -fPIC ${DEFUNDEF} -std=gnu99

SRCS=sysctl.c sysctl_hostops.c

OBJS=$(SRCS:.c=.o)

all:	sysctlall.o

dummy.o:	dummy.c

sysctlall.o:	${OBJS} dummy.o
		${CC} -Wl,-r -nostdlib ${OBJS} ${LIBS} dummy.o -o $@

clean:		
		rm -f *.o *.so *~
