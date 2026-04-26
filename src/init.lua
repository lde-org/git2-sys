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

  typedef struct { unsigned int version; unsigned int checkout_strategy; char _rest[136]; } git_checkout_options;

  /* git_fetch_options — layout verified against libgit2 headers on 64-bit.
     Opaque padding hides git_remote_callbacks (128 B) and git_proxy_options
     (40 B); only `depth` is exposed (GIT_FETCH_DEPTH_FULL=0, shallow=1+). */
  typedef struct {
    int version;
    char _pad0[4];
    char _callbacks[128];
    int prune;
    unsigned int update_fetchhead;
    int download_tags;
    char _pad1[4];
    char _proxy[40];
    int depth;
    char _rest[20];
  } git_fetch_options;

  /* git_clone_options — fetch_opts embedded at offset 152, checkout_branch
     at offset 376 (matches the former opaque char _[376] + pointer layout). */
  typedef struct {
    unsigned int version;
    char _pad0[4];
    char _checkout_opts[144];
    git_fetch_options fetch_opts;
    int bare;
    int local;
    const char *checkout_branch;
    char _rest[32];
  } git_clone_options;

  /* git_submodule_update_options — fetch_opts embedded at offset 152;
     explicit trailing _pad1 keeps sizeof at 376 to match the C ABI. */
  typedef struct {
    unsigned int version;
    char _pad0[4];
    char _checkout_opts[144];
    git_fetch_options fetch_opts;
    int allow_fetch;
    char _pad1[4];
  } git_submodule_update_options;

  const git_error *git_error_last(void);
  int  git_libgit2_init(void);
  int  git_libgit2_shutdown(void);

  int  git_fetch_options_init(git_fetch_options *opts, unsigned int version);
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
  int  git_remote_fetch(git_remote *remote, const void *refspecs, const git_fetch_options *opts, const char *reflog_message);
  void git_remote_free(git_remote *remote);
  const char *git_remote_url(const git_remote *remote);

  const char *git_reference_shorthand(const git_reference *ref);

  int  git_checkout_options_init(git_checkout_options *opts, unsigned int version);
  int  git_checkout_head(git_repository *repo, const git_checkout_options *opts);
  int  git_repository_set_head_detached(git_repository *repo, const git_oid *commitish);

  int  git_reset(git_repository *repo, const git_object *target, int reset_type, const git_checkout_options *checkout_opts);

  void git_libgit2_version(int *major, int *minor, int *rev);
]]

local here = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or ""
local libName = jit.os == "Windows" and "git2.dll" or (jit.os == "OSX" and "libgit2.dylib" or "libgit2.so")

local lib = ffi.load(here .. libName)
lib.git_libgit2_init()

-- phantom types

---@class git2.ffi.Oid: ffi.cdata*
---@class git2.ffi.Repository: ffi.cdata*
---@class git2.ffi.Commit: ffi.cdata*
---@class git2.ffi.Object: ffi.cdata*
---@class git2.ffi.Reference: ffi.cdata*
---@class git2.ffi.Index: ffi.cdata*
---@class git2.ffi.Remote: ffi.cdata*
---@class git2.ffi.Signature: ffi.cdata*

-- ffi type constructors

---@type fun(): git2.ffi.Oid
local Oid = ffi.typeof("git_oid")
---@type fun(): ffi.cdata*
local OidBuf = ffi.typeof("char[41]")
---@type fun(): ffi.cdata*
local IntPtr = ffi.typeof("int[1]")
---@type fun(): ffi.cdata*
local RepositoryPtr = ffi.typeof("git_repository*[1]")
---@type fun(): ffi.cdata*
local CommitPtr = ffi.typeof("git_commit*[1]")
---@type fun(): ffi.cdata*
local ObjectPtr = ffi.typeof("git_object*[1]")
---@type fun(): ffi.cdata*
local ReferencePtr = ffi.typeof("git_reference*[1]")
---@type fun(): ffi.cdata*
local IndexPtr = ffi.typeof("git_index*[1]")
---@type fun(): ffi.cdata*
local RemotePtr = ffi.typeof("git_remote*[1]")
---@type fun(): ffi.cdata*
local CheckoutOptions = ffi.typeof("git_checkout_options")
---@type fun(): ffi.cdata*
local FetchOptions = ffi.typeof("git_fetch_options")
---@type fun(): ffi.cdata*
local CloneOptions = ffi.typeof("git_clone_options")
---@type fun(): ffi.cdata*
local SubmoduleUpdateOptions = ffi.typeof("git_submodule_update_options")

-- value types

---@class git2.Sig
---@field name string
---@field email string
---@field time integer

-- helpers

local function git_err()
	local e = lib.git_error_last()
	return (e ~= nil and e.message ~= nil) and ffi.string(e.message) or "unknown git2 error"
end

---@param oid git2.ffi.Oid
local function oidStr(oid)
	local buf = OidBuf()
	lib.git_oid_tostr(buf, 41, oid)
	return ffi.string(buf)
end

---@param sig git2.ffi.Signature
local function wrapSig(sig)
	return { name = ffi.string(sig.name), email = ffi.string(sig.email), time = tonumber(sig.when.time) }
end

-- Commit class — fields resolved lazily and cached on first access

---@class git2.Commit
---@field id string
---@field message string
---@field summary string
---@field author git2.Sig
---@field committer git2.Sig
---@field time integer
---@field parents string[]
local Commit = {}

local CommitMeta = {}
CommitMeta.__index = function(self, key)
	local c = rawget(self, "_c")
	local val

	---@format disable-next
	if     key == "id"        then val = oidStr(lib.git_commit_id(c))
	elseif key == "message"   then val = ffi.string(lib.git_commit_message(c))
	elseif key == "summary"   then val = ffi.string(lib.git_commit_summary(c))
	elseif key == "author"    then val = wrapSig(lib.git_commit_author(c))
	elseif key == "committer" then val = wrapSig(lib.git_commit_committer(c))
	elseif key == "time"      then val = tonumber(lib.git_commit_time(c))
	elseif key == "parents"   then
		local parents = {}
		for i = 0, tonumber(lib.git_commit_parentcount(c)) - 1 do
			parents[i + 1] = oidStr(lib.git_commit_parent_id(c, i))
		end
		val = parents
	end

	if val ~= nil then rawset(self, key, val) end
	return val
end

---@param c git2.ffi.Commit
function Commit.new(c)
	return setmetatable({ _c = ffi.gc(c, lib.git_commit_free) }, CommitMeta)
end

-- Repo class

local state = {
	alive = true,
	repos = setmetatable({}, { __mode = "k" })
}

local function freeRepo(self)
	local repo = self._repo
	if repo == nil then return end
	self._repo = nil
	state.repos[self] = nil
	lib.git_repository_free(ffi.gc(repo, nil))
end

---@class git2.Repo
---@field _repo git2.ffi.Repository
local Repo = {}
Repo.__index = Repo

---@param repo git2.ffi.Repository
function Repo.new(repo)
	local self = setmetatable({
		_repo = ffi.gc(repo, function(p)
			if state.alive then
				lib.git_repository_free(p)
			end
		end),
		_state = state
	}, Repo)
	state.repos[self] = true
	return self
end

function Repo:path()
	return ffi.string(lib.git_repository_path(self._repo))
end

function Repo:workdir()
	local p = lib.git_repository_workdir(self._repo)
	return p ~= nil and ffi.string(p) or nil
end

function Repo:isBare()
	return lib.git_repository_is_bare(self._repo) == 1
end

function Repo:headUnborn()
	return lib.git_repository_head_unborn(self._repo) == 1
end

---@return string?, string?
function Repo:head()
	local ref = ReferencePtr()
	local code = lib.git_repository_head(ref, self._repo)
	if code ~= 0 then return nil, git_err() end

	local sha = oidStr(lib.git_reference_target(ref[0]))
	lib.git_reference_free(ref[0])
	return sha
end

---@param sha string
---@return git2.Commit?, string?
function Repo:commitLookup(sha)
	local oid = Oid()
	local code = lib.git_oid_fromstr(oid, sha)
	if code ~= 0 then return nil, git_err() end

	local cp = CommitPtr()
	code = lib.git_commit_lookup(cp, self._repo, oid)
	if code ~= 0 then return nil, git_err() end

	return Commit.new(cp[0])
end

---@param spec string
---@return string?, string?
function Repo:revparse(spec)
	local op = ObjectPtr()
	local code = lib.git_revparse_single(op, self._repo, spec)
	if code ~= 0 then return nil, git_err() end

	local sha = oidStr(lib.git_object_id(op[0]))
	lib.git_object_free(op[0])
	return sha
end

---@param relpath string
---@return true?, string?
function Repo:indexAdd(relpath)
	local ip = IndexPtr()
	local code = lib.git_repository_index(ip, self._repo)
	if code ~= 0 then return nil, git_err() end

	code = lib.git_index_add_bypath(ip[0], relpath)
	lib.git_index_free(ip[0])
	if code ~= 0 then return nil, git_err() end

	return true
end

---@param relpath string
---@return true?, string?
function Repo:indexRemove(relpath)
	local ip = IndexPtr()
	local code = lib.git_repository_index(ip, self._repo)
	if code ~= 0 then return nil, git_err() end

	code = lib.git_index_remove_bypath(ip[0], relpath)
	lib.git_index_free(ip[0])
	if code ~= 0 then return nil, git_err() end

	return true
end

---@return true?, string?
function Repo:indexWrite()
	local ip = IndexPtr()
	local code = lib.git_repository_index(ip, self._repo)
	if code ~= 0 then return nil, git_err() end

	code = lib.git_index_write(ip[0])
	lib.git_index_free(ip[0])
	if code ~= 0 then return nil, git_err() end

	return true
end

---@return string?, string?
function Repo:indexWriteTree()
	local ip = IndexPtr()
	local code = lib.git_repository_index(ip, self._repo)
	if code ~= 0 then return nil, git_err() end

	local oid = Oid()
	code = lib.git_index_write_tree(oid, ip[0])
	lib.git_index_free(ip[0])
	if code ~= 0 then return nil, git_err() end

	return oidStr(oid)
end

---@param remoteName string
---@param depth integer? 1 for shallow, nil for full history
---@return true?, string?
function Repo:fetch(remoteName, depth)
	local rmt = RemotePtr()
	local code = lib.git_remote_lookup(rmt, self._repo, remoteName)
	if code ~= 0 then return nil, git_err() end

	local fopts = nil
	if depth then
		fopts = FetchOptions()
		lib.git_fetch_options_init(fopts, 1)
		fopts.depth = depth
	end

	code = lib.git_remote_fetch(rmt[0], nil, fopts, nil)
	lib.git_remote_free(rmt[0])
	if code ~= 0 then return nil, git_err() end

	return true
end

---@param depth integer? 1 for shallow submodule fetch, nil for full history
---@return true?, string?
function Repo:updateSubmodules(depth)
	local opts = SubmoduleUpdateOptions()
	lib.git_submodule_update_options_init(opts, 1)
	if depth then opts.fetch_opts.depth = depth end

	local sub_err
	local cb = ffi.cast("int (*)(git_submodule*, const char*, void*)", function(sm)
		local code = lib.git_submodule_update(sm, 1, opts)
		if code ~= 0 and not sub_err then sub_err = git_err() end
		return 0
	end)

	local code = lib.git_submodule_foreach(self._repo, cb, nil)
	cb:free()

	if code ~= 0 then return nil, git_err() end
	if sub_err then return nil, sub_err end
	return true
end

---@param name string
---@return string?, string?
function Repo:remoteUrl(name)
	local rmt = RemotePtr()
	local code = lib.git_remote_lookup(rmt, self._repo, name)
	if code ~= 0 then return nil, git_err() end

	local url = ffi.string(lib.git_remote_url(rmt[0]))
	lib.git_remote_free(rmt[0])
	return url
end

---@return string?, string?
function Repo:currentBranch()
	local ref = ReferencePtr()
	local code = lib.git_repository_head(ref, self._repo)
	if code ~= 0 then return nil, git_err() end

	local name = ffi.string(lib.git_reference_shorthand(ref[0]))
	lib.git_reference_free(ref[0])
	return name
end

---@param ref string
---@return true?, string?
function Repo:checkout(ref)
	local op = ObjectPtr()
	local code = lib.git_revparse_single(op, self._repo, ref)
	if code ~= 0 then return nil, git_err() end

	local oid = Oid()
	ffi.copy(oid, lib.git_object_id(op[0]), ffi.sizeof("git_oid"))
	lib.git_object_free(op[0])

	code = lib.git_repository_set_head_detached(self._repo, oid)
	if code ~= 0 then return nil, git_err() end

	local opts = CheckoutOptions()
	code = lib.git_checkout_options_init(opts, 1)
	if code ~= 0 then return nil, git_err() end
	opts.checkout_strategy = 1 -- GIT_CHECKOUT_SAFE

	code = lib.git_checkout_head(self._repo, opts)
	if code ~= 0 then return nil, git_err() end

	return true
end

---@return true?, string?
function Repo:pull()
	local ok, err = self:fetch("origin")
	if not ok then return nil, err end

	local op = ObjectPtr()
	local code = lib.git_revparse_single(op, self._repo, "FETCH_HEAD")
	if code ~= 0 then return nil, git_err() end

	code = lib.git_reset(self._repo, op[0], 3, nil) -- GIT_RESET_HARD
	lib.git_object_free(op[0])
	if code ~= 0 then return nil, git_err() end

	return true
end

function Repo:free()
	freeRepo(self)
end

-- module

---@class git2
local git2 = {}

---@param path string
---@return git2.Repo?, string?
function git2.open(path)
	local rp = RepositoryPtr()
	local code = lib.git_repository_open(rp, path)
	if code ~= 0 then return nil, git_err() end
	return Repo.new(rp[0])
end

---@param path string
---@param bare boolean?
---@return git2.Repo?, string?
function git2.init(path, bare)
	local rp = RepositoryPtr()
	local code = lib.git_repository_init(rp, path, bare and 1 or 0)
	if code ~= 0 then return nil, git_err() end
	return Repo.new(rp[0])
end

---@param url string
---@param path string
---@param branch string?
---@param depth integer? 1 for shallow clone, nil for full history
---@return git2.Repo?, string?
function git2.clone(url, path, branch, depth)
	local rp = RepositoryPtr()
	local opts = nil

	if branch or depth then
		local o = CloneOptions()
		lib.git_clone_options_init(o, 1)
		if branch then o.checkout_branch = branch end
		if depth then o.fetch_opts.depth = depth end
		opts = o
	end

	local code = lib.git_clone(rp, url, path, opts)
	if code ~= 0 then return nil, git_err() end
	return Repo.new(rp[0])
end

---@return string
function git2.version()
	local major = IntPtr()
	local minor = IntPtr()
	local rev   = IntPtr()
	lib.git_libgit2_version(major, minor, rev)
	return major[0] .. "." .. minor[0] .. "." .. rev[0]
end

git2._gc = ffi.gc(ffi.new("char[1]"), function()
	for repo in pairs(state.repos) do
		freeRepo(repo)
	end

	state.alive = false
	lib.git_libgit2_shutdown()
end)

return git2
