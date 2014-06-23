void _netbsd_init(int);

void _lwp_rumprun_scheduler_init(void);

int  rumprun_ucontext(void *, size_t, void (*)(void *), void *, void *, size_t);
