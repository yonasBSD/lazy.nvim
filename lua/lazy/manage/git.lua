local Util = require("lazy.util")
local Semver = require("lazy.manage.semver")

local M = {}

---@param details? boolean
function M.info(repo, details)
  local line = Util.head(repo .. "/.git/HEAD")
  if line then
    ---@type string, string
    local ref, branch = line:match("ref: (refs/heads/(.*))")
    local ret = ref and {
      branch = branch,
      commit = Util.head(repo .. "/.git/" .. ref),
    } or { commit = line }

    if details then
      Util.ls(repo .. "/.git/refs/tags", function(_, name)
        if M.ref(repo, "tags/" .. name) == ret.commit then
          ret.tag = name
          ret.version = Semver.version(name)
          return false
        end
      end)
    end

    return ret
  end
end

---@class TaggedSemver: Semver
---@field tag string

---@param spec? string
function M.get_versions(repo, spec)
  local range = Semver.range(spec or "*")
  ---@type TaggedSemver[]
  local versions = {}
  Util.ls(repo .. "/.git/refs/tags", function(_, name)
    local v = Semver.version(name)
    ---@cast v TaggedSemver
    if v and range:matches(v) then
      v.tag = name
      table.insert(versions, v)
    end
  end)
  return versions
end

---@param plugin LazyPlugin
function M.get_branch(plugin)
  if plugin.branch then
    return {
      branch = plugin.branch,
      commit = M.ref(plugin.dir, "heads/" .. plugin.branch),
    }
  else
    local main = M.ref(plugin.dir, "remotes/origin/HEAD")
    if main then
      local branch = main:match("ref: refs/remotes/origin/(.*)")
      if branch then
        return {
          branch = branch,
          commit = M.ref(plugin.dir, "heads/" .. branch),
        }
      end
    end
  end
end

---@param plugin LazyPlugin
function M.get_target(plugin)
  local branch = M.get_branch(plugin)

  if plugin.commit then
    return { branch = branch, commit = plugin.commit }
  end
  if plugin.tag then
    return { branch = branch, tag = plugin.tag, commit = M.ref(plugin.dir, "tags/" .. plugin.tag) }
  end
  if plugin.version then
    local last = Semver.last(M.get_versions(plugin.dir, plugin.version))
    if last then
      return { branch = branch, version = last, tag = last.tag, commit = M.ref(plugin.dir, "tags/" .. last.tag) }
    end
  end
  return { branch = branch, commit = branch.commit }
end

function M.ref(repo, ref)
  return Util.head(repo .. "/.git/refs/" .. ref)
end

return M
