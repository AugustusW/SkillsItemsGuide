-- 物品／法術分頁的資料：插件包內跟專業、職業技能有關的物品與法術（永恆限定）
-- 物品分類在第一次用到時建好並快取；職業技能每次照職業技能分頁同一套（Skills.list）重算，
-- 才會跟著訓練師快取與已學狀態變動。
local _, ns = ...
local L = ns.L

local DbIndex = {}
ns.DbIndex = DbIndex

local info, sortedItems, supOf, all

-- 永恆全部物品（Data/Forever/Items.lua 的長字串）：第一次用到才解開。
-- 一行：<id 差 36 進位>,<品質>,<類別 36>,<子類別 36>,<物品等級 36>,<名稱>（產生端 tools/build_data.py encode_items）
function DbIndex.allItems()
  if all then return all end
  all = {}
  local src = ns.Data.allItems
  if not (src and src.rows) then return all end
  local prev = 0
  local order = {}
  for d, q, c, sc, il, name in src.rows:gmatch("(%w+),(%d*),(%w*),(%w*),(%w*),([^\n]*)\n") do
    prev = prev + tonumber(d, 36)
    all[prev] = { q = tonumber(q), c = c ~= "" and tonumber(c, 36) or nil, s = sc ~= "" and tonumber(sc, 36) or nil,
      il = il ~= "" and tonumber(il, 36) or nil, name = name }
    order[#order + 1] = prev
  end
  -- 英文名稱（一行一個、順序同 rows）：只有英文客戶端才解
  local loc = GetLocale and GetLocale()
  if src.en and (loc == "enUS" or loc == "enGB") then
    local k = 0
    for n in src.en:gmatch("([^\n]*)\n") do
      k = k + 1
      if n ~= "" and order[k] then all[order[k]].en = n end
    end
  end
  return all
end

-- 打包的名稱（繁中或英文客戶端）；沒有回 nil
function DbIndex.bundledName(id)
  local a = DbIndex.allItems()[id]
  if not a then return nil end
  local n = GetLocale and GetLocale() == "zhTW" and a.name or a.en
  return n ~= "" and n or nil
end

-- 畫面上的名稱：遊戲名稱優先，還沒載入時用打包名稱
function DbIndex.displayName(id)
  return ns.Names.item(id) or DbIndex.bundledName(id)
end

-- 打包的品質（專業資料優先，其次全部物品）；都沒有回 nil
function DbIndex.quality(id)
  local it = ns.Data.items and ns.Data.items[id]
  if it and it.q then return it.q end
  local a = DbIndex.allItems()[id]
  return a and a.q
end

-- 搜尋用名稱：繁中、英文直接用打包名稱（不向伺服器請求）；其他語系只搜專業物品（走 Names.item）
local zh = GetLocale and GetLocale() == "zhTW"
local function searchName(id)
  if zh then
    local n = ns.Data.itemNames and ns.Data.itemNames[id]
    if n then return n, false end
  end
  local b = DbIndex.bundledName(id) -- 繁中或英文客戶端：直接比對打包名稱，不向伺服器請求
  if b then return b, false end
  if info[id] and info[id].total > 0 then
    local n = ns.Names.item(id)
    return n, n == nil and ns.Names.isPending(id)
  end
  -- 非繁中、跟配方無關的物品不搜尋：GetItemNameByID 遇到沒快取的物品可能向伺服器請求，
  -- 每按一鍵就是上萬個請求（review）。瀏覽（不輸入搜尋字）時照樣列出
  return nil, false
end

local knownCache
-- 已學集合：一次重算（一輪 compute）只建一次（review：每列都建會在每次按鍵建 200 次）
function DbIndex.resetKnown() knownCache = nil end
local function knownSet()
  if knownCache then return knownCache end
  local set = {}
  for k in pairs((SkillsItemsGuideCharDB or {}).known or {}) do local n = tonumber(k) if n then set[n] = true end end
  knownCache = set
  return set
end

local function buildItems()
  info, sortedItems = {}, {}
  local ids = {}
  for id in pairs(ns.Data.items or {}) do ids[id] = true end
  for id in pairs(DbIndex.allItems()) do ids[id] = true end
  for id in pairs(ids) do
    local used, made = ns.Index.usedBy(id), ns.Index.madeBy(id)
    local profs = {}
    for _, rid in ipairs(used) do profs[ns.Data.recipes[rid].p] = true end
    for _, rid in ipairs(made) do profs[ns.Data.recipes[rid].p] = true end
    local a = all[id]
    local pk = ns.Data.items and ns.Data.items[id]
    info[id] = { isMat = #used > 0, isProduct = #made > 0, profs = profs, total = #used + #made,
      c = a and a.c, s = a and a.s, il = (a and a.il) or (pk and pk.il) }
    sortedItems[#sortedItems + 1] = id
  end
  -- 使用者 2026-11-13：物品等級高→低；同等級品質高→低，再依 id（名稱非同步載入，不拿名稱排）；沒有等級的排最後
  local q = {}
  for id in pairs(info) do q[id] = DbIndex.quality(id) or -1 end
  table.sort(sortedItems, function(a, b)
    local la, lb = info[a].il or -1, info[b].il or -1
    if la ~= lb then return la > lb end
    if q[a] ~= q[b] then return q[a] > q[b] end
    return a < b
  end)
end

function DbIndex.itemInfo(id)
  if not info then buildItems() end
  local i = info[id]
  if i and i.isProduct then i.made = ns.Breakdown.choose(ns.Index.madeBy(id), knownSet()) end
  return i
end

local function nameMatches(name, id, q)
  if name == nil then return false, ns.Names.isPending(id) end
  return name:find(q, 1, true) ~= nil, false
end

-- 類別名稱：打包的是繁中；其他語系先跟遊戲要當地語言的名稱，拿不到才用打包的
function DbIndex.className(c, s)
  local cls = ns.Data.itemClasses and ns.Data.itemClasses[c]
  if not cls then return nil, nil end
  local name, sub = cls.name, s and cls.sub and cls.sub[s]
  if not zh and C_Item then
    name = (C_Item.GetItemClassInfo and C_Item.GetItemClassInfo(c)) or name
    if s then sub = (C_Item.GetItemSubClassInfo and C_Item.GetItemSubClassInfo(c, s)) or sub end
  end
  return name, sub
end

-- filter = { kind = "all"|"mat"|"product", prof = id|nil, cls = 物品類別|nil, q = 品質|nil }
function DbIndex.items(filter, query)
  if not info then buildItems() end
  filter = filter or {}
  local kind = filter.kind or "all"
  local list, loading = {}, false
  for _, id in ipairs(sortedItems) do
    local i = info[id]
    local keep = (kind == "all" or (kind == "mat" and i.isMat) or (kind == "product" and i.isProduct))
      and (not filter.prof or i.profs[filter.prof]) and (not filter.cls or i.c == filter.cls)
    if keep and filter.q then -- 遊戲還沒回報品質的物品：先不列，標「載入中」
      local q = ns.Window.itemQuality(id)
      if q == nil then loading = true end
      keep = q == filter.q
    end
    if keep and query and query ~= "" then
      local name, pending = searchName(id)
      if pending then loading = true end
      keep = name ~= nil and name:find(query, 1, true) ~= nil
    end
    if keep then list[#list + 1] = id end
  end
  return { list = list, loading = loading }
end

function DbIndex.itemSummary(id)
  local i = DbIndex.itemInfo(id)
  if not i then return "" end
  local parts = {}
  if i.isMat then
    local counts = {}
    for _, c in ipairs(ns.Index.profCounts(id)) do counts[#counts + 1] = L.prof(c.prof) .. " " .. (c.n + c.old) end
    parts[#parts + 1] = string.format(L.DB_MAT_FMT, #ns.Index.usedBy(id), L.join(counts))
  end
  if i.isProduct then
    local rec = ns.Data.recipes[i.made]
    local skill = ns.Index.skillOf(i.made)
    local who = L.prof(rec.p) .. (skill and (" " .. skill) or "")
    parts[#parts + 1] = string.format(L.DB_PRODUCT_FMT, who)
  end
  if #parts == 0 then -- 非專業物品：類別、子類別、物品等級
    local c, sc = DbIndex.className(i.c, i.s)
    if c then parts[#parts + 1] = c end
    if sc and sc ~= c then parts[#parts + 1] = sc end
    if i.il then parts[#parts + 1] = string.format(L.DB_ILVL_FMT, i.il) end
  end
  return table.concat(parts, L.DOT)
end

-- ---------- 法術 ----------

local function buildSup()
  supOf = {}
  for _, rows in pairs(ns.Data.classSkills or {}) do
    for _, r in ipairs(rows) do if r.sup then supOf[r.spell] = r.sup end end
  end
end

local function spellName(id) return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end

-- filter = { kind = "all"|"recipe"|"class", prof = id|nil, classId = id|nil }
function DbIndex.spells(filter, query)
  if not supOf then buildSup() end
  filter = filter or {}
  local kind = filter.kind or "all"
  local q = query ~= "" and query or nil
  local list, loading = {}, false
  local function nameOk(spell)
    if not q then return true end
    local n = spellName(spell)
    return n ~= nil and n:find(q, 1, true) ~= nil
  end
  if (kind == "all" or kind == "class") and not filter.prof then
    for _, classId in ipairs(ns.Skills.CLASS_ORDER) do
      if not filter.classId or filter.classId == classId then
        local res = ns.Skills.list(classId, (ns.Skills.optsFor(classId)))
        for _, g in ipairs(res.groups) do
          for _, r in ipairs(g.rows) do
            if nameOk(r.spell) then
              list[#list + 1] = { spell = r.spell, classId = classId, lv = r.lv, cost = r.cost, status = r.status,
                sup = supOf[r.spell] }
            end
          end
        end
      end
    end
  end
  if (kind == "all" or kind == "recipe") and not filter.classId then
    local rids = {}
    for rid, rec in pairs(ns.Data.recipes or {}) do
      if rec.spell and (not filter.prof or rec.p == filter.prof) then
        local ok = nameOk(rec.spell)
        if not ok and q and rec.item then
          local hit, pending = nameMatches(ns.Names.item(rec.item), rec.item, q)
          if pending then loading = true end
          ok = hit
        end
        if ok then rids[#rids + 1] = rid end
      end
    end
    ns.Breakdown.sortRecipes(rids)
    for _, rid in ipairs(rids) do list[#list + 1] = { spell = ns.Data.recipes[rid].spell, rid = rid } end
  end
  return { list = list, loading = loading }
end

local STATUS_LABEL = { learned = "SHOW_LEARNED", available = "SHOW_AVAILABLE", tooLow = "SHOW_TOOLOW", other = "NOT_TRAINER" }

-- 法術名＋子標題（「火球術 等級 5」），同職業技能分頁
function DbIndex.spellTitle(spell)
  local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spell)
  return (spellName(spell) or ("#" .. spell)) .. (sub and sub ~= "" and (" " .. sub) or "")
end

-- className 由畫面傳入（可帶職業色）；不傳就用純文字
function DbIndex.spellSummary(e, className)
  local parts = {}
  if e.classId then
    parts[1] = string.format(L.DB_CLASS_FMT, className or L.class(e.classId), e.lv)
    if e.cost then parts[#parts + 1] = string.format(L.DB_COST_FMT, ns.SkillTab and ns.SkillTab.costText(e.cost) or tostring(e.cost)) end
    if e.sup then parts[#parts + 1] = string.format(L.DB_SUP_FMT, DbIndex.spellTitle(e.sup)) end
    if e.status then parts[#parts + 1] = L[STATUS_LABEL[e.status]] end
  else
    local rec = ns.Data.recipes[e.rid]
    local skill = ns.Index.skillOf(e.rid)
    parts[1] = string.format(L.DB_RECIPE_FMT, L.prof(rec.p) .. (skill and (" " .. skill) or ""))
    if rec.item then parts[2] = string.format(L.DB_YIELD_FMT, ns.Names.item(rec.item) or string.format(L.ITEM_PLACEHOLDER, rec.item)) end
  end
  return table.concat(parts, L.DOT)
end
