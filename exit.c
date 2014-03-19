#include <stdint.h>
#include <stdio.h>
#include <setjmp.h>

extern char *_netbsd__progname;

static jmp_buf buf;

int _netbsd_main(int argc, char **argv);

int
main(int argc, char **argv)
{
	int ret;

	_netbsd__progname = argv[0];

	if (! (ret = setjmp(buf))) {
        	return _netbsd_main(argc, argv);
	}
	return ret;
}

void
emul__exit(int status)
{
	longjmp(buf, status);
}
