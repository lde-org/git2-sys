local build = require("lde-build")

local isWindows = jit.os == "Windows"
local isMac = jit.os == "OSX"
local libName = isWindows and "git2.dll" or (isMac and "libgit2.dylib" or "libgit2.so")

local url = "https://github.com/libgit2/libgit2/archive/refs/tags/v1.8.5.tar.gz"
local tarball = "libgit2-1.8.5.tar.gz"

local content = build:fetch(url)
build:write(tarball, content)
build:extract(tarball, ".")
build:move("libgit2-1.8.5", "libgit2")

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

build:sh('cmake -S "' ..
srcDir .. '" -B "' .. buildDir .. '" -DBUILD_SHARED_LIBS=ON -DUSE_HTTPS=' .. https .. ' ' .. gitMin)
build:sh('cmake --build "' .. buildDir .. '" --config Release' .. (isWindows and "" or " -j$(nproc)"))

if isWindows then
	build:copy("libgit2/build/Release/git2.dll", libName)
elseif isMac then
	build:copy("libgit2/build/libgit2.dylib", libName)
	build:sh('strip -x "' .. build.outDir .. '/' .. libName .. '"')
else
	build:copy("libgit2/build/libgit2.so", libName)
	build:sh('strip --strip-unneeded --remove-section=.eh_frame --remove-section=.eh_frame_hdr "' ..
		build.outDir .. '/' .. libName .. '"')
end
