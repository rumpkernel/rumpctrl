#include <rump/rumpclient.h>

int
emul__fork(void)
{
	return rumpclient_fork();
}

int
emul__vfork14(void)
{
	return rumpclient_fork();
}

extern char **environ;

int
emul_execve(const char *filename, char *const argv[], char *const envp[])
{

	return rumpclient_exec(filename, argv, environ);
}

