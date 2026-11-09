-- 樹狀拆解：把一個配方展開到沒有配方可做的物品為止，算出原料總數與冷卻次數
local _, ns = ...

local Breakdown = {}
ns.Breakdown = Breakdown

local function itemLevel(rid)
  local rec = ns.Data.recipes[rid]
  if rec.il then return rec.il end
  local it = rec.item and ns.Data.items and ns.Data.items[rec.item]
  return it and it.il
end

-- 排序：物品等級 → 技能等級 → recipeId；缺值排最後
local function cmp(a, b)
  local ia, ib = itemLevel(a), itemLevel(b)
  if ia ~= ib then
    if ia == nil then return false elseif ib == nil then return true end
    return ia < ib
  end
  local sa, sb = ns.Index.skillOf(a), ns.Index.skillOf(b)
  if sa ~= sb then
    if sa == nil then return false elseif sb == nil then return true end
    return sa < sb
  end
  return a < b
end

function Breakdown.sortRecipes(list) table.sort(list, cmp) return list end

-- 同一產物有多條配方：已學的優先；都沒學時優先沒有冷卻的（例：金錠熔煉優先於點鐵成金），再依排序
local function choose(list, known)
  if known then
    for _, rid in ipairs(list) do
      if ns.Index.learned(ns.Data.recipes[rid], known) then return rid end
    end
  end
  for _, rid in ipairs(list) do
    if not ns.Data.recipes[rid].cd then return rid end
  end
  return list[1]
end
Breakdown.choose = choose

function Breakdown.build(recipeId, qty, known)
  local totals, order, cds = {}, {}, {}
  local function addTotal(item, n)
    if not totals[item] then totals[item] = 0; order[#order + 1] = item end
    totals[item] = totals[item] + n
  end
  local function addCd(rid, times)
    local rec = ns.Data.recipes[rid]
    if not rec.cd then return end
    cds[rid] = (cds[rid] or 0) + times
  end

  local expand
  -- 製作 n 個 rid 的產物
  expand = function(rid, n, path)
    local rec = ns.Data.recipes[rid]
    local crafts = math.ceil(n / (rec.q or 1))
    addCd(rid, crafts)
    local node = { recipe = rid, item = rec.item, n = n, prof = rec.p, children = {} }
    local C = ns.Index.canonical
    if rec.item then path[C(rec.item)] = true end
    for _, rg in ipairs(rec.r or {}) do
      local item, need = rg[1], rg[2] * crafts
      local makers = ns.Index.madeBy(item)
      if #makers > 0 and not path[C(item)] and not ns.Index.cyclic(item) then
        local child = expand(choose(makers, known), need, path)
        child.item = item -- 正式版：做法產出可能是別的品質，樹上顯示配方要的那個（canonical）
        node.children[#node.children + 1] = child
      else
        addTotal(item, need)
        node.children[#node.children + 1] = { item = item, n = need, children = {} }
      end
    end
    if rec.item then path[C(rec.item)] = nil end
    return node
  end

  local root = expand(recipeId, qty, {})
  local list = {}
  for i, item in ipairs(order) do list[#list + 1] = { item = item, n = totals[item], first = i } end
  table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.first < b.first end)
  for _, t in ipairs(list) do t.first = nil end
  local cdList = {}
  for rid, times in pairs(cds) do cdList[#cdList + 1] = { recipe = rid, times = times, sec = ns.Data.recipes[rid].cd } end
  table.sort(cdList, function(a, b) return a.recipe < b.recipe end)
  local rootItem = ns.Data.recipes[recipeId].item
  local alts = rootItem and (#ns.Index.madeBy(rootItem) - 1) or 0
  return { root = root, totals = list, cooldowns = cdList, alternatives = alts }
end
