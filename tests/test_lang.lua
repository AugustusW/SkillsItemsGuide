-- 語言解析（spec 2026-11-27 語言切換）：ns.lang／ns.clientLang／ns.useBundled／ns.setLang／L.bind
local function boot(client, setting, projectId)
  H.reset({ locale = client, projectId = projectId })
  SkillsItemsGuideDB = setting ~= nil and { lang = setting } or nil
  return H.load({ "ErrorLog.lua", "Locale.lua", "Flavor.lua" })
end

-- 3 設定 × 3 客戶端
local CASES = {
  { "zhTW", nil, "zhTW", false }, { "zhTW", "zhTW", "zhTW", false }, { "zhTW", "enUS", "enUS", true },
  { "enUS", nil, "enUS", false }, { "enUS", "zhTW", "zhTW", true }, { "enUS", "enUS", "enUS", false },
  { "deDE", nil, "enUS", false }, { "deDE", "zhTW", "zhTW", true }, { "deDE", "enUS", "enUS", true },
}
for _, c in ipairs(CASES) do
  local ns = boot(c[1], c[2])
  local tag = c[1] .. "＋" .. tostring(c[2])
  H.eq(ns.lang(), c[3], "lang " .. tag)
  H.eq(ns.useBundled(), c[4], "useBundled " .. tag)
end

local ns = boot("deDE", nil)
H.eq(ns.clientLang(), nil, "德文客戶端沒有對應語言")
ns = boot("enGB", "enUS")
H.eq(ns.clientLang(), "enUS", "enGB 對應 enUS")
H.eq(ns.useBundled(), false, "enGB＋設定 enUS 不用打包名稱")

-- 手動改壞的存檔當成跟隨遊戲
for _, bad in ipairs({ "frFR", 5, true }) do
  ns = boot("enUS", bad)
  H.eq(ns.lang(), "enUS", "非法設定 " .. tostring(bad) .. " 當成跟隨遊戲")
  H.eq(ns.useBundled(), false, "非法設定 " .. tostring(bad) .. " 不用打包名稱")
end
ns = boot("enUS", nil)
SkillsItemsGuideDB = "壞掉"
H.eq(ns.lang(), "enUS", "存檔不是表格也不報錯")

-- 正式服：設定無效
ns = boot("enUS", "zhTW", 1)
H.eq(ns.lang(), "enUS", "正式服一律客戶端語言")
H.eq(ns.useBundled(), false, "正式服不用打包名稱")

-- setLang：只有語言真的變了才通知；回呼出錯不影響後面的
ns = boot("zhTW", nil)
local calls, after = 0, 0
table.insert(ns.onLangChanged, function() calls = calls + 1 end)
table.insert(ns.onLangChanged, function() error("回呼壞掉") end)
table.insert(ns.onLangChanged, function() after = after + 1 end)
ns.setLang("zhTW")
H.eq(calls, 0, "設成與目前相同的語言不通知")
H.eq(SkillsItemsGuideDB and SkillsItemsGuideDB.lang, "zhTW", "仍寫入設定")
ns.setLang("enUS")
H.eq(calls, 1, "語言變了通知一次")
H.eq(after, 1, "前一個回呼出錯，後面的仍執行")
H.eq(ns.lang(), "enUS", "切換後 lang 是 enUS")
ns.setLang(nil)
H.eq(ns.lang(), "zhTW", "設回跟隨遊戲")
H.eq(SkillsItemsGuideDB.lang, nil, "跟隨遊戲時設定清空")
ns.setLang("frFR")
H.eq(SkillsItemsGuideDB.lang, nil, "非法值不寫入")

-- L 與 L.bind 跟著顯示語言
ns = boot("zhTW", nil)
local L = ns.L
local fs = H.widget("FontString")
L.bind(fs, "TAB_PROF")
H.eq(fs._text, ns.LOCALES.zhTW.TAB_PROF, "bind 立即設定文字")
local fs2 = H.widget("FontString")
L.bind(fs2, function() return L.prof(164) end)
H.eq(fs2._text, "鍛造", "bind 函式立即設定")
ns.setLang("enUS")
H.eq(fs._text, "Professions", "切換後重套 key")
H.eq(fs2._text, "Blacksmithing", "切換後重套函式")
H.eq(L.class(1), "Warrior", "職業名稱跟著顯示語言")
H.eq(L.TAB_PROF, "Professions", "L 跟著顯示語言")
-- 某個登記出錯不影響其他
L.bind(H.widget("FontString"), function() return L.prof(164) end)
local bad = H.widget("FontString")
L.bind(bad, function() if ns.lang() == "zhTW" then error("壞掉") end return "x" end)
ns.setLang("zhTW")
H.eq(fs._text, ns.LOCALES.zhTW.TAB_PROF, "某個登記出錯，其他照常重套")

-- 非中英客戶端：跟隨遊戲（lang＝enUS、遊戲名稱）→ English（lang 仍 enUS、改用打包名稱）也要通知重畫（review Important 1）
ns = boot("deDE", nil)
local n = 0
table.insert(ns.onLangChanged, function() n = n + 1 end)
ns.setLang("enUS")
H.eq(n, 1, "deDE 跟隨遊戲 → English：名稱來源變了要通知")
ns.setLang(nil)
H.eq(n, 2, "deDE English → 跟隨遊戲：也要通知")
ns.setLang(nil)
H.eq(n, 2, "沒變就不通知")
