-- 訓練師快取：開訓練師視窗時，暫時打開全部篩選，讀完所有服務（含還不能學的），再還原篩選
local _, ns = ...

local Scan = {}
ns.Scan = Scan

local FILTERS = { "available", "unavailable", "used" }

local function serviceId(i)
  local tip = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(i)
  return tip and tip.id
end

-- 專業訓練師：用訓練師的技能名稱對到自己學的專業，取 skillLine id
local function professionId()
  local line = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(1)
  if not (line and GetProfessions and GetProfessionInfo) then return nil end
  local list = { GetProfessions() }
  for i = 1, 6 do
    local idx = list[i]
    if idx then
      local name, _, _, _, _, _, skillLine = GetProfessionInfo(idx)
      if name == line then return skillLine end
    end
  end
  return nil
end

-- 是否為本職業的訓練師：至少一個服務的法術 id 或名稱屬於本職業技能（排除武器大師、寵物、騎術訓練師）
local function isOwnClassTrainer(classId, rows)
  local list = (ns.Data and ns.Data.classSkills or {})[classId] or {}
  local ids, names = {}, {}
  for _, r in ipairs(list) do
    ids[r.spell] = true
    local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(r.spell)
    if n then names[n] = true end
  end
  for key, row in pairs(rows) do
    if ids[tonumber(key)] or names[row.name] then return true end
  end
  return false
end

local function readServices()
  local rows = {}
  for i = 1, GetNumTrainerServices() do
    local name, rank, state = GetTrainerServiceInfo(i)
    if name and state ~= "header" then
      local id = serviceId(i)
      local lv = GetTrainerServiceLevelReq(i)
      -- 已學的服務需求等級回 0（實測），存成未知
      local row = { name = name, rank = rank, lv = (lv and lv > 0) and lv or nil, cost = GetTrainerServiceCost(i) }
      if GetTrainerServiceSkillReq then
        local _, skill = GetTrainerServiceSkillReq(i)
        row.skill = skill
      end
      rows[id and tostring(id) or (name .. "|" .. tostring(rank))] = row
    end
  end
  return rows
end

local scanning, savedThisVisit = false, false

function Scan.trainer(event)
  if scanning or savedThisVisit then return end
  if not (GetNumTrainerServices and SetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter) then return end
  local db = SkillsItemsGuideDB
  local debug = { event = event, date = date("%Y-%m-%d %H:%M") }
  db.trainerDebug = debug
  scanning = true
  local saved = {}
  for _, f in ipairs(FILTERS) do saved[f] = GetTrainerServiceTypeFilter(f) and true or false end
  for _, f in ipairs(FILTERS) do SetTrainerServiceTypeFilter(f, true) end
  -- 讀取包在 pcall 裡：中途出錯也一定還原使用者的篩選
  local ok, rows = (ns.ErrorLog and ns.ErrorLog.try or pcall)(readServices)
  local isProf = IsTradeskillTrainer and IsTradeskillTrainer()
  local key = isProf and professionId() or nil
  for _, f in ipairs(FILTERS) do SetTrainerServiceTypeFilter(f, saved[f]) end
  scanning = false

  local count = 0
  for _ in pairs(ok and rows or {}) do count = count + 1 end
  debug.ok, debug.err, debug.count, debug.isProf = ok, (not ok) and tostring(rows) or nil, count, isProf and true or false
  if not ok or count == 0 then return end
  -- 讀到資料就結束這次造訪（不論最後有沒有寫入），避免非同步 TRAINER_UPDATE 一直重讀、重設篩選
  savedThisVisit = true

  local bucket = isProf and "prof" or "class"
  if not isProf then
    key = select(3, UnitClass("player"))
    debug.matched = isOwnClassTrainer(key, rows)
    if not debug.matched then return end
  end
  debug.key = key
  if not key then return end
  db.trainer = db.trainer or {}
  db.trainer[bucket] = db.trainer[bucket] or {}
  local entry = db.trainer[bucket][tostring(key)] or { spells = {} }
  db.trainer[bucket][tostring(key)] = entry
  local version, build = GetBuildInfo()
  entry.build = version .. "." .. build
  entry.date = date("%Y-%m-%d")
  entry.spells = entry.spells or {}
  for k, row in pairs(rows) do entry.spells[k] = row end
  debug.saved = true
  savedThisVisit = true
  -- 專業訓練師快取剛更新：視窗開著就重繪，標籤不用切分頁就變金色
  if isProf and ns.Window and ns.Window.refreshIfShown then ns.Window.refreshIfShown() end
end

ns.onLoad = ns.onLoad or {}
table.insert(ns.onLoad, function()
  if not ns.Flavor.isForever() then return end -- 正式版沒有職業技能分頁，不掃訓練師
  local f = CreateFrame("Frame")
  f:RegisterEvent("TRAINER_SHOW")
  f:RegisterEvent("TRAINER_UPDATE")
  f:RegisterEvent("TRAINER_CLOSED")
  -- 開啟當下清單可能還是空的，TRAINER_UPDATE 再讀；同一次造訪寫入成功就不再讀
  f:SetScript("OnEvent", function(_, ev)
    if ev == "TRAINER_SHOW" or ev == "TRAINER_CLOSED" then savedThisVisit = false end
    if ev ~= "TRAINER_CLOSED" then Scan.trainer(ev) end
  end)
end)

-- 學了哪些專業（登入、技能變動時）
function Scan.professions()
  if not (GetProfessions and GetProfessionInfo) then return end
  local char = SkillsItemsGuideCharDB
  char.professions = {}
  local list = { GetProfessions() }
  for i = 1, 6 do
    local idx = list[i]
    if idx then
      local skillLine = select(7, GetProfessionInfo(idx))
      if skillLine then char.professions[tostring(skillLine)] = true end
    end
  end
end

-- 已學配方（開專業視窗時）；永恆客戶端的 recipeID 等於法術 id
function Scan.known()
  local ui = C_TradeSkillUI
  if not (ui and ui.GetAllRecipeIDs and ui.GetRecipeInfo) then return end
  -- 開的是別人的專業（聊天連結、公會成員、製作訂單）：learned 描述的是對方，不能記成自己的（審查 2026-11-09）
  for _, k in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting", "IsRuneforging" }) do
    if ui[k] and ui[k]() then return end
  end
  local char = SkillsItemsGuideCharDB
  char.known = char.known or {}
  char.opened = char.opened or {}
  -- 法術 id → 專業：用打包資料判斷這次開的是哪個專業（不需要額外 API）
  local profOf = {}
  for _, rec in pairs((ns.Data and ns.Data.recipes) or {}) do
    for _, sp in ipairs(rec.spells or { rec.spell }) do profOf[sp] = rec.p end
  end
  for _, id in ipairs(ui.GetAllRecipeIDs() or {}) do
    -- 視窗列出的配方（不論學了沒）都代表這個專業開過；只學採集專業的角色也能消掉提示
    local p = profOf[id]
    if p then char.opened[tostring(p)] = true end
    local info = ui.GetRecipeInfo(id)
    if info and info.learned then char.known[tostring(id)] = true end
  end
end

-- 有配方來源資料的專業 id 集合（佔位資料或零售版為空表）。trainer.prof 與 char.professions 的鍵同為 skillLine id
local function sourceProfessions()
  local D = ns.Data
  local set = {}
  if not (ns.Source and ns.Flavor and ns.Flavor.isForever() and D and D.meta and D.meta.sourcesGenerated and D.sources) then return set end
  for _, rec in pairs(D.recipes or {}) do
    for _, sp in ipairs(rec.spells or { rec.spell }) do
      if D.sources[sp] then set[rec.p] = true end
    end
  end
  return set
end

-- 學了但還沒開過視窗、而且至少學了一個配方的專業名稱（已排序）；登入提示與視窗底部共用。
-- 一個配方都沒學的專業（例：永恆版釣魚）視窗是空清單，用配方反推不到是哪個專業，會每次登入都提示（使用者 2026-11-28）；
-- 沒學配方也沒東西可掃，不提示。永恆版 GetBaseProfessionInfo 回空值，改用 IsPlayerSpell（實測 56 個已學配方全部認得）
-- 每個專業有沒有學到配方的快取：視窗每次重繪都會問，正式版一萬多筆配方不能每次重掃（審查 2026-11-28）。
-- 專業與專業視窗相關事件時清掉（下面的事件處理）
local hasLearned = {}

function Scan.unopened()
  local char = SkillsItemsGuideCharDB or {}
  local D = ns.Data or {}
  local pending, left, candidates = {}, 0, {}
  for p in pairs(char.professions or {}) do
    local id = tonumber(p)
    if id and not (char.opened or {})[p] and D.professions and D.professions[id] then
      candidates[#candidates + 1] = id
      if hasLearned[id] == nil then pending[id] = true; left = left + 1 end
    end
  end
  if left > 0 and IsPlayerSpell then
    for _, rec in pairs(D.recipes or {}) do
      if pending[rec.p] then
        for _, sp in ipairs(rec.spells or { rec.spell }) do
          if IsPlayerSpell(sp) then hasLearned[rec.p] = true; pending[rec.p] = nil; left = left - 1; break end
        end
        if left == 0 then break end
      end
    end
    for id in pairs(pending) do hasLearned[id] = false end
  end
  local missing = {}
  for _, id in ipairs(candidates) do
    if hasLearned[id] then missing[#missing + 1] = ns.L.prof(id) end
  end
  table.sort(missing)
  return missing
end

-- 登入提示：學了但還沒開過視窗的專業（使用者 2026-11-08：不提示的話使用者不知道要開）；
-- 永恆版再加一行：學了但訓練師沒開過的專業（2026-11-22，需要玩家動作的功能要主動提示、做完就不再提示）
function Scan.remindUnopened()
  local char = SkillsItemsGuideCharDB
  local db = SkillsItemsGuideDB or {}
  local trainerProf = db.trainer and db.trainer.prof or {}
  local withSources = sourceProfessions()
  local missing, noTrainer = Scan.unopened(), {}
  for p in pairs(char.professions or {}) do
    local id = tonumber(p)
    if id and ns.Data and ns.Data.professions and ns.Data.professions[id] then
      if withSources[id] and not trainerProf[p] then noTrainer[#noTrainer + 1] = ns.L.prof(id) end
    end
  end
  if #missing == 0 and #noTrainer == 0 then return end
  local lines = {}
  if #missing > 0 then
    lines[#lines + 1] = ns.L.ADDON_TITLE .. ns.L.COLON .. string.format(ns.L.NOT_OPENED_FMT, ns.L.join(missing))
  end
  if #noTrainer > 0 then
    table.sort(noTrainer)
    lines[#lines + 1] = ns.L.ADDON_TITLE .. ns.L.COLON .. string.format(ns.L.TRAINER_NOT_OPENED_FMT, ns.L.join(noTrainer))
  end
  local function say() for _, m in ipairs(lines) do print(m) end end
  if C_Timer and C_Timer.After then C_Timer.After(5, say) else say() end
end

table.insert(ns.onLoad, function()
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("SKILL_LINES_CHANGED")
  f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
  f:RegisterEvent("TRADE_SKILL_SHOW")
  -- 正式版一個專業上千個配方、專業視窗事件很密：0.5 秒內合併成一次掃描
  local pendingScan = false
  local function knownSoon()
    if not (ns.Flavor.isRetail() and C_Timer and C_Timer.After) then return Scan.known() end
    if pendingScan then return end
    pendingScan = true
    C_Timer.After(0.5, function() pendingScan = false; Scan.known() end)
  end
  f:SetScript("OnEvent", function(_, ev)
    hasLearned = {}
    if ev == "PLAYER_LOGIN" or ev == "SKILL_LINES_CHANGED" then Scan.professions() else knownSoon() end
    if ev == "PLAYER_LOGIN" then Scan.remindUnopened() end
  end)
end)
