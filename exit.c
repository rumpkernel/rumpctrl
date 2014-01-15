#include <stdint.h>
#include <stdio.h>
#include <setjmp.h>

extern char *__progname;

static jmp_buf buf;

int main(int argc, char **argv);

int
emul_main_wrapper(int argc, char **argv)
{
	int ret;

	__progname = argv[0];

	if (! (ret = setjmp(buf))) {
        	return main(argc, argv);
	}
	return ret;
}

void
_exit(int status)
{
	longjmp(buf, status);
}
