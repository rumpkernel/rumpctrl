#include <sys/types.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <rump/rump.h>
#include <rump/rump_syscalls.h>

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
main(int argc, char **argv)
{
	if (argc == 1)
		die("supply a program to load");

	rump_init();
	// run main()
	rump_sys_reboot(0, NULL);
	return 0;
}

