-- this is rumprun rewritten as a Lua script
-- unfortunately running shared libs multiple times is an issue, and exit() is bound to host exit() so it is not that useful

ffi = require "ffi"

if ffi.os:lower() == "linux" then
  assert(os.getenv("LD_DYNAMIC_WEAK"), "you need to set LD_DYNAMIC_WEAK=1 before running this script")
end

__libs = {}
local loadlibs = {"user", "", "vfs", "kern_tty", "dev", "net", "fs_tmpfs", "fs_kernfs", "fs_ptyfs",
                  "net_net", "net_local", "net_netinet", "net_shmif"}
for _, v in ipairs(loadlibs) do __libs[#__libs + 1] = ffi.load("rump" .. v, true) end

ffi.cdef [[
extern void *_netbsd_environ;
extern const char *__progname;
]]

ffi.cdef "int main(int argc, const char *argv[])"

ffi.cdef [[
typedef int32_t pid_t;

int rump_init(void);
int rump_pub_lwproc_rfork(int);
int rump_pub_lwproc_newlwp(pid_t);
void rump_pub_lwproc_switch(struct lwp *);
void rump_pub_lwproc_releaselwp(void);
struct lwp * rump_pub_lwproc_curlwp(void);
]]

ffi.C.rump_init()

ffi.C.rump_pub_lwproc_newlwp(1)
local origlwp = ffi.C.rump_pub_lwproc_curlwp()

local the_env = ffi.new("char *[1]", nil)

function register(lib)
  _G[lib] = function(...)
    local handle = ffi.load("./" .. lib .. ".so") -- TODO luajit wants these named libexample.so to find from LD_LIBRARY_PATH
    if not handle then print "failed to load library"; return end
    local argc = select('#', ...) + 1
    local av = {lib, ...}
    local argv = ffi.new("const char *[?]", argc, av)
    ffi.C.rump_pub_lwproc_rfork(0x01) -- RUMP_RFFDG
    handle._netbsd_environ = the_env
    ffi.C.__progname = lib
    local ret = handle.main(argc, argv)
    ffi.C.rump_pub_lwproc_releaselwp() -- exit this process
    ffi.C.rump_pub_lwproc_switch(origlwp)
    handle = nil
    collectgarbage("collect") -- force unload lib
    return ret
  end
  return _G[lib]
end

setmetatable(_G, {__index = function(_, k) return register(k) end})


