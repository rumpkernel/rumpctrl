#include <sys/types.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <rump/rumpclient.h>
#include <rump/rump_syscalls.h>

#include "netbsd_init.h"

/* we are not supposed to use values below 100 but NetBSD libc does */
void rumprun_init (void) __attribute__((constructor (1)));

static void
die(const char *fmt, ...)
{
        va_list va;

        va_start(va, fmt);
        vfprintf(stderr, fmt, va);
        va_end(va);
        fputs("\n", stderr);
        exit(1);
}

void
rumprun_init()
{
        int ret, fd;

        ret = rumpclient_init();
        if (ret != 0)
                die("rumpclient init failed");
	_netbsd_init(isatty(STDOUT_FILENO));

        /* this has to be the greatest hack ever */
        while ((fd = rump_sys_kqueue()) < 3)
                continue;
        rump_sys_close(fd);
}
