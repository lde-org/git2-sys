local outDir = os.getenv("LDE_OUTPUT_DIR")
local sep = string.sub(package.config, 1, 1)
local isWindows = sep == "\\"
local scriptDir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
local src = scriptDir .. "vendor" .. sep .. "libgit2"
local outLib = outDir .. sep .. (isWindows and "git2.dll" or "libgit2.so")

if io.open(outLib, "rb") then return end

local function exec(cmd)
    local ret = os.execute(cmd)
    assert(ret == 0 or ret == true, "command failed: " .. cmd)
end

local build = src .. sep .. "build"
exec('cmake -S "' .. src .. '" -B "' .. build .. '" -DBUILD_SHARED_LIBS=ON -DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_SSH=OFF -DUSE_HTTPS=OpenSSL')
exec('cmake --build "' .. build .. '" --config Release -j' .. (isWindows and "" or "$(nproc)"))

if isWindows then
    exec('copy "' .. build .. '\\Release\\git2.dll" "' .. outLib .. '"')
else
    exec('cp "' .. build .. '/libgit2.so" "' .. outLib .. '"')
end
