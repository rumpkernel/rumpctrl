#include <sys/types.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <fcntl.h>

static int
die(const char *fmt, ...)
{
        va_list va;

        va_start(va, fmt);
        vfprintf(stderr, fmt, va);
        va_end(va);
	fprintf(stderr, "error %d\n", errno);
	return 1;
}

int
main()
{
        char buf[8192];
        int fd;

	printf("pid is %d\n", getpid());
        if (mkdir("/kern", 0755) == -1)
                return die("error mkdir /kern\n");
        if (mount("kernfs", "/kern", 0, NULL, 0) == -1)
                return die("error mount kernfs\n");
        if ((fd = open("/kern/version", O_RDONLY)) == -1)
                return die("error open /kern/version\n");
        printf("\nReading version info from /kern:\n");
        if (read(fd, buf, sizeof(buf)) <= 0)
                return die("error read version\n");
        printf("\n%s", buf);

        return 0;
}

