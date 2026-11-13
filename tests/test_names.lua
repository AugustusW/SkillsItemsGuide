-- 使用者實測（2026-11-08）：裁縫清單很多品項是代碼、搜尋一直「名稱載入中…」
-- 根因：每個物品只請求一次，沒回來（伺服器漏回、client 沒有這個物品）就永遠沒名稱，搜尋永遠 pending
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")

local clientNames, requests, timers = {}, {}, {}
local function boot(locale)
  clientNames, requests, timers = {}, {}, {}
  H.reset({ locale = locale or "zhTW", extra = {
    C_Item = {
      GetItemNameByID = function(id) return clientNames[id] end,
      RequestLoadItemDataByID = function(id) requests[id] = (requests[id] or 0) + 1 end,
      GetItemIconByID = function() return 134400 end,
      GetItemInfo = function() return nil end,
    },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
      Hide = function() end, IsShown = function() return false end },
    hooksecurefunc = function() end,
  } })
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end
local function runTimers()
  local t = timers; timers = {}
  for _, fn in ipairs(t) do fn() end
end

-- 1. 打包的官方中文名稱當備用：client 還沒有名稱時不顯示代碼
local ns = boot("zhTW")
local ID = 2589
H.check(ns.Data.itemNames and ns.Data.itemNames[ID] ~= nil, "資料檔帶官方物品名稱（itemNames）")
H.eq(ns.Names.item(ID), ns.Data.itemNames and ns.Data.itemNames[ID], "client 沒有名稱時，繁中用打包的官方名稱")
clientNames[ID] = "亞麻布（client）"
H.eq(ns.Names.item(ID), "亞麻布（client）", "client 有名稱時優先用 client 的")

-- 2. 非繁中 client 不用中文備用名稱；英文 client 改用打包的英文名稱（0.4.0 起，物品分頁資料）
ns = boot("enUS")
H.eq(ns.Names.item(ID), "Linen Cloth", "英文 client 沒有名稱時用打包英文名，不回中文")
ns = boot("deDE")
H.eq(ns.Names.item(ID), nil, "德文 client 沒有打包名稱時回 nil（不回中文）")

-- 3. 沒回來的會重試，最多 3 次；之後不再算 pending
ns = boot("enUS")
local MISS = 999001
ns.Names.item(MISS); ns.Names.item(MISS)
H.eq(requests[MISS], 1, "同一輪內不重複請求")
H.check(ns.Names.isPending(MISS), "請求中算 pending")
runTimers(); ns.Names.item(MISS)
H.eq(requests[MISS], 1, "至少等滿一整輪才重試（輪中途才請求的不會被下一個計時器立刻放掉）")
runTimers(); ns.Names.item(MISS)
H.eq(requests[MISS], 2, "逾時後重試第 2 次")
runTimers(); runTimers(); ns.Names.item(MISS)
H.eq(requests[MISS], 3, "第 3 次")
runTimers(); runTimers(); ns.Names.item(MISS)
H.eq(requests[MISS], 3, "最多 3 次")
H.check(not ns.Names.isPending(MISS), "3 次都沒回來就不再算 pending")
H.eq(#timers, 0, "沒有在等的物品時不再排計時器")

-- 4. 伺服器明確回失敗：不再等
ns = boot("enUS")
local BAD = 999002
ns.Names.item(BAD)
H.fire("GET_ITEM_INFO_RECEIVED", BAD, false)
H.check(not ns.Names.isPending(BAD), "回報失敗的物品不再算 pending")
runTimers(); ns.Names.item(BAD)
H.eq(requests[BAD], 1, "回報失敗的物品不再重試")
H.fire("GET_ITEM_INFO_RECEIVED", 777777, false)
H.check(ns.Names.isPending(777777), "沒請求過的物品收到失敗事件（別的 addon 觸發）不標記失敗")

-- 4b. 沒有 C_Timer：請求一次後就不算 pending（不會永遠載入中）
H.reset({ locale = "enUS", extra = {
  C_Item = { GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end,
    GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
  C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
  hooksecurefunc = function() end,
} })
ns = H.load(files)
ns.Names.item(999003)
H.check(not ns.Names.isPending(999003), "沒有 C_Timer 時請求過就不算 pending")

-- 5. 搜尋不會永遠卡在「名稱載入中…」
ns = boot("enUS")
SkillsItemsGuideCharDB = { professions = { ["197"] = true } }
ns.Window.open({})
ns.Window.setProf(197)
ns.Window.setSearch("zzz-不存在")
H.eq(ns.Window.state().empty, "Names loading...", "名稱還在載入時先顯示載入中")
for _ = 1, 6 do runTimers(); ns.Window.setSearch("zzz-不存在") end
H.eq(ns.Window.state().empty, "No results", "重試用完後改顯示找不到，不再卡住")

-- 6. 繁中用打包名稱就搜得到
ns = boot("zhTW")
SkillsItemsGuideCharDB = { professions = { ["197"] = true } }
ns.Window.open({})
ns.Window.setProf(197)
ns.Window.setSearch("亞麻")
H.check(#ns.Window.state().list > 0, "繁中用打包名稱就搜得到「亞麻」")

-- 7. 英文 client：名稱未快取時標題用佔位；有結果但仍有名稱在載入，結果照列、標題提示載入中
ns = boot("enUS")
ns.Window.open({ material = 2589 })
H.eq(ns.Window.state().header, "Linen Cloth: used by 12 recipes", "英文名稱未快取時標題用打包英文名（0.4.0 前是 Item #2589 佔位）")
clientNames[2589] = "Linen Cloth"
SkillsItemsGuideCharDB = { professions = { ["197"] = true } }
ns.Window.open({})
ns.Window.setProf(197)
ns.Window.setSearch("Linen")
local st = ns.Window.state()
H.check(#st.list > 0, "已載入的名稱先列出結果")
H.check(st.loading and st.header:find("Names loading", 1, true) ~= nil, "有結果但仍有名稱在載入時，標題提示載入中")
for _ = 1, 6 do runTimers(); ns.Window.setSearch("Linen") end
H.check(ns.Window.state().header:find("Names loading", 1, true) == nil, "重試用完後標題不再提示")

-- 實測（2026-11-13）：C_Spell.GetSpellLink 的名稱帶「(等級 1)」，貼到對話送出後變純文字、不能點；
-- 技能書送的可以點 → 連結名稱只放法術名
H.reset({ locale = "zhTW", extra = {
  C_Spell = { GetSpellName = function() return "英勇打擊" end,
              GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. id .. ":0|h[英勇打擊 (等級 1)]|h|r" end },
} })
local nsL = H.load({ "Locale.lua", "Names.lua" })
H.eq(nsL.Names.spellLink(78), "|cff71d5ff|Hspell:78:0|h[英勇打擊]|h|r", "法術連結名稱不帶等級")
H.reset({ locale = "zhTW", extra = { C_Spell = { GetSpellName = function() return "100%傷害" end,
  GetSpellLink = function() return "|cff71d5ff|Hspell:1:0|h[x (等級 1)]|h|r" end } } })
nsL = H.load({ "Locale.lua", "Names.lua" })
H.eq(nsL.Names.spellLink(1), "|cff71d5ff|Hspell:1:0|h[100%傷害]|h|r", "名稱含 % 不出錯")
H.reset({ locale = "zhTW", extra = { C_Spell = { GetSpellName = function() return nil end, GetSpellLink = function() return nil end } } })
nsL = H.load({ "Locale.lua", "Names.lua" })
H.eq(nsL.Names.spellLink(1), nil, "沒有連結時回 nil")
