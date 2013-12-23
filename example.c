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

static void
die(const char *fmt, ...)
{
        va_list va;

        va_start(va, fmt);
        vfprintf(stderr, fmt, va);
        va_end(va);
        exit(1);
}

int
main()
{
        char buf[8192];
        int fd;

        if (mkdir("/kern", 0755) == -1)
                die("mkdir /kern");
        if (mount("kernfs", "/kern", 0, NULL, 0) == -1)
                die("mount kernfs");
        if ((fd = open("/kern/version", O_RDONLY)) == -1)
                die("open /kern/version");
        printf("\nReading version info from /kern:\n");
        if (read(fd, buf, sizeof(buf)) <= 0)
                die("read version");
        printf("\n%s", buf);

        return 0;
}

