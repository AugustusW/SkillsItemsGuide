-- 遊戲內名稱：物品用 C_Item（未快取時回 nil 並請求載入）、配方用法術名、專業用語系表
local _, ns = ...

local Names = {}
ns.Names = Names

-- 名稱載入（使用者實測 2026-11-08：只請求一次的話，伺服器漏回或 client 沒有的物品會永遠是代碼、搜尋永遠「載入中」）
-- 每個物品最多請求 MAX_TRIES 次。計時器每 RETRY_SEC 秒一輪；請求後至少等滿一整輪（下下個計時器）才重試，
-- 輪中途才請求的物品不會被下一個計時器立刻放掉。伺服器回報失敗的不再請求。
-- 沒有 C_Timer 時無法重試：請求一次就算結束（不能讓 inflight 永遠掛著，否則搜尋又會卡在載入中）。
local MAX_TRIES, RETRY_SEC = 3, 5
local tries, inflight, failed = {}, {}, {} -- inflight[id] = 送出請求時的輪次
local round, scheduled = 0, false

local function tick()
  scheduled = false
  round = round + 1
  local waiting = false
  for id, r in pairs(inflight) do
    if r < round - 1 then inflight[id] = nil else waiting = true end
  end
  if waiting then
    scheduled = true
    C_Timer.After(RETRY_SEC, tick)
  end
  if ns.Window and ns.Window.refreshIfShown then ns.Window.refreshIfShown() end
end

local function fallback(id)
  -- 打包的是官方 API 的 zh_TW 名稱，只在繁中 client 用
  if GetLocale and GetLocale() == "zhTW" then
    local t = ns.Data and ns.Data.itemNames
    if t and t[id] then return t[id] end
  end
  -- 永恆全部物品（繁中／英文名稱，物品分頁的資料）
  return ns.DbIndex and ns.DbIndex.bundledName(id) or nil
end

function Names.item(id)
  if not id then return nil end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if name then return name end
  local n = tries[id] or 0
  if not failed[id] and not inflight[id] and n < MAX_TRIES and C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(id)
    if C_Timer and C_Timer.After then
      tries[id], inflight[id] = n + 1, round
      if not scheduled then scheduled = true; C_Timer.After(RETRY_SEC, tick) end
    else
      tries[id] = MAX_TRIES
    end
  end
  return fallback(id)
end

-- 名稱還可能回來嗎（搜尋用：可能回來的才算「載入中」）
function Names.isPending(id)
  if failed[id] then return false end
  return inflight[id] ~= nil or (tries[id] or 0) < MAX_TRIES
end

-- 只標記自己請求過的物品（GET_ITEM_INFO_RECEIVED 也會因為別的 addon 的請求觸發）
function Names.markFailed(id)
  if id and tries[id] then failed[id] = true; inflight[id] = nil end
end

function Names.prof(id) return ns.L.prof(id) end

function Names.recipe(rid)
  local rec = ns.Data.recipes[rid]
  local sp = rec and rec.spell
  return sp and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sp) or nil
end

-- 法術連結：C_Spell.GetSpellLink 的名稱帶等級（「英勇打擊 (等級 1)」），送出後伺服器不認、變純文字；
-- 技能書送的可以點（使用者 2026-11-13 實測）→ 只把方括號內換成法術名，其他照遊戲給的格式
function Names.spellLink(id)
  local link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(id)
  if not link then return nil end
  local name = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
  if not name then return link end
  return (link:gsub("%[.-%]", "[" .. name:gsub("%%", "%%%%") .. "]", 1))
end
