#include <stddef.h>

extern char **_netbsd_environ;

static char *the_env[1] = { NULL } ;

void nullenv_init (void) __attribute__((constructor (102)));

void
nullenv_init()
{
	_netbsd_environ = &the_env;
}
