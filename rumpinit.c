#include <sys/types.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <rump/rump.h>

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
        int ret;

        ret = rump_init();
        if (ret != 0)
                die("rump init failed");
	_netbsd_init(isatty(STDOUT_FILENO));
}
