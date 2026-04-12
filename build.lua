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
local https = isWindows and "WinHTTP" or "OpenSSL"
local ndkRoot = os.getenv("ANDROID_NDK_ROOT")
local cmakeExtra = ""

---@format disable-next
local gitMin = "-DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_SSH=OFF -DUSE_GSSAPI=OFF -DUSE_NTLMCLIENT=OFF -DREGEX_BACKEND=builtin -DUSE_HTTP_PARSER=builtin -DCMAKE_C_FLAGS=-g0"

if isAndroid and ndkRoot then
	local toolchain = ndkRoot .. "/build/cmake/android.toolchain.cmake"
	cmakeExtra = ' -DCMAKE_TOOLCHAIN_FILE="' .. toolchain .. '" -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24'
elseif isMac then
	local f = io.popen("brew --prefix openssl")
	if f then
		local prefix = f:read("*l"); f:close()
		if prefix and prefix ~= "" then
			cmakeExtra = ' -DOPENSSL_ROOT_DIR="' .. prefix .. '"'
		end
	end
end

---@format disable-next
exec('cmake -S "' .. src .. '" -B "' .. build .. '" -DBUILD_SHARED_LIBS=ON -DUSE_HTTPS=' .. https .. ' ' .. gitMin .. cmakeExtra)
exec('cmake --build "' .. build .. '" --config Release' .. (isWindows and "" or " -j$(nproc)"))

---@format disable-next
if isWindows then
	exec('copy "' .. build .. '\\Release\\git2.dll" "' .. outLib .. '"')
elseif isMac then
	exec('cp "' .. build .. '/libgit2.dylib" "' .. outLib .. '"')
	exec('strip -x "' .. outLib .. '"')
else
	exec('cp "' .. build .. '/libgit2.so" "' .. outLib .. '"')
	local strip = (isAndroid and ndkRoot) and (ndkRoot .. "/toolchains/llvm/prebuilt/linux-aarch64/bin/llvm-strip") or "strip"
	exec(strip .. ' --strip-unneeded --remove-section=.eh_frame --remove-section=.eh_frame_hdr "' .. outLib .. '"')
end
