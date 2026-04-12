local test = require("lde-test")
local git2 = require("git2-sys")

local sep = string.sub(package.config, 1, 1)
local isWindows = sep == "\\"

local tmpBase = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp") .. sep .. "git2-sys-test-" .. tostring(os.time())

local function mkTmp(suffix)
	local dir = tmpBase .. suffix
	if isWindows then
		os.execute('mkdir "' .. dir .. '"')
	else
		os.execute('mkdir -p "' .. dir .. '"')
	end
	return dir
end

local null = isWindows and ">nul 2>&1" or ">>/dev/null 2>&1"

local function mkCommit(dir, msg)
	local touch = isWindows and ('type nul > "' .. dir .. sep .. 'f"') or ('touch "' .. dir .. '/f"')
	os.execute('git -C "' .. dir .. '" init ' .. null)
	os.execute('git -C "' .. dir .. '" config user.email "t@t.com"')
	os.execute('git -C "' .. dir .. '" config user.name "T"')
	os.execute(touch)
	os.execute('git -C "' .. dir .. '" add f ' .. null)
	os.execute('git -C "' .. dir .. '" commit -m "' .. msg .. '" ' .. null)
end

test.it("init creates a non-bare repo", function()
	local repo = git2.init(mkTmp("init"))
	test.truthy(repo:path():find(".git"))
	test.equal(repo:isBare(), false)
	test.equal(repo:headUnborn(), true)
	repo:free()
end)

test.it("init bare creates a bare repo", function()
	local repo = git2.init(mkTmp("bare"), true)
	test.equal(repo:isBare(), true)
	repo:free()
end)

test.it("open existing repo works", function()
	local src = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
	local repo = git2.open(src .. "..")
	test.truthy(repo:path())
	test.equal(repo:isBare(), false)
	repo:free()
end)

test.it("head returns a 40-char sha", function()
	local dir = mkTmp("head")
	mkCommit(dir, "init")
	local repo = git2.open(dir)
	test.equal(#repo:head(), 40)
	repo:free()
end)

test.it("commitLookup returns correct metadata", function()
	local dir = mkTmp("meta")
	mkCommit(dir, "hello world")
	local repo = git2.open(dir)
	local sha = repo:head()
	local c = repo:commitLookup(sha)
	test.equal(c.id, sha)
	test.truthy(c.summary:find("hello world"))
	test.equal(c.author.name, "T")
	test.equal(c.author.email, "t@t.com")
	test.truthy(c.time > 0)
	repo:free()
end)

test.it("revparse HEAD matches head()", function()
	local dir = mkTmp("rev")
	mkCommit(dir, "rev")
	local repo = git2.open(dir)
	test.equal(repo:revparse("HEAD"), repo:head())
	repo:free()
end)

-- NOTE: requires network access
test.it("clone clones a remote repo", function()
	local dir = mkTmp("clone") .. sep .. "repo"
	local repo = git2.clone("https://github.com/lde-org/lde", dir)
	test.truthy(repo:workdir())
	test.equal(repo:headUnborn(), false)
	test.equal(#repo:head(), 40)
	repo:free()
	local f = io.open(dir .. sep .. "README.md", "r")
	test.truthy(f)
	if f then f:close() end
end)

test.it("clone with branch checks out the right branch", function()
	local dir = mkTmp("clone-branch") .. sep .. "repo"
	local repo = git2.clone("https://github.com/lde-org/lde", dir, "master")
	test.equal(repo:headUnborn(), false)
	repo:free()
end)
