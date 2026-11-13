-- 物品／法術分頁畫面：清單上限、篩選與搜尋、明細、跳轉與返回（狀態保留）
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local ns
H.reset({ locale = "zhTW", extra = {
  UnitClass = function() return "法師", "MAGE", 8 end,
  UnitLevel = function() return 18 end,
  IsSpellKnown = function() return false end,
  C_Spell = { GetSpellName = function(id) return "法術" .. id end, GetSpellTexture = function() return 1 end,
              GetSpellSubtext = function() return "" end },
  C_Item = { GetItemNameByID = function(id) return ns.Data.itemNames[id] end, RequestLoadItemDataByID = function() end,
             GetItemIconByID = function() return 1 end,
             GetItemQualityByID = function(id) if id == 273908 then return 4 end end },
  C_CurrencyInfo = { GetCoinTextureString = function(c) return "coin" .. c end },
  RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } },
  hooksecurefunc = function() end,
  GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
                  Hide = function() end, SetItemByID = function() end, SetSpellByID = function() end },
} })
ns = H.load(files)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("PLAYER_LOGIN")
local T = ns.DbTab
H.check(T ~= nil, "DbTab 存在")

-- ---------- 物品 ----------
local ok, err = pcall(ns.Window.open, { tab = "item" })
H.check(ok, "開物品分頁不報錯：" .. tostring(err))
H.eq(ns.Window.state().tab, "item", "在物品分頁")
local st = T.itemState()
H.check(st.rendered <= 100, "一次最多畫 100 列")
H.eq(st.overflow, #st.list - st.rendered, "超過的筆數")
H.check(st.footer ~= nil, "超過上限時有提示")

T.setItemFilter({ kind = "mat" })
local allMat = true
for _, id in ipairs(T.itemState().list) do if not ns.DbIndex.itemInfo(id).isMat then allMat = false end end
H.check(allMat, "材料篩選")
T.setItemSearch("亞麻布")
local found = false
for _, id in ipairs(T.itemState().list) do if id == 2589 then found = true end end
H.check(found, "搜尋亞麻布")

T.openItem(2589)
st = T.itemState()
H.eq(st.detail, 2589, "開明細")
H.eq(st.usedCount, #ns.Index.usedBy(2589), "明細列出全部用到它的配方")
H.eq(st.madeCount, #ns.Index.madeBy(2589), "明細列出全部做它的配方")

-- 跳到專業分頁再返回：明細、搜尋、篩選都還在
local rid = ns.Index.usedBy(2589)[1]
T.openRecipe(rid)
H.eq(ns.Window.state().tab, "prof", "跳到專業分頁")
H.eq(ns.Window.state().list[1], rid, "專業分頁只有那一條配方")
H.eq(ns.Window.state().from, "item", "可以返回物品分頁")
ns.Window.setTab("item")
st = T.itemState()
H.eq(st.detail, 2589, "返回後明細還在")
H.eq(st.search, "亞麻布", "返回後搜尋還在")
H.eq(st.filter.kind, "mat", "返回後篩選還在")
-- 關掉視窗再用 /sig 開：專業分頁，但物品分頁狀態保留
ns.Window.open({})
ns.Window.setTab("item")
H.eq(T.itemState().detail, 2589, "重新開視窗後物品分頁狀態保留")

T.backToList()
T.itemState().ui.scroll:SetVerticalScroll(120)
T.openItem(2589)
H.eq(T.itemState().ui.scroll:GetVerticalScroll(), 0, "明細從頂端開始")
T.backToList()
H.eq(T.itemState().ui.scroll:GetVerticalScroll(), 120, "回清單時還原捲動位置")
st = T.itemState()
H.eq(st.detail, nil, "回清單")
H.check(#st.list >= 1 and #st.list < 50, "清單仍套用篩選與搜尋（" .. #st.list .. "）")

-- ---------- 法術 ----------
ok, err = pcall(ns.Window.setTab, "spell")
H.check(ok, "開法術分頁不報錯：" .. tostring(err))
st = T.spellState()
H.check(st.rendered <= 100 and st.rendered > 0, "法術清單有列且不超過 100")
T.setSpellFilter({ kind = "class", classId = 1 })
local allWar = #T.spellState().list > 0
for _, e in ipairs(T.spellState().list) do if e.classId ~= 1 then allWar = false end end
H.check(allWar, "職業篩選只有戰士")

local war = T.spellState().list[1]
T.activateSpell(war)
H.eq(ns.Window.state().tab, "skill", "職業技能 → 職業技能分頁")
H.eq(ns.SkillTab.state().classId, 1, "選到戰士")
H.eq(ns.SkillTab.state().focusSpell, war.spell, "標亮那個法術")

ns.Window.setTab("spell")
T.setSpellFilter({ kind = "recipe", prof = 197 })
local e = T.spellState().list[1]
T.activateSpell(e)
H.eq(ns.Window.state().tab, "prof", "配方法術 → 專業分頁")
H.eq(ns.Window.state().list[1], e.rid, "專業分頁只有那一條配方")
H.eq(ns.Window.state().from, "spell", "可以返回法術分頁")

-- 實測：永恆新物品（打包資料沒有品質，例：正義護腿）顯示白色、tooltip 是紫色 → 打包沒有就問遊戲
H.eq(next(ns.Data.items[273908]), nil, "正義護腿的打包資料沒有品質（前提）")
H.eq(ns.Window.itemColor(273908), ns.Window.QUALITY[4], "打包沒有品質時用遊戲回報的品質")
H.eq(ns.Window.itemColor(12811), ns.Window.QUALITY[ns.Data.items[12811].q], "打包有品質時用打包的")
H.eq(ns.Window.itemColor(424242), ns.Window.QUALITY[1], "都沒有時白色")
local prid = ns.Index.madeBy(273908)[1]
H.eq(ns.Window.recipeColor(prid), ns.Window.QUALITY[4], "專業分頁的配方名稱也用同一個品質來源")

-- 全部物品：類別篩選（下拉）與非專業物品的明細
ns.Window.setTab("item")
T.setItemSearch("")
T.setItemFilter({ kind = "all" })
T.setItemClass(2)
local wOK = #T.itemState().list > 100
for _, id in ipairs(T.itemState().list) do if ns.DbIndex.itemInfo(id).c ~= 2 then wOK = false end end
H.check(wOK, "類別下拉：只列武器")
H.check(T.itemState().header:find("武器", 1, true) ~= nil, "標題帶類別名（" .. T.itemState().header .. "）")
T.setItemFilter({ kind = "mat" })
H.eq(T.itemState().filter.cls, 2, "換左側篩選時保留類別")
T.setItemClass(nil)
H.eq(T.itemState().filter.cls, nil, "類別回到全部")
-- 使用者 2026-11-13：跟配方無關的物品展開沒意義 → 點了不開明細（只看 tooltip）
T.activate({ item = 19019 })
H.eq(T.itemState().detail, nil, "無關配方的物品點了不展開")
T.openItem(19019)
H.eq(T.itemState().detail, nil, "openItem 也不展開無關配方的物品")
T.activate({ item = 2589 })
H.eq(T.itemState().detail, 2589, "配方材料照樣展開")
T.backToList()
-- 非專業物品在遊戲名稱還沒載入時，繁中用打包名稱（不是「物品 #id」）
T.setItemFilter({ kind = "all" })
T.setItemSearch("雷霆之怒")
local rowName
for _, r in ipairs(T.itemState().rows) do if r._shown and r.entry and r.entry.item == 19019 then rowName = r.name._text end end
H.eq(rowName, ns.DbIndex.allItems()[19019].name, "列名稱用打包名稱")
T.setItemSearch("")

-- 實測：物品不能直接試穿（Ctrl+點），只能貼出來再點 → 修飾鍵點擊交給遊戲的 HandleModifiedItemClick（Shift 貼連結、Ctrl 試穿）
-- review：有按修飾鍵就一律吃掉這次點擊（不看遊戲回傳值；物品未快取時也不穿透成打開明細／跳頁）
local handled = {}
local ctrl, shift = false, false
HandleModifiedItemClick = function(link) handled[#handled + 1] = link; return nil end -- 回 nil 也要算處理過
IsControlKeyDown = function() return ctrl end
IsShiftKeyDown = function() return shift end
local cached = true
C_Item.GetItemInfo = function(id) if not cached then return nil end return "n", "|cffa335ee|Hitem:" .. id .. "::::::::|h[n]|h|r" end
ctrl = true
T.activate({ item = 2589 })
H.eq(#handled, 1, "Ctrl+點物品交給遊戲處理（試穿）")
H.check(handled[1]:find("Hitem:2589", 1, true) ~= nil, "傳的是該物品的連結")
H.check(T.itemState().detail ~= 2589, "遊戲回 nil 也不開明細")
cached = false
T.activate({ item = 2589 })
H.eq(#handled, 1, "物品未快取：不呼叫遊戲（沒有連結）")
H.check(T.itemState().detail ~= 2589, "物品未快取：也不穿透成打開明細")
cached, ctrl = true, false
T.activate({ item = 2589 })
H.eq(T.itemState().detail, 2589, "沒按修飾鍵就開明細")
T.backToList()
shift = true
ns.Window.open({})
handled = {}
T.activate({ rid = ns.Index.madeBy(273908)[1] })
H.check(handled[1] and handled[1]:find("Hitem:273908", 1, true), "配方列 Shift+點：貼的是成品")
H.eq(ns.Window.state().recipe, nil, "按修飾鍵不跳專業分頁")
shift = false
HandleModifiedItemClick, IsControlKeyDown = nil, nil

-- 品質篩選（下拉）：跟類別、左側篩選同時作用；打包沒有品質的物品用遊戲回報的品質
ns.Window.setTab("item")
T.setItemFilter({ kind = "all" })
T.setItemSearch("")
T.setItemClass(nil)
T.setItemQuality(4)
local epicOK, has273908 = #T.itemState().list > 100, false
for _, id in ipairs(T.itemState().list) do
  if ns.Window.itemQuality(id) ~= 4 then epicOK = false end
  if id == 273908 then has273908 = true end
end
H.check(epicOK, "品質篩選只列史詩（" .. #T.itemState().list .. "）")
H.check(has273908, "打包沒有品質、遊戲回報史詩的物品也在")
T.setItemClass(2)
for _, id in ipairs(T.itemState().list) do
  if ns.Window.itemQuality(id) ~= 4 or ns.DbIndex.itemInfo(id).c ~= 2 then epicOK = false end
end
H.check(epicOK and #T.itemState().list > 0, "品質＋類別同時作用")
H.check(T.itemState().header:find("史詩", 1, true) ~= nil, "標題帶品質名（" .. T.itemState().header .. "）")
T.setItemFilter({ kind = "all" })
H.eq(T.itemState().filter.q, 4, "換左側篩選時保留品質")
T.setItemQuality(nil); T.setItemClass(nil)

-- 使用者 2026-11-13：明細頁保留物品圖示與遊戲 tooltip（Ctrl／Shift+點也照遊戲）
T.setItemFilter({ kind = "all" })
T.openItem(2589)
local hb = T.itemState().ui.headBtn
H.check(hb and hb._shown, "明細標題有物品圖示")
H.eq(hb.itemId, 2589, "圖示對應該物品")
local tipItem
GameTooltip.SetItemByID = function(_, id) tipItem = id end
hb._scripts.OnEnter(hb)
H.eq(tipItem, 2589, "滑鼠移到圖示顯示遊戲 tooltip")
T.backToList()
H.check(not hb._shown, "清單模式不顯示標題圖示")

-- 暴雪 API 條款第 2 條第 13 款：清楚標明暴雪是資料來源（使用者 2026-11-13 要求物品標來源）
H.check(ns.Window.footerText():find("Blizzard API", 1, true) ~= nil, "視窗底部標資料來源 Blizzard API")
local src = T.itemState().ui.source and T.itemState().ui.source._text or ""
H.check(src:find("Blizzard API", 1, true) and src:find(ns.Data.meta.itemsVersion, 1, true) and src:find(ns.Data.meta.itemsGenerated, 1, true),
  "物品分頁標資料來源、版本、匯出日期（" .. src .. "）")

-- 實測（2026-11-13）：聖騎士 190 個法術只看得到前 100 個、又沒有其他篩選 → 清單最後「顯示更多」每次多 100 筆
ns.Window.setTab("spell")
T.setSpellSearch("")
T.setSpellFilter({ kind = "class", classId = 2 })
local ps = T.spellState()
H.check(#ps.list > 100, "聖騎士超過 100 筆（" .. #ps.list .. "）")
H.eq(ps.rendered, 100, "一開始畫 100 筆")
H.check(ps.ui.more._shown, "有「顯示更多」按鈕")
ps.ui.more._scripts.OnClick(ps.ui.more)
H.eq(ps.rendered, math.min(200, #ps.list), "按一次多 100 筆")
H.eq(ps.overflow, #ps.list - ps.rendered, "剩下的筆數")
if ps.overflow == 0 then H.check(not ps.ui.more._shown, "全部顯示後按鈕隱藏") end
T.setSpellFilter({ kind = "class", classId = 1 })
H.eq(T.spellState().limit, 100, "換篩選後回到 100 筆")

H.check(T.spellState().ui.source._text:find(ns.Data.meta.classBuild, 1, true) ~= nil, "法術分頁標客戶端資料版本（" .. T.spellState().ui.source._text .. "）")
