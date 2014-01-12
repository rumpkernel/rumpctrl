/*
 * Like rumprun, except connects to a remote service.
 * Note, std* will be directed to the remote service (and they are
 * not even open by default), so example.so needs to be judiciously
 * selected, at least for now.
 */

#include <sys/types.h>
#include <errno.h>
#include <inttypes.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dlfcn.h>

#include <rump/rumpclient.h>

static void
die(const char *fmt, ...)
{
        va_list va;

        va_start(va, fmt);
        vfprintf(stderr, fmt, va);
        va_end(va);
	fprintf(stderr, "\n");
        exit(1);
}

int
runprog(int (*dlmain)(int, char **), int argc, char *argv[])
{
  return (*dlmain)(argc, argv);
}


int
main(int argc, char *argv[])
{
	void *dl;
	int (*dlmain)(int, char **);
	int ret;

	if (argc == 1)
		die("supply a program to load");
	ret = rumpclient_init();
	if (ret != 0)
		die("rumpclient init failed");
	dl = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
	if (! dl)
		die("could not open library");
	dlmain = dlsym(dl, "emul_main_wrapper");
	if (! dlmain)
		die("could not find main() in library");
	return runprog(dlmain, argc - 1, argv + 1);	
}
