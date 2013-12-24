#include <sys/types.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>

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
runprog(int (*dlmain)(int, char **), int argc, char *argv[])
{
  return (*dlmain)(argc - 1, argv + 1);
}


int
main(int argc, char *argv[])
{
	void *dl;
	int (*dlmain)(int, char **);
	int ret;

	if (argc == 1)
		die("supply a program to load");
	dl = dlopen(argv[1], RTLD_LAZY | RTLD_DEEPBIND);
	if (! dl)
		die("could not open library");
	dlmain = dlsym(dl, "main");
	if (! dlmain)
		die("could not find main() in library");
	rump_init();
	ret = runprog(dlmain, argc - 1, argv + 1);	
	rump_sys_reboot(0, NULL);
	return ret;
}

