-- 語言切換：名稱與格式的來源（spec 2026-11-27「文字與名稱的來源規則」）
-- 三種名稱用互不相同的哨兵：遊戲回 "G"..id；打包繁中、打包英文用真資料（亞麻布／Linen Cloth）或 "Z"／"E" 開頭
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local LINEN, THUNDER = 2589, 19019
local calls
local function boot(client, setting)
  calls = { secondsToTime = 0 }
  H.reset({ locale = client, extra = {
    C_Item = {
      GetItemNameByID = function(id) return "G" .. id end,
      RequestLoadItemDataByID = function() end,
      GetItemClassInfo = function(c) return "G" .. c end,
      GetItemSubClassInfo = function(c, s) return "G" .. c .. "." .. s end,
    },
    C_Spell = { GetSpellName = function(id) return "G" .. id end, GetSpellTexture = function() return 1 end,
      GetSpellSubtext = function(id) if id == 11 then return "Racial" end return "Rank 5" end,
      GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. id .. "|h[G" .. id .. " (Rank 5)]|h|r" end },
    C_Timer = { After = function() end },
    SecondsToTime = function() calls.secondsToTime = calls.secondsToTime + 1 return "GAME" end,
    UnitClass = function() return "Mage", "MAGE", 8 end, UnitLevel = function() return 18 end,
    IsSpellKnown = function() return false end,
    hooksecurefunc = function() end,
    GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
      Hide = function() end, IsShown = function() return false end },
  } })
  SkillsItemsGuideDB = setting and { lang = setting } or nil
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  ns.Data.spellNames = { n = 2, ids = "a\n1\n", zhTW = "Z10\nZ11\n", enUS = "E10\n\n" } -- 11 沒有英文
  ns.Names._resetSpellCache()
  return ns
end

local ZH_LINEN = nil
do local ns = boot("zhTW", nil) ZH_LINEN = ns.Data.itemNames[LINEN] end
H.check(ZH_LINEN and ZH_LINEN ~= "G" .. LINEN, "測試前提：打包繁中名稱存在且不同於遊戲哨兵")

-- 每格：{ 客戶端, 設定, 法術 10, 物品亞麻布, 類別 4 }
local CASES = {
  { "zhTW", nil,    "G10", "G2589", "zhcls" },
  { "zhTW", "zhTW", "G10", "G2589", "zhcls" },
  { "zhTW", "enUS", "E10", "Linen Cloth", "encls" },
  { "enUS", nil,    "G10", "G2589", "G4" },
  { "enUS", "zhTW", "Z10", "zh", "zhcls" },
  { "enUS", "enUS", "G10", "G2589", "G4" },
  { "deDE", nil,    "G10", "G2589", "G4" },
  { "deDE", "zhTW", "Z10", "zh", "zhcls" },
  { "deDE", "enUS", "E10", "Linen Cloth", "encls" },
}
for _, c in ipairs(CASES) do
  local ns = boot(c[1], c[2])
  local tag = c[1] .. "＋" .. tostring(c[2]) .. " "
  H.eq(ns.Names.spell(10), c[3], tag .. "法術名稱來源")
  H.eq(ns.Names.item(LINEN), c[4] == "zh" and ZH_LINEN or c[4], tag .. "物品名稱來源")
  local cls = ns.DbIndex.className(4)
  local want = ({ zhcls = ns.Data.itemClasses[4].name, encls = ns.Data.itemClassesEn[4].name })[c[5]] or c[5]
  H.eq(cls, want, tag .. "物品類別名稱來源")
  H.eq(ns.Names.recipe(next(ns.Data.recipes)) ~= nil, true, tag .. "配方名稱不為 nil")
end

-- 打包名稱是空的 → 退回遊戲名稱
local ns = boot("zhTW", "enUS")
H.eq(ns.Names.spell(11), "G11", "打包英文缺 → 用遊戲名稱")
H.eq(ns.Names.spell(999), "G999", "不在打包清單 → 用遊戲名稱")

-- 搜尋：用名稱語言的打包名稱，跟隨遊戲時與 0.5 相同
local function hit(n, q, id)
  for _, x in ipairs(n.DbIndex.items({ kind = "all" }, q).list) do if x == id then return true end end
  return false
end
ns = boot("enUS", "zhTW")
H.check(hit(ns, ZH_LINEN, LINEN), "英文客戶端切繁中：用繁中名稱搜得到")
H.check(not hit(ns, "Linen Cloth", LINEN), "英文客戶端切繁中：英文名稱搜不到")
ns = boot("zhTW", "enUS")
H.check(hit(ns, "Thunderfury", THUNDER), "繁中客戶端切英文：英文名稱搜得到非專業物品")
ns = boot("deDE", nil)
H.check(hit(ns, "G" .. LINEN, LINEN), "德文客戶端跟隨遊戲：專業物品仍用遊戲名稱搜尋")
H.check(not hit(ns, "Thunderfury", THUNDER), "德文客戶端跟隨遊戲：不用打包英文名稱")

-- 繁中客戶端跟隨遊戲：不解英文名稱（不多佔記憶體）
ns = boot("zhTW", nil)
hit(ns, ZH_LINEN, LINEN)
ns.Names.item(THUNDER)
H.eq(ns.DbIndex.allItems()[THUNDER].en, nil, "繁中跟隨遊戲時英文名稱不解碼")

-- 子標題
ns = boot("enUS", "zhTW")
H.eq(ns.Names.spellSub(10), "等級 5", "切繁中：Rank 5 → 等級 5")
H.eq(ns.Names.spellSub(11), "Racial", "非等級子標題照遊戲給的")
H.eq(ns.DbIndex.spellTitle(10), "Z10 等級 5", "法術標題＝打包名稱＋重組子標題")
ns = boot("enUS", nil)
H.eq(ns.Names.spellSub(10), "Rank 5", "跟隨遊戲：子標題不動")

-- 冷卻時間
ns = boot("enUS", "zhTW")
H.eq(ns.Format.duration(90000), "1 天 1 小時", "切繁中：插件自己排冷卻時間")
H.eq(ns.Format.duration(1800), "30 分鐘", "只有分鐘")
H.eq(calls.secondsToTime, 0, "切繁中不呼叫 SecondsToTime")
ns = boot("zhTW", "enUS")
H.eq(ns.Format.duration(90000), "1 Day 1 Hr", "切英文")
ns = boot("enUS", nil)
H.eq(ns.Format.duration(90000), "GAME", "跟隨遊戲：用遊戲的 SecondsToTime")

-- 一定用客戶端語言（負面對照：顯示語言 ≠ 客戶端時結果與跟隨遊戲相同）
local a, b = boot("enUS", nil), nil
local clientA, linkA = a.DbIndex.clientName(LINEN), a.Names.spellLink(10)
b = boot("enUS", "zhTW")
H.eq(b.DbIndex.clientName(LINEN), clientA, "ItemLevel 比對用的名稱不跟顯示語言")
H.eq(clientA, "Linen Cloth", "英文客戶端 clientName 是英文")
H.eq(b.Names.spellLink(10), linkA, "聊天連結不跟顯示語言")
local scanSrc = io.open(H.dir .. "/Scan.lua"):read("*a")
H.check(scanSrc:find("C_Spell.GetSpellName(r.spell)", 1, true) ~= nil, "Scan 訓練師比對直接用遊戲名稱（客戶端語言）")
local ilSrc = io.open(H.dir .. "/ItemLevel.lua"):read("*a")
H.check(ilSrc:find("DbIndex.clientName(id)", 1, true) ~= nil and not ilSrc:find("bundledName", 1, true),
  "ItemLevel 用 clientName")

-- 立即切換：同一個 session 內換語言，名稱馬上跟著換
ns = boot("enUS", nil)
H.eq(ns.Names.spell(10), "G10", "切換前")
ns.setLang("zhTW")
H.eq(ns.Names.spell(10), "Z10", "setLang 後立即用打包繁中")
H.eq(ns.Names.item(LINEN), ZH_LINEN, "物品也立即換")
ns.setLang(nil)
H.eq(ns.Names.item(LINEN), "G" .. LINEN, "切回跟隨遊戲")
