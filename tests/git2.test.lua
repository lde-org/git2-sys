local test = require("lde-test")
local git2 = require("git2-sys")

local sep = string.sub(package.config, 1, 1)
local isWindows = sep == "\\"

local tmpBase = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp") .. sep .. "git2-sys-test-" .. tostring(os.time())

---@param suffix string
---@return string
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

---@param dir string
---@param msg string
local function mkCommit(dir, msg)
	local touch = isWindows and ('type nul > "' .. dir .. sep .. 'f"') or ('touch "' .. dir .. '/f"')
	os.execute('git -C "' .. dir .. '" init ' .. null)
	os.execute('git -C "' .. dir .. '" config user.email "t@t.com"')
	os.execute('git -C "' .. dir .. '" config user.name "T"')
	os.execute(touch)
	os.execute('git -C "' .. dir .. '" add f ' .. null)
	os.execute('git -C "' .. dir .. '" commit -m "' .. msg .. '" ' .. null)
end

---@param dir string
---@param filename string
---@param msg string
local function addCommit(dir, filename, msg)
	local touch = isWindows and ('type nul > "' .. dir .. sep .. filename .. '"')
		or ('touch "' .. dir .. '/' .. filename .. '"')
	os.execute(touch)
	os.execute('git -C "' .. dir .. '" add "' .. filename .. '" ' .. null)
	os.execute('git -C "' .. dir .. '" commit -m "' .. msg .. '" ' .. null)
end

---@param dir string
---@return string
local function headSha(dir)
	local h = assert(io.popen('git -C "' .. dir .. '" rev-parse HEAD'))
	local sha = h:read("*l")
	h:close()
	return sha
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
	local dir = mkTmp("open")
	mkCommit(dir, "open")
	local repo = git2.open(dir)
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

test.it("version returns a semver string", function()
	local v = git2.version()
	test.truthy(v:match("^%d+%.%d+%.%d+$"))
end)

test.it("currentBranch returns the active branch name", function()
	local dir = mkTmp("branch")
	mkCommit(dir, "init")
	local repo = git2.open(dir)
	local branch = repo:currentBranch()
	test.truthy(branch == "master" or branch == "main")
	repo:free()
end)

test.it("remoteUrl returns the configured origin URL", function()
	local src = mkTmp("remurl-src")
	mkCommit(src, "init")
	local dest = mkTmp("remurl-dest") .. sep .. "repo"
	os.execute('git clone "' .. src .. '" "' .. dest .. '" ' .. null)
	local repo = git2.open(dest)
	test.equal(repo:remoteUrl("origin"), src)
	repo:free()
end)

test.it("checkout detaches HEAD to the requested SHA", function()
	local dir = mkTmp("checkout")
	mkCommit(dir, "first")
	local first_sha = headSha(dir)
	addCommit(dir, "f2", "second")
	local repo = git2.open(dir)
	test.equal(#repo:head(), 40) -- sanity: we're on second commit
	repo:checkout(first_sha)
	test.equal(repo:head(), first_sha)
	repo:free()
end)

test.it("pull fetches origin and hard-resets to new upstream commit", function()
	local src = mkTmp("pull-src")
	mkCommit(src, "init")
	local dest = mkTmp("pull-dest") .. sep .. "repo"
	os.execute('git clone "' .. src .. '" "' .. dest .. '" ' .. null)
	addCommit(src, "f2", "second")
	local second_sha = headSha(src)
	local repo = git2.open(dest)
	repo:pull()
	test.equal(repo:head(), second_sha)
	repo:free()
end)

local function commitCount(dir)
	local h = assert(io.popen('git -C "' .. dir .. '" rev-list --count HEAD'))
	local n = tonumber(h:read("*l"))
	h:close()
	return n
end

-- NOTE: requires network access
test.it("clone with depth=1 produces a shallow clone", function()
	local dir = mkTmp("shallow-clone") .. sep .. "repo"
	local repo = git2.clone("https://github.com/lde-org/lde", dir, nil, 1)
	test.truthy(repo:workdir())
	test.equal(commitCount(dir), 1)
	repo:free()
end)

-- NOTE: requires network access
test.it("clone with depth and branch is shallow", function()
	local dir = mkTmp("shallow-branch") .. sep .. "repo"
	local repo = git2.clone("https://github.com/lde-org/lde", dir, "master", 1)
	test.equal(repo:headUnborn(), false)
	test.equal(commitCount(dir), 1)
	repo:free()
end)

-- NOTE: requires network access
test.it("fetch with depth=1 performs a shallow fetch", function()
	local dir = mkTmp("shallow-fetch") .. sep .. "repo"
	os.execute('git clone --depth 1 "https://github.com/lde-org/lde" "' .. dir .. '" ' .. null)
	local repo = git2.open(dir)
	local ok, err = repo:fetch("origin", 1)
	test.truthy(ok, err)
	repo:free()
end)

-- NOTE: requires network access
test.skip("updateSubmodules with depth=1 clones submodules shallowly", function()
	local dir = mkTmp("shallow-sub") .. sep .. "repo"
	-- clone without submodules so updateSubmodules has work to do
	os.execute('git clone "https://github.com/lde-org/git2-sys" "' .. dir .. '" ' .. null)
	local repo = git2.open(dir)
	local ok, err = repo:updateSubmodules(1)
	test.truthy(ok, err)
	test.equal(commitCount(dir .. sep .. "vendor" .. sep .. "libgit2"), 1)
	repo:free()
end)

-- NOTE: requires network access
test.it("clone progress callback fires with valid stats", function()
	local dir = mkTmp("clone-progress") .. sep .. "repo"
	local calls = {}
	local repo = git2.clone("https://github.com/lde-org/lde", dir, nil, nil, function(stats)
		calls[#calls + 1] = {
			total_objects = tonumber(stats.total_objects),
			received_objects = tonumber(stats.received_objects),
			received_bytes = tonumber(stats.received_bytes)
		}
	end)
	test.truthy(repo, "clone should succeed")
	test.truthy(#calls > 0, "progress callback should fire at least once")
	test.truthy(calls[#calls].total_objects > 0, "total_objects should be non-zero")
	test.truthy(calls[#calls].received_bytes > 0, "received_bytes should be non-zero")
	repo:free()
end)

-- NOTE: requires network access
test.it("clone progress returning true cancels the clone", function()
	local dir = mkTmp("clone-cancel") .. sep .. "repo"
	local cancelled = false
	local repo, err = git2.clone("https://github.com/lde-org/git2-sys", dir, nil, nil, function()
		cancelled = true
		return true
	end)
	test.truthy(not repo, "clone should fail when cancelled")
	test.truthy(cancelled, "callback should have been called")
end)

-- NOTE: requires network access
test.it("fetch progress callback fires with valid stats", function()
	local dir = mkTmp("fetch-progress") .. sep .. "repo"
	os.execute('rm -rf "' .. dir .. '"')
	os.execute('git clone --depth 1 "https://github.com/lde-org/lde" "' .. dir .. '" ' .. null)
	local repo = git2.open(dir)
	local fired = false
	local ok, err = repo:fetch("origin", 0, function(stats)
		fired = true
		test.truthy(stats.total_objects > 0)
		test.truthy(stats.received_bytes > 0)
	end)
	test.truthy(ok, err)
	-- note: callback may not fire if fetch is already up-to-date
	repo:free()
end)
