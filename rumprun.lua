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

ffi.cdef "int main(int argc, char *argv[])"

ffi.cdef "int rump_init(void);"
ffi.C.rump_init()

function register(lib)
  local handle = ffi.load("./" .. lib .. ".so") -- TODO luajit wants these named libexample.so to find from LD_LIBRARY_PATH
  if not handle then print "failed to load library"; return end
  _G[lib] = function(...)
    local argc = select('#', ...)
    local argv = ffi.new("char *[?]", argc)
    for i, v in ipairs{...} do argv[i - 1] = ffi.cast("char *", v) end
    return handle.main(argc, argv)
  end
end

