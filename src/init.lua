local ffi = require("ffi")

ffi.cdef [[
  typedef struct git_repository git_repository;
  typedef struct git_commit     git_commit;
  typedef struct git_object     git_object;
  typedef struct git_reference  git_reference;
  typedef struct git_signature  git_signature;
  typedef struct git_index      git_index;
  typedef struct git_remote     git_remote;

  typedef struct { unsigned char id[20]; } git_oid;
  typedef struct { const char *message; int klass; } git_error;

  const git_error *git_error_last(void);
  int git_libgit2_init(void);

  int  git_repository_open(git_repository **out, const char *path);
  int  git_repository_init(git_repository **out, const char *path, unsigned is_bare);
  void git_repository_free(git_repository *repo);
  int  git_repository_is_bare(git_repository *repo);
  const char *git_repository_path(git_repository *repo);
  const char *git_repository_workdir(git_repository *repo);
  int  git_repository_head(git_reference **out, git_repository *repo);
  int  git_repository_head_unborn(git_repository *repo);
  int  git_repository_index(git_index **out, git_repository *repo);

  void           git_reference_free(git_reference *ref);
  const git_oid *git_reference_target(const git_reference *ref);

  void git_oid_tostr(char *out, size_t n, const git_oid *oid);
  int  git_oid_fromstr(git_oid *out, const char *str);

  int            git_commit_lookup(git_commit **out, git_repository *repo, const git_oid *id);
  void           git_commit_free(git_commit *commit);
  const char    *git_commit_message(const git_commit *commit);
  const char    *git_commit_summary(const git_commit *commit);
  const git_oid *git_commit_id(const git_commit *commit);
  const git_oid *git_commit_parent_id(const git_commit *commit, unsigned int n);
  unsigned int   git_commit_parentcount(const git_commit *commit);
  int64_t        git_commit_time(const git_commit *commit);
  const git_signature *git_commit_author(const git_commit *commit);
  const git_signature *git_commit_committer(const git_commit *commit);

  int  git_index_add_bypath(git_index *index, const char *path);
  int  git_index_remove_bypath(git_index *index, const char *path);
  int  git_index_write(git_index *index);
  int  git_index_write_tree(git_oid *out, git_index *index);
  void git_index_free(git_index *index);

  int  git_revparse_single(git_object **out, git_repository *repo, const char *spec);
  void git_object_free(git_object *obj);
  const git_oid *git_object_id(const git_object *obj);

  int  git_remote_lookup(git_remote **out, git_repository *repo, const char *name);
  int  git_remote_fetch(git_remote *remote, const void *refspecs, void *opts, const char *reflog_message);
  void git_remote_free(git_remote *remote);
]]

local here = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or ""
local sep = string.sub(package.config, 1, 1)
local lib = ffi.load(here .. (sep == "\\" and "git2.dll" or "libgit2.so"))

lib.git_libgit2_init()

-- ffi.cdata* phantom types for LuaCATS

---@class git2.ffi.Oid: ffi.cdata*
---@field id number[]

---@class git2.ffi.Repository: ffi.cdata*

---@class git2.ffi.Commit: ffi.cdata*

---@class git2.ffi.Object: ffi.cdata*

---@class git2.ffi.Reference: ffi.cdata*

---@class git2.ffi.Index: ffi.cdata*

---@class git2.ffi.Remote: ffi.cdata*

---@class git2.ffi.Signature: ffi.cdata*
---@field name string
---@field email string
---@field when_time integer

-- Lua-land value types

---@class git2.Sig
---@field name string
---@field email string
---@field time number Unix timestamp

---@class git2.Commit
---@field id string 40-char hex SHA
---@field message string Full commit message
---@field summary string First line of message
---@field author git2.Sig
---@field committer git2.Sig
---@field time number Unix timestamp
---@field parents string[]

---@class git2.Repo
---@field path fun(): string Absolute path to the .git directory
---@field workdir fun(): string|nil Working directory, nil for bare repos
---@field isBare fun(): boolean
---@field headUnborn fun(): boolean True when repo has no commits yet
---@field head fun(): string SHA of HEAD commit
---@field commitLookup fun(sha: string): git2.Commit
---@field revparse fun(spec: string): string Resolve any refspec to a SHA
---@field indexAdd fun(relpath: string)
---@field indexRemove fun(relpath: string)
---@field indexWrite fun()
---@field indexWriteTree fun(): string Tree SHA
---@field fetch fun(remote: string)

local sigLayout = ffi.typeof("struct { char *name; char *email; int64_t when_time; int when_offset; } *")

---@param code integer
local function check(code)
	if code ~= 0 then
		local e = lib.git_error_last()
		error((e ~= nil and e.message ~= nil) and ffi.string(e.message) or ("git2 error " .. code), 2)
	end
end

---@param oid git2.ffi.Oid
---@return string
local function oidStr(oid)
	local buf = ffi.new("char[41]")
	lib.git_oid_tostr(buf, 41, oid)
	return ffi.string(buf)
end

---@param sig git2.ffi.Signature
---@return git2.Sig
local function wrapSig(sig)
	local s = ffi.cast(sigLayout, sig)
	return { name = ffi.string(s.name), email = ffi.string(s.email), time = tonumber(s.when_time) }
end

---@param c git2.ffi.Commit
---@return git2.Commit
local function wrapCommit(c)
	local parents = {}
	for i = 0, tonumber(lib.git_commit_parentcount(c)) - 1 do
		parents[i + 1] = oidStr(lib.git_commit_parent_id(c, i))
	end
	return {
		id        = oidStr(lib.git_commit_id(c)),
		message   = ffi.string(lib.git_commit_message(c)),
		summary   = ffi.string(lib.git_commit_summary(c)),
		author    = wrapSig(lib.git_commit_author(c)),
		committer = wrapSig(lib.git_commit_committer(c)),
		time      = tonumber(lib.git_commit_time(c)),
		parents   = parents,
	}
end

---@param path string
---@param bare boolean?
---@return git2.Repo
local function openRepo(path, bare)
	local rp = ffi.new("git_repository*[1]")
	if bare ~= nil then
		check(lib.git_repository_init(rp, path, bare and 1 or 0))
	else
		check(lib.git_repository_open(rp, path))
	end
	---@type git2.ffi.Repository
	local repo = ffi.gc(rp[0], lib.git_repository_free)

	---@type git2.Repo
	local M = {}

	---@return string
	function M.path() return ffi.string(lib.git_repository_path(repo)) end

	---@return string|nil
	function M.workdir()
		local p = lib.git_repository_workdir(repo)
		return p ~= nil and ffi.string(p) or nil
	end

	---@return boolean
	function M.isBare() return lib.git_repository_is_bare(repo) == 1 end

	---@return boolean
	function M.headUnborn() return lib.git_repository_head_unborn(repo) == 1 end

	---@return string
	function M.head()
		local ref = ffi.new("git_reference*[1]")
		check(lib.git_repository_head(ref, repo))
		local sha = oidStr(lib.git_reference_target(ref[0]))
		lib.git_reference_free(ref[0])
		return sha
	end

	---@param sha string
	---@return git2.Commit
	function M.commitLookup(sha)
		local oid = ffi.new("git_oid")
		check(lib.git_oid_fromstr(oid, sha))
		local cp = ffi.new("git_commit*[1]")
		check(lib.git_commit_lookup(cp, repo, oid))
		local info = wrapCommit(cp[0])
		lib.git_commit_free(cp[0])
		return info
	end

	---@param spec string
	---@return string
	function M.revparse(spec)
		local op = ffi.new("git_object*[1]")
		check(lib.git_revparse_single(op, repo, spec))
		local sha = oidStr(lib.git_object_id(op[0]))
		lib.git_object_free(op[0])
		return sha
	end

	---@generic T
	---@param fn fun(idx: git2.ffi.Index): T
	---@return T
	local function withIndex(fn)
		local ip = ffi.new("git_index*[1]")
		check(lib.git_repository_index(ip, repo))
		local result = fn(ip[0])
		lib.git_index_free(ip[0])
		return result
	end

	---@param relpath string
	function M.indexAdd(relpath)    withIndex(function(i) check(lib.git_index_add_bypath(i, relpath)) end) end

	---@param relpath string
	function M.indexRemove(relpath) withIndex(function(i) check(lib.git_index_remove_bypath(i, relpath)) end) end

	function M.indexWrite()         withIndex(function(i) check(lib.git_index_write(i)) end) end

	---@return string
	function M.indexWriteTree()
		return withIndex(function(i)
			local oid = ffi.new("git_oid")
			check(lib.git_index_write_tree(oid, i))
			return oidStr(oid)
		end)
	end

	---@param remoteName string
	function M.fetch(remoteName)
		local rmt = ffi.new("git_remote*[1]")
		check(lib.git_remote_lookup(rmt, repo, remoteName))
		check(lib.git_remote_fetch(rmt[0], nil, nil, nil))
		lib.git_remote_free(rmt[0])
	end

	return M
end

---@class git2
local git2 = {}

---Open an existing repository.
---@param path string
---@return git2.Repo
function git2.open(path) return openRepo(path) end

---Initialise a new repository.
---@param path string
---@param bare boolean?
---@return git2.Repo
function git2.init(path, bare) return openRepo(path, bare or false) end

return git2
