-- 配方取得方式的判定與 tooltip 行（純邏輯，只進永恆 TOC）。
-- 資料來自 Data/Forever/Sources.lua（D.sources 等），沒有資料（D.meta.sourcesGenerated 為 nil）時一律當沒有來源。
--
-- ctx = { side = "A"|"H"|nil, profSkill = 目前專業技能或 nil, names = { item = fn }|nil,
--         profName = 專業名稱（推定訓練師提示用，可省略）,
--         trainerSpells = { [法術 id] = true | 學費（銅） }|nil,
--         trainerSkills = { [法術 id] = 學會所需技能 }|nil }（訓練師快取；補 tr[1] 未知時用）
--   trainerSpells 為 nil（快取鍵不是數字法術 id 時 Task 4 傳 nil）→ 永遠不會是 "trainerOk"。
--
-- Source.kind(spell, ctx) -> "auto"|"book"|"trainerOk"|"trainer"|nil
-- Source.lines(spell, ctx) -> { {text=, flag=, ...}, ... }
-- Source.color(spell, skill, ctx) -> "o"|"y"|"g"|"x"|nil（skill 為 nil＝沒學這個專業；已知門檻且 skill < 門檻＝還學不了 → nil；
--   門檻 = tr[1]>1 ？ 訓練師快取 ？ 未知（不能說學不了，照 tr[2] 以下算橘））
--
-- 行的語意旗標 flag（由 Format.appendTree 上色）：
--   sourceTitle     「學會方式」標題（金字）
--   source          來源主行（自動學會／訓練師／配方：書名）；訓練師確認時 confirmed=true（金字＋勾圖示）；
--                   配方行帶 item（物品 id，供並排 tooltip）與 q（書的品質 0-5，缺則 nil）
--   sourceDetail    次要行（條件、任務、推定提示）；任務行帶 quest（任務 id）
--   sourceMore      「另有 N 個」
--   sideOther       （布林欄位，與 flag 並存）另一陣營，整行灰字
--   skillRangeTitle 「技能點數」標題
--   skillRange      四個數字：parts = { {text=, color="o"|"y"|"g"|"x"} x4 }
local _, ns = ...
local Source = {}
ns.Source = Source

local MAX_BOOKS, MAX_QUESTS = 3, 3
-- 任務、地區、陣營名稱：兩種語言都保留，每次依名稱語言取（語言切換可立即生效）。
-- 名稱語言：顯示語言 ≠ 客戶端時用顯示語言；否則繁中客戶端用繁中，其他一律英文（與 0.5 相同）
local NAMES
local function names()
  local all = ns.Data and ns.Data.sourceNamesByLocale
  if not all then return nil end
  local want = ns.useBundled() and ns.lang() or (ns.clientLang() == "zhTW" and "zhTW" or "enUS")
  return all[want]
end

-- 舊介面：測試換資料後呼叫（現在每次都即時取，不再快取）
function Source.init() NAMES = nil end

local function entry(spell)
  local D = ns.Data
  if not D or not D.meta or not D.meta.sourcesGenerated or not D.sources then return nil end
  return D.sources[spell]
end

local function trainerHas(spell, ctx)
  local set = ctx and ctx.trainerSpells
  return set ~= nil and set[spell] ~= nil and set[spell] ~= false
end

function Source.kind(spell, ctx)
  local e = entry(spell)
  if not e then return nil end
  if e.src ~= "auto" and trainerHas(spell, ctx) then return "trainerOk" end
  return e.src
end

-- 學會門檻：資料表 tr[1] > 1 才算數（<=1 是 wago MinSkillLineRank 的假值）；其次訓練師快取；否則 nil（未知）
local function learnSkill(spell, e, ctx)
  local o = e.tr[1]
  if o and o > 1 then return o end
  local ts = ctx and ctx.trainerSkills
  local v = ts and ts[spell]
  if v and v > 1 then return v end
  return nil
end

function Source.color(spell, skill, ctx)
  local e = entry(spell)
  if not e or not e.tr or not skill then return nil end
  local t = e.tr
  local need = learnSkill(spell, e, ctx)
  if need and skill < need then return nil end -- 技能還不到可學的門檻：不給顏色
  if skill >= t[4] then return "x" end
  if skill >= t[3] then return "g" end
  if skill >= t[2] then return "y" end
  return "o"
end

-- 外部來源的名稱（任務、地區、陣營、書名）可能含 WoW 跳脫字元，一律把 | 變成 ||
local function esc(s)
  if type(s) ~= "string" then return s end
  return (s:gsub("|", "||"))
end

local function bookName(id, ctx)
  local n
  if ns.DbIndex and ns.DbIndex.displayName then n = ns.DbIndex.displayName(id) end
  if not n and ctx and ctx.names and ctx.names.item then n = ctx.names.item(id) end
  if n then return esc(n) end
  return string.format(ns.L.ITEM_PLACEHOLDER, id)
end

local function sideTag(side)
  if side == "A" then return ns.L.SRC_SIDE_A end
  if side == "H" then return ns.L.SRC_SIDE_H end
end

local function isOther(side, mine) return side ~= nil and mine ~= nil and side ~= mine end

-- 自己陣營與中立在前，另一陣營在後；各組保持原順序
local function stableBySide(list, sideOf, mine)
  local a, b = {}, {}
  for _, v in ipairs(list) do
    if isOther(sideOf(v), mine) then b[#b + 1] = v else a[#a + 1] = v end
  end
  for _, v in ipairs(b) do a[#a + 1] = v end
  return a
end

local function repLabel(rank)
  -- 陣營名稱只有 zhTW／enUS 兩份；其他語系的遊戲全域字串會跟陣營名稱語言不一致，改用插件自己的等級名。
  -- 顯示語言 ≠ 客戶端時遊戲全域字串是另一種語言，同樣改用插件自己的
  if not ns.useBundled() and ns.clientLang() then
    local g = _G["FACTION_STANDING_LABEL" .. tostring(rank)]
    if type(g) == "string" and g ~= "" then return g end
  end
  local t = ns.L.REP_RANKS
  return t and t[rank]
end

local function condition(b)
  local L = ns.L
  local parts = {}
  if b.skill then parts[#parts + 1] = string.format(L.SRC_REQ_SKILL_FMT, b.skill) end
  if b.lv then parts[#parts + 1] = string.format(L.SRC_REQ_LEVEL_FMT, b.lv) end
  if b.bind == 1 then parts[#parts + 1] = L.SRC_BIND_1 elseif b.bind == 2 then parts[#parts + 1] = L.SRC_BIND_2 end
  NAMES = names()
  if b.fac and NAMES and NAMES.faction and NAMES.faction[b.fac] then
    local rank = b.rep and repLabel(b.rep)
    parts[#parts + 1] = rank and string.format(L.SRC_REP_FMT, esc(NAMES.faction[b.fac]), rank) or esc(NAMES.faction[b.fac])
  end
  if #parts == 0 then return nil end
  return table.concat(parts, L.SEP)
end

-- 任務文字：有名稱＝名稱（地區）；只有地區＝只列地區；都沒有＝nil（略過）。只用客戶端語系那份名稱
local function questText(qid)
  local L = ns.L
  NAMES = names()
  local name = esc(NAMES and NAMES.quest and NAMES.quest[qid])
  local area = esc(NAMES and NAMES.area and NAMES.area[qid])
  if name then
    return string.format(L.SRC_QUEST_FMT, area and string.format(L.SRC_QUEST_AREA_FMT, name, area) or name)
  elseif area then
    return string.format(L.SRC_QUEST_AREA_ONLY_FMT, area)
  end
end

local function moneyText(copper)
  if type(copper) ~= "number" or copper <= 0 then return nil end
  if GetMoneyString then return GetMoneyString(copper) end
  return tostring(copper)
end

-- 並排 tooltip 用：自己陣營（或中立）的第一本配方書物品 id；自動學會、沒有書、書全是另一陣營 → nil
-- （順序與 Source.lines 一致：stableBySide）
function Source.firstOwnBook(spell, ctx)
  local e = entry(spell)
  if not e or not e.books or Source.kind(spell, ctx) == "auto" then return nil end
  local mine = ctx and ctx.side
  local books = stableBySide(e.books, function(b) return b.side end, mine)
  local b = books[1]
  if b and not isOther(b.side, mine) then return b.item end
end

function Source.lines(spell, ctx)
  local e = entry(spell)
  local out = {}
  if not e then return out end
  local L = ns.L
  local mine = ctx and ctx.side
  local D = ns.Data
  local kind = Source.kind(spell, ctx)
  out[#out + 1] = { text = L.SRC_TITLE, flag = "sourceTitle" }

  if kind == "auto" then
    out[#out + 1] = { text = L.SRC_AUTO, flag = "source" }
  elseif kind == "trainerOk" then
    local cost = moneyText(ctx.trainerSpells[spell])
    out[#out + 1] = { text = cost and string.format(L.SRC_TRAINER_COST_FMT, cost) or L.SRC_TRAINER, flag = "source", confirmed = true }
  elseif kind == "trainer" then
    out[#out + 1] = { text = L.SRC_TRAINER_GUESS, flag = "source" }
    local pn = ctx and ctx.profName
    out[#out + 1] = { text = pn and string.format(L.SRC_TRAINER_GUESS_HINT_FMT, pn) or L.SRC_TRAINER_GUESS_HINT, flag = "sourceDetail" }
  end

  if e.books and kind ~= "auto" then
    local books = stableBySide(e.books, function(b) return b.side end, mine)
    for i = 1, math.min(#books, MAX_BOOKS) do
      local b = books[i]
      local other = isOther(b.side, mine) or nil
      local text = string.format(L.SRC_BOOK_FMT, bookName(b.item, ctx))
      local tag = sideTag(b.side)
      if tag then text = tag .. " " .. text end
      out[#out + 1] = { text = text, flag = "source", item = b.item, q = b.q, sideOther = other }
      local cond = condition(b)
      if cond then out[#out + 1] = { text = cond, flag = "sourceDetail", sideOther = other } end
      if b.quests then
        local shown = {}
        for _, qid in ipairs(stableBySide(b.quests, function(q) return D.sourceQuestSide and D.sourceQuestSide[q] end, mine)) do
          local t = questText(qid)
          if t then shown[#shown + 1] = { qid = qid, text = t } end
        end
        for j = 1, math.min(#shown, MAX_QUESTS) do
          local q = shown[j]
          local qside = D.sourceQuestSide and D.sourceQuestSide[q.qid]
          local text = q.text
          local qtag = sideTag(qside)
          if qtag then text = qtag .. " " .. text end
          out[#out + 1] = { text = text, flag = "sourceDetail", quest = q.qid, sideOther = (other or isOther(qside, mine)) or nil }
        end
        if #shown > MAX_QUESTS then
          out[#out + 1] = { text = string.format(L.SRC_MORE_FMT, #shown - MAX_QUESTS), flag = "sourceMore", sideOther = other }
        end
      end
    end
    if #books > MAX_BOOKS then
      out[#out + 1] = { text = string.format(L.SRC_MORE_FMT, #books - MAX_BOOKS), flag = "sourceMore" }
    end
  end

  if e.tr then
    out[#out + 1] = { text = L.SRC_RANGE_TITLE, flag = "skillRangeTitle" }
    local colors = { "o", "y", "g", "x" }
    local parts, strs = {}, {}
    for i = 1, 4 do
      local v = e.tr[i]
      if i == 1 then v = learnSkill(spell, e, ctx) or "-" end
      parts[i] = { text = tostring(v), color = colors[i] }
      strs[i] = parts[i].text
    end
    out[#out + 1] = { text = table.concat(strs, " "), flag = "skillRange", parts = parts }
  end
  return out
end

Source.init()
