#include <errno.h>

#define _NETBSD_ENOTSUP	86

#define STUB(name)                              \
  int name(void); int name(void) {              \
        static int done = 0;                    \
        errno = _NETBSD_ENOTSUP;                        \
        if (done) return errno; done = 1;     \
      /*printk("STUB ``%s'' called\n", #name);*/\
        return errno;}

#define STUB_ABORT(name) void name(void); void name(void) { abort(); }

STUB(emul__fork);
STUB(emul__vfork14);
STUB(emul_execve);

