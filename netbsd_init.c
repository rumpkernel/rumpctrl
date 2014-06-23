/* init routines for NetBSD namespace */

#include <sys/types.h>

#include <sys/exec_elf.h>
#include <sys/exec.h>

#include <stdio.h>
#include <string.h>

/* this whole thing is a bit XXX */
static struct ps_strings thestrings;
AuxInfo myaux[2];

#include "netbsd_init.h"

void
_netbsd_init(int stdouttty)
{
	extern struct ps_strings *__ps_strings;

	memset(&thestrings, 0, sizeof(thestrings));
	thestrings.ps_argvstr = (void *)((char *)&myaux - 2); /* well, uuuuh? */
	__ps_strings = &thestrings;

	if (stdouttty)
		setlinebuf(stdout);

	_lwp_rumprun_scheduler_init();
}
