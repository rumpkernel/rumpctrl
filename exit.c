#include <stdint.h>
#include <stdio.h>
#include <setjmp.h>

static jmp_buf buf;

extern char *_netbsd__progname;
int _netbsd_main(int argc, char **argv);
void _netbsd_exit(int status);

static int ret = 0;

int
main(int argc, char **argv)
{
	int jret;

	_netbsd__progname = argv[0];

	if (! (jret = setjmp(buf))) {
		/* exit has not been called, so stdio may not be flushed etc */
        	_netbsd_exit(_netbsd_main(argc, argv));
		/* will call _exit so will not reach here */
	}
	return ret;
}

void
emul__exit(int status)
{

	ret = status;
	longjmp(buf, status);
}
