local outDir = os.getenv("LDE_OUTPUT_DIR")
local sep = string.sub(package.config, 1, 1)
local isWindows = jit.os == "Windows"
local isMac = jit.os == "OSX"
local isAndroid = os.getenv("ANDROID_ROOT") ~= nil
local scriptDir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
local src = scriptDir .. "vendor" .. sep .. "libgit2"
local libName = isWindows and "git2.dll" or (isMac and "libgit2.dylib" or "libgit2.so")
local outLib = outDir .. sep .. libName

if io.open(outLib, "rb") then return end

local function exec(cmd)
	local ret = os.execute(cmd)
	assert(ret == 0 or ret == true, "command failed: " .. cmd)
end

local build = src .. sep .. "build"

---@format disable-next
local gitMin = "-DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_SSH=OFF -DUSE_GSSAPI=OFF -DUSE_NTLMCLIENT=OFF -DREGEX_BACKEND=builtin -DUSE_HTTP_PARSER=builtin -DCMAKE_C_FLAGS=-g0"

local https, cmakeExtra
if isWindows then
	https = "WinHTTP"
	cmakeExtra = ""
elseif isMac then
	https = "SecureTransport"
	cmakeExtra = ""
else
	https = "OpenSSL"
	cmakeExtra = ""
end

exec('cmake -S "' .. src .. '" -B "' .. build .. '" -DBUILD_SHARED_LIBS=ON -DUSE_HTTPS=' .. https .. ' ' .. gitMin .. (cmakeExtra ~= "" and (' ' .. cmakeExtra) or ""))
exec('cmake --build "' .. build .. '" --config Release' .. (isWindows and "" or " -j$(nproc)"))

if isWindows then
	exec('copy "' .. build .. '\\Release\\git2.dll" "' .. outLib .. '"')
elseif isMac then
	exec('cp "' .. build .. '/libgit2.dylib" "' .. outLib .. '"')
	exec('strip -x "' .. outLib .. '"')
else
	exec('cp "' .. build .. '/libgit2.so" "' .. outLib .. '"')
	exec('strip --strip-unneeded --remove-section=.eh_frame --remove-section=.eh_frame_hdr "' .. outLib .. '"')
end
