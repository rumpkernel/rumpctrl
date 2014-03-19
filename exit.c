#include <stdint.h>
#include <stdio.h>
#include <setjmp.h>

extern char *_netbsd__progname;

static jmp_buf buf;

int _netbsd_main(int argc, char **argv);
void _netbsd_exit(int status);

int
main(int argc, char **argv)
{
	int ret;

	_netbsd__progname = argv[0];

	if (! (ret = setjmp(buf))) {
        	ret = _netbsd_main(argc, argv);
		/* exit has not been called, so stdio may not be flushed etc */
		(void)_netbsd_exit(ret);
		return ret; /* actually will call _exit so will not reach here */
	}
	return ret;
}

void
emul__exit(int status)
{
	longjmp(buf, status);
}
