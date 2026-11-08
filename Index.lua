-- 反查索引：物品被哪些配方用（usedBy）、由哪些配方做（madeBy）、各專業用到幾條（profCounts）
local _, ns = ...

local Index = {}
ns.Index = Index

local usedBy, madeBy, counts, cyclic

function Index.build()
  usedBy, madeBy, counts = {}, {}, {}
  for rid, rec in pairs(ns.Data.recipes or {}) do
    if rec.item then
      madeBy[rec.item] = madeBy[rec.item] or {}
      table.insert(madeBy[rec.item], rid)
    end
    local seen = {}
    for _, rg in ipairs(rec.r or {}) do
      local item = rg[1]
      if not seen[item] then
        seen[item] = true
        usedBy[item] = usedBy[item] or {}
        table.insert(usedBy[item], rid)
        counts[item] = counts[item] or {}
        counts[item][rec.p] = (counts[item][rec.p] or 0) + 1
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

function Index.cyclic(itemId) return cyclic ~= nil and cyclic[itemId] == true end

local EMPTY = {}
function Index.usedBy(itemId) return usedBy[itemId] or EMPTY end
function Index.madeBy(itemId) return madeBy[itemId] or EMPTY end

function Index.profCounts(itemId)
  local out = {}
  for prof, n in pairs(counts[itemId] or EMPTY) do out[#out + 1] = { prof = prof, n = n } end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.prof < b.prof end)
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
