local build = require("lde-build")

local isWindows = jit.os == "Windows"
local isMac = jit.os == "OSX"
local libName = isWindows and "git2.dll" or (isMac and "libgit2.dylib" or "libgit2.so")

local commit = "1888a166e43420b2a5f93f104f2a99ec049b073c"
local url = "https://github.com/libgit2/libgit2/archive/" .. commit .. ".tar.gz"
local tarball = "libgit2-" .. commit .. ".tar.gz"

local content = build:fetch(url)
build:write(tarball, content)
build:extract(tarball, ".")
build:move("libgit2-" .. commit, "libgit2")

local srcDir = build.outDir .. "/libgit2"
local buildDir = srcDir .. "/build"

---@format disable-next
local gitMin = "-DBUILD_TESTS=OFF -DBUILD_CLI=OFF -DUSE_SSH=OFF -DUSE_GSSAPI=OFF -DUSE_NTLMCLIENT=OFF -DREGEX_BACKEND=builtin -DUSE_HTTP_PARSER=builtin -DUSE_BUNDLED_ZLIB=ON -DCMAKE_C_FLAGS=-g0"

local https
if isWindows then
	https = "WinHTTP"
elseif isMac then
	https = "SecureTransport"
else
	https = "OpenSSL"
end

build:sh('cmake -S "' .. srcDir .. '" -B "' .. buildDir .. '" -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DUSE_HTTPS=' .. https .. ' ' .. gitMin)
build:sh('cmake --build "' .. buildDir .. '" --config Release' .. (isWindows and "" or " -j$(nproc)"))

if isWindows then
	-- The pinned libgit2 names its shared library libgit2.dll. Multi-config
	-- generators (Ninja Multi-Config, Visual Studio) emit it under
	-- build/Release/; single-config ones (MinGW Makefiles) under build/.
	local dll = build:exists("libgit2/build/Release/libgit2.dll")
		and "libgit2/build/Release/libgit2.dll"
		or "libgit2/build/libgit2.dll"
	build:copy(dll, libName)
elseif isMac then
	build:copy("libgit2/build/libgit2.dylib", libName)
	build:sh('strip -x -o "' .. build.outDir .. '/' .. libName .. '.stripped" "' .. build.outDir .. '/' .. libName .. '"')
	build:move(libName .. '.stripped', libName)
else
	build:copy("libgit2/build/libgit2.so", libName)
	build:sh('strip --strip-unneeded --remove-section=.eh_frame --remove-section=.eh_frame_hdr -o "' .. build.outDir .. '/' .. libName .. '.stripped" "' .. build.outDir .. '/' .. libName .. '"')
	build:move(libName .. '.stripped', libName)
end
