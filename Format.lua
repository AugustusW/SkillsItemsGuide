-- tooltip 文字組裝（純函式）。名稱由呼叫端注入 names：
--   names.item(id) -> string|nil（nil＝尚未快取）、names.prof(id) -> string、names.recipe(rid) -> string|nil
local _, ns = ...
local L = ns.L

local Format = {}
ns.Format = Format

local function itemName(names, id) return names.item(id) or string.format(L.ITEM_PLACEHOLDER, id) end
local function recipeTitle(names, rid)
  local rec = ns.Data.recipes[rid]
  if rec.item then return itemName(names, rec.item) end
  return (names.recipe and names.recipe(rid)) or string.format(L.RECIPE_PLACEHOLDER, rid)
end
Format.recipeTitle = recipeTitle

function Format.duration(sec)
  if SecondsToTime then return SecondsToTime(sec) end
  local h = math.floor(sec / 3600)
  return h .. "h"
end

function Format.countsLine(itemId, names)
  local pc = ns.Index.profCounts(itemId)
  if #pc == 0 then return nil end
  local parts = {}
  for i, x in ipairs(pc) do parts[i] = L.paren(names.prof(x.prof), x.n) end
  return L.join(parts)
end

-- char：SkillsItemsGuideCharDB（professions／known 的鍵是字串化的 id）
function Format.shiftLines(itemId, char, names, max)
  max = max or 8
  local profs = char.professions or {}
  local known = char.known or {}
  local opened = char.opened or {}
  local out, more, missing, missingOrder = {}, 0, {}, {}
  for _, rid in ipairs(ns.Index.usedBy(itemId)) do
    local rec = ns.Data.recipes[rid]
    if profs[tostring(rec.p)] then
      if #out < max then
        local qty = 0
        for _, rg in ipairs(rec.r) do if rg[1] == itemId then qty = rg[2] end end
        local text = L.label(names.prof(rec.p), recipeTitle(names, rid) .. " " .. L.paren(itemName(names, itemId), qty))
        -- 沒開過該專業視窗：不知道學了沒（nil），並記下要提示
        local learned
        if opened[tostring(rec.p)] then
          learned = (rec.spell and known[tostring(rec.spell)]) and true or false
        elseif not missing[rec.p] then
          missing[rec.p] = true
          missingOrder[#missingOrder + 1] = names.prof(rec.p)
        end
        out[#out + 1] = { text = text, learned = learned, recipe = rid }
      else
        more = more + 1
      end
    end
  end
  local notOpened = #missingOrder > 0 and string.format(L.NOT_OPENED_FMT, L.join(missingOrder)) or nil
  return { lines = out, more = more, empty = (#out == 0) and L.SHIFT_EMPTY or nil, notOpened = notOpened }
end

local function skillText(rid)
  local s = rid and ns.Index.skillOf(rid)
  return L.SKILL .. " " .. (s and tostring(s) or "?")
end

-- 清單的第一層材料：「細線（1）、紅色染料（1）」（使用者：數量用括號，不用 ×）
function Format.firstLayer(rid, names)
  local parts = {}
  for i, rg in ipairs(ns.Data.recipes[rid].r or {}) do parts[i] = L.paren(itemName(names, rg[1]), rg[2]) end
  return L.join(parts)
end

-- 樹狀 tooltip：標題、專業（技能）、原料、冷卻、樹（最多 maxRows 列）、多做法
function Format.treeTooltip(res, names, maxRows)
  maxRows = maxRows or 12
  local lines = {}
  local root = res.root
  local title = L.paren(root.item and itemName(names, root.item) or recipeTitle(names, root.recipe), root.n)
  lines[#lines + 1] = { text = title, title = true, item = root.item }
  if root.prof then lines[#lines + 1] = { text = L.paren(names.prof(root.prof), skillText(root.recipe)) } end
  if #res.totals > 0 then
    local parts = {}
    for i, t in ipairs(res.totals) do parts[i] = L.paren(itemName(names, t.item), t.n) end
    lines[#lines + 1] = { text = L.label(L.MATERIALS, L.join(parts)), materials = true }
  end
  for _, c in ipairs(res.cooldowns) do
    local what = recipeTitle(names, c.recipe)
    lines[#lines + 1] = { text = L.label(L.COOLDOWN, string.format(L.COOLDOWN_FMT, what, c.times, Format.duration(c.sec))), cooldown = true }
  end
  local rows, hidden = 0, 0
  local function walk(node, prefix)
    for i, child in ipairs(node.children) do
      local last = i == #node.children
      if rows < maxRows then
        rows = rows + 1
        local text = prefix .. (last and "└ " or "├ ") .. L.paren(itemName(names, child.item), child.n)
        if child.recipe then text = text .. "  " .. L.paren(names.prof(child.prof), skillText(child.recipe)) end
        lines[#lines + 1] = { text = text, tree = true, item = child.item }
      else
        hidden = hidden + 1
      end
      walk(child, prefix .. (last and "    " or "│  "))
    end
  end
  walk(root, "")
  if hidden > 0 then lines[#lines + 1] = { text = string.format(L.MORE, hidden), more = true } end
  if (res.alternatives or 0) > 0 then lines[#lines + 1] = { text = string.format(L.ALTERNATIVES, res.alternatives), hint = true } end
  return { lines = lines }
end
