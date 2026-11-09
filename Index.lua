-- 反查索引：物品被哪些配方用（usedBy）、由哪些配方做（madeBy）、各專業用到幾條（profCounts）
local _, ns = ...

local Index = {}
ns.Index = Index

local usedBy, madeBy, counts, cyclic
local canon = {} -- 正式版：同一材料槽的各品質物品 → canonical（最低品質那個）

function Index.canonical(itemId) return canon[itemId] or itemId end

-- 配方學了沒：正式版分級配方（spells 有 1–3 級）學了任一級就算；known 的鍵可以是數字或字串
function Index.learned(rec, known)
  if not (rec and known) then return false end
  for _, sp in ipairs(rec.spells or { rec.spell }) do
    if known[sp] or known[tostring(sp)] then return true end
  end
  return false
end

-- 配方屬於舊資料片嗎（永恆資料沒有 tiers，一律當前）
local function isOld(rec)
  local t = rec.t and ns.Data.tiers and ns.Data.tiers[rec.t]
  return t ~= nil and t.cur == false
end

function Index.build()
  usedBy, madeBy, counts, canon = {}, {}, {}, {}
  for c, group in pairs(ns.Data.slotGroups or {}) do
    for _, id in ipairs(group) do canon[id] = c end
  end
  local C = Index.canonical
  for rid, rec in pairs(ns.Data.recipes or {}) do
    if rec.item then
      local it = C(rec.item)
      madeBy[it] = madeBy[it] or {}
      table.insert(madeBy[it], rid)
    end
    local seen = {}
    for _, rg in ipairs(rec.r or {}) do
      local item = C(rg[1])
      if not seen[item] then
        seen[item] = true
        usedBy[item] = usedBy[item] or {}
        table.insert(usedBy[item], rid)
        counts[item] = counts[item] or {}
        local c = counts[item][rec.p] or { n = 0, old = 0 }
        if isOld(rec) then c.old = c.old + 1 else c.n = c.n + 1 end
        counts[item][rec.p] = c
      end
    end
  end
  for _, list in pairs(usedBy) do ns.Breakdown.sortRecipes(list) end
  for _, list in pairs(madeBy) do ns.Breakdown.sortRecipes(list) end
  cyclic = Index.findCycles()
end

-- 物品圖（產物 → 材料）的強連通元件（Tarjan，非遞迴）。
-- 落在非平凡環上的物品（例如元素精華互相轉化）拆解時一律當原料，否則會出現「準備 6 個同一種精華」與假冷卻。
function Index.findCycles()
  local edges = {}
  for item, rids in pairs(madeBy) do
    local e = {}
    for _, rid in ipairs(rids) do
      for _, rg in ipairs(ns.Data.recipes[rid].r or {}) do e[#e + 1] = rg[1] end
    end
    edges[item] = e
  end
  local index, low, onStack, stack, out, counter = {}, {}, {}, {}, {}, 0
  for start in pairs(edges) do
    if not index[start] then
      local work = { { start, 1 } }
      counter = counter + 1
      index[start], low[start] = counter, counter
      stack[#stack + 1] = start; onStack[start] = true
      while #work > 0 do
        local top = work[#work]
        local v, i = top[1], top[2]
        local e = edges[v] or {}
        if i <= #e then
          top[2] = i + 1
          local w = e[i]
          if not index[w] then
            counter = counter + 1
            index[w], low[w] = counter, counter
            stack[#stack + 1] = w; onStack[w] = true
            work[#work + 1] = { w, 1 }
          elseif onStack[w] and index[w] < low[v] then
            low[v] = index[w]
          end
        else
          work[#work] = nil
          if #work > 0 then
            local parent = work[#work][1]
            if low[v] < low[parent] then low[parent] = low[v] end
          end
          if low[v] == index[v] then
            local comp = {}
            repeat
              local w = stack[#stack]; stack[#stack] = nil; onStack[w] = nil
              comp[#comp + 1] = w
            until w == v
            local selfLoop = false
            for _, w in ipairs(edges[v] or {}) do if w == v then selfLoop = true end end
            if #comp > 1 or selfLoop then for _, w in ipairs(comp) do out[w] = true end end
          end
        end
      end
    end
  end
  return out
end

function Index.cyclic(itemId) return cyclic ~= nil and cyclic[Index.canonical(itemId)] == true end

local EMPTY = {}
function Index.usedBy(itemId) return usedBy[Index.canonical(itemId)] or EMPTY end
function Index.madeBy(itemId) return madeBy[Index.canonical(itemId)] or EMPTY end

-- { {prof, n=當前資料片, old=舊資料片} }，依總數排序
function Index.profCounts(itemId)
  local out = {}
  for prof, c in pairs(counts[Index.canonical(itemId)] or EMPTY) do
    out[#out + 1] = { prof = prof, n = c.n, old = c.old }
  end
  table.sort(out, function(a, b)
    local ta, tb = a.n + a.old, b.n + b.old
    if ta ~= tb then return ta > tb end
    return a.prof < b.prof
  end)
  return out
end

-- 技能點數：訓練師快取（依法術 id）優先，其次圖紙資料
function Index.skillOf(recipeId)
  local rec = ns.Data.recipes[recipeId]
  if not rec then return nil end
  if rec.spell then
    local db = SkillsItemsGuideDB
    local live = db and db.trainer and db.trainer.prof and db.trainer.prof[tostring(rec.p)]
    local v = live and live.spells and live.spells[tostring(rec.spell)]
    if v and v.skill and v.skill > 0 then return v.skill end -- 已學的服務回 0，視為未知
  end
  local cache = ns.Data.cache and ns.Data.cache.recipeSkill
  if cache and rec.spell and cache[rec.spell] and cache[rec.spell] > 0 then return cache[rec.spell] end
  return rec.s
end
