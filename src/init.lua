local ffi = require("ffi")

ffi.cdef [[
  typedef struct git_repository git_repository;
  typedef struct git_commit     git_commit;
  typedef struct git_object     git_object;
  typedef struct git_reference  git_reference;

  typedef struct {
    char *name;
    char *email;
    struct {
      int64_t time;
      int offset;
      char sign;
    } when;
  } git_signature;

  typedef struct git_index      git_index;
  typedef struct git_remote     git_remote;
  typedef struct git_submodule  git_submodule;

  typedef struct { unsigned char id[20]; } git_oid;
  typedef struct { const char *message; int klass; } git_error;

  /* opaque options structs — sized to match the ABI, initialized via _init */
  typedef struct { char _[376]; const char *checkout_branch; char _rest[32]; } git_clone_options;
  typedef struct { char _[376]; } git_submodule_update_options;

  const git_error *git_error_last(void);
  int  git_libgit2_init(void);
  int  git_libgit2_shutdown(void);

  int  git_clone_options_init(git_clone_options *opts, unsigned int version);
  int  git_clone(git_repository **out, const char *url, const char *local_path, const git_clone_options *options);

  int  git_submodule_update_options_init(git_submodule_update_options *opts, unsigned int version);
  int  git_submodule_foreach(git_repository *repo, int (*cb)(git_submodule *sm, const char *name, void *payload), void *payload);
  int  git_submodule_update(git_submodule *submodule, int init, git_submodule_update_options *options);
  void git_submodule_free(git_submodule *submodule);

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
local libName = jit.os == "Windows" and "git2.dll" or (jit.os == "OSX" and "libgit2.dylib" or "libgit2.so")

-- On Android/Bionic, OpenSSL's atexit cleanup crashes if libgit2.so has been
-- dlclose'd (it holds callbacks into it). Pre-open with RTLD_NODELETE so the
-- library stays mapped through process teardown even after ffi's dlclose.
if os.getenv("ANDROID_ROOT") then
	ffi.cdef [[ void *dlopen(const char *filename, int flags); ]]
	ffi.C.dlopen(here .. libName, 0x2 + 0x1000) -- RTLD_NOW | RTLD_NODELETE
end

local lib = ffi.load(here .. libName)

lib.git_libgit2_init()

-- ffi phantom types

---@class git2.ffi.Oid: ffi.cdata*
---@class git2.ffi.Repository: ffi.cdata*
---@class git2.ffi.Commit: ffi.cdata*
---@class git2.ffi.Object: ffi.cdata*
---@class git2.ffi.Reference: ffi.cdata*
---@class git2.ffi.Index: ffi.cdata*
---@class git2.ffi.Remote: ffi.cdata*
---@class git2.ffi.Signature: ffi.cdata*
---@field name string
---@field email string
---@field when { time: integer, offset: integer, sign: string }

-- value types

---@class git2.Sig
---@field name string
---@field email string
---@field time number

---@class git2.Commit
---@field id string
---@field message string
---@field summary string
---@field author git2.Sig
---@field committer git2.Sig
---@field time number
---@field parents string[]

-- helpers


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
	return { name = ffi.string(sig.name), email = ffi.string(sig.email), time = tonumber(sig.when.time) }
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

-- Repo class

---@class git2.Repo
---@field _repo git2.ffi.Repository
local Repo = {}
Repo.__index = Repo

---@param repo git2.ffi.Repository
---@return git2.Repo
function Repo.new(repo)
	return setmetatable({ _repo = repo }, Repo)
end

---@return string
function Repo:path()
	return ffi.string(lib.git_repository_path(self._repo))
end

---@return string|nil
function Repo:workdir()
	local p = lib.git_repository_workdir(self._repo)
	return p ~= nil and ffi.string(p) or nil
end

---@return boolean
function Repo:isBare()
	return lib.git_repository_is_bare(self._repo) == 1
end

---@return boolean
function Repo:headUnborn()
	return lib.git_repository_head_unborn(self._repo) == 1
end

---@return string
function Repo:head()
	local ref = ffi.new("git_reference*[1]")
	check(lib.git_repository_head(ref, self._repo))
	local sha = oidStr(lib.git_reference_target(ref[0]))
	lib.git_reference_free(ref[0])
	return sha
end

---@param sha string
---@return git2.Commit
function Repo:commitLookup(sha)
	local oid = ffi.new("git_oid")
	check(lib.git_oid_fromstr(oid, sha))
	local cp = ffi.new("git_commit*[1]")
	check(lib.git_commit_lookup(cp, self._repo, oid))
	local info = wrapCommit(cp[0])
	lib.git_commit_free(cp[0])
	return info
end

---@param spec string
---@return string
function Repo:revparse(spec)
	local op = ffi.new("git_object*[1]")
	check(lib.git_revparse_single(op, self._repo, spec))
	local sha = oidStr(lib.git_object_id(op[0]))
	lib.git_object_free(op[0])
	return sha
end

---@param relpath string
function Repo:indexAdd(relpath)
	local ip = ffi.new("git_index*[1]")
	check(lib.git_repository_index(ip, self._repo))
	check(lib.git_index_add_bypath(ip[0], relpath))
	lib.git_index_free(ip[0])
end

---@param relpath string
function Repo:indexRemove(relpath)
	local ip = ffi.new("git_index*[1]")
	check(lib.git_repository_index(ip, self._repo))
	check(lib.git_index_remove_bypath(ip[0], relpath))
	lib.git_index_free(ip[0])
end

function Repo:indexWrite()
	local ip = ffi.new("git_index*[1]")
	check(lib.git_repository_index(ip, self._repo))
	check(lib.git_index_write(ip[0]))
	lib.git_index_free(ip[0])
end

---@return string
function Repo:indexWriteTree()
	local ip = ffi.new("git_index*[1]")
	check(lib.git_repository_index(ip, self._repo))
	local oid = ffi.new("git_oid")
	check(lib.git_index_write_tree(oid, ip[0]))
	lib.git_index_free(ip[0])
	return oidStr(oid)
end

---@param remoteName string
function Repo:fetch(remoteName)
	local rmt = ffi.new("git_remote*[1]")
	check(lib.git_remote_lookup(rmt, self._repo, remoteName))
	check(lib.git_remote_fetch(rmt[0], nil, nil, nil))
	lib.git_remote_free(rmt[0])
end

function Repo:updateSubmodules()
	local repo = self._repo
	local opts = ffi.new("git_submodule_update_options")
	lib.git_submodule_update_options_init(opts, 1)
	local cb = ffi.cast("int (*)(git_submodule*, const char*, void*)", function(sm, _, _)
		lib.git_submodule_update(sm, 1, opts)
		return 0
	end)
	local ret = lib.git_submodule_foreach(repo, cb, nil)
	cb:free()
	check(ret)
end

function Repo:free()
	lib.git_repository_free(self._repo)
end

-- module

---@class git2
local git2 = {}

---@param path string
---@return git2.Repo
function git2.open(path)
	local rp = ffi.new("git_repository*[1]")
	check(lib.git_repository_open(rp, path))
	return Repo.new(rp[0])
end

---@param path string
---@param bare boolean?
---@return git2.Repo
function git2.init(path, bare)
	local rp = ffi.new("git_repository*[1]")
	check(lib.git_repository_init(rp, path, bare and 1 or 0))
	return Repo.new(rp[0])
end

---@param url string
---@param path string
---@param branch string?
---@return git2.Repo
function git2.clone(url, path, branch)
	local rp = ffi.new("git_repository*[1]")
	local opts = nil
	if branch then
		local o = ffi.new("git_clone_options")
		lib.git_clone_options_init(o, 1)
		o.checkout_branch = branch
		opts = o
	end
	check(lib.git_clone(rp, url, path, opts))
	return Repo.new(rp[0])
end

-- Call git_libgit2_shutdown when the module is GC'd to avoid a segfault on DLL unload.
-- The closure keeps `lib` alive until after shutdown runs.
git2._gc = ffi.gc(ffi.new("char[1]"), function() lib.git_libgit2_shutdown() end)

return git2
