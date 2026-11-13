-- 物品／法術分頁的資料（DbIndex）：分類、篩選、搜尋、排序、職業技能與 Skills.list 一致
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local known = { [133] = true }
local ns_names
local requested = {}
local function boot(opts)
  opts = opts or {}
  H.reset({ locale = opts.locale or "zhTW", extra = {
    UnitClass = function() return "法師", "MAGE", 8 end,
    UnitLevel = function() return 18 end,
    IsSpellKnown = function(id) return known[id] == true end,
    C_Spell = { GetSpellName = function(id) return "法術" .. id end, GetSpellTexture = function() return 1 end,
                GetSpellSubtext = function() return "等級 1" end },
    C_Timer = { After = function() end },
    C_Item = { GetItemNameByID = function(id) if opts.noNames then return nil end return ns_names(id) end,
               RequestLoadItemDataByID = function(id) requested[id] = true end },
    C_CurrencyInfo = { GetCoinTextureString = function(c) return "coin" .. c end },
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } },
    hooksecurefunc = function() end,
    GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end, Hide = function() end },
  } })
  local ns = H.load(files)
  ns_names = function(id) return ns.Data.itemNames[id] end
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end

local ns = boot()
local D = ns.DbIndex
H.check(D ~= nil, "DbIndex 存在")

-- ---------- 物品 ----------
-- 全部物品＝專業物品 ∪ 永恆全部物品（Items.lua）
local union, total = {}, 0
for id in pairs(ns.Data.items) do union[id] = true end
for id in pairs(D.allItems()) do union[id] = true end
for _ in pairs(union) do total = total + 1 end
H.check(total > 16000, "聯集超過 1.6 萬，已略過內部物品（" .. total .. "）")
H.eq(#D.items({ kind = "all" }).list, total, "全部物品＝聯集數")
local thunder = D.allItems()[19019]
H.check(thunder and thunder.q == 5 and thunder.c == 2, "雷霆之怒：傳說、武器")
local weapons = D.items({ kind = "all", cls = 2 }).list
local allWeapons = #weapons > 100
for _, id in ipairs(weapons) do if D.itemInfo(id).c ~= 2 then allWeapons = false end end
H.check(allWeapons, "類別篩選只有武器（" .. #weapons .. "）")
requested = {}
local hit = D.items({ kind = "all" }, "雷霆之怒").list
local found19019 = false
for _, id in ipairs(hit) do if id == 19019 then found19019 = true end end
H.check(found19019, "繁中搜尋找得到非專業物品")
H.eq(next(requested), nil, "繁中搜尋不向伺服器請求物品資料")
H.check(D.itemSummary(19019):find("武器", 1, true) and D.itemSummary(19019):find("劍", 1, true),
  "非專業物品摘要含類別與子類別（" .. D.itemSummary(19019) .. "）")
H.eq(ns.Window.itemColor(19019), ns.Window.QUALITY[5], "全部物品的品質用在顏色上")

local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end
H.eq(D.itemInfo(2589).isMat, true, "亞麻布是材料")
H.check(has(D.items({ kind = "mat" }).list, 2589), "材料篩選有亞麻布")
H.check(D.itemSummary(2589):find("用於 12 條配方", 1, true) ~= nil, "亞麻布摘要：用於 12 條配方（" .. D.itemSummary(2589) .. "）")

local both, productOnly
for id in pairs(ns.Data.items) do
  local i = D.itemInfo(id)
  if i.isMat and i.isProduct and not both then both = id end
  if i.isProduct and not i.isMat and not productOnly then productOnly = id end
end
H.check(both ~= nil, "有同時是材料與成品的物品")
H.check(has(D.items({ kind = "mat" }).list, both) and has(D.items({ kind = "product" }).list, both), "材料與成品兩邊都列")
H.check(D.itemSummary(both):find("，可製作", 1, true) ~= nil, "兩者皆是：摘要兩段（" .. D.itemSummary(both) .. "）")
-- 負控制：只當成品的物品不在材料篩選
H.check(not has(D.items({ kind = "mat" }).list, productOnly), "只當成品的物品不在材料篩選")

local tl = D.items({ kind = "all", prof = 197 }).list
local allTailor = #tl > 0
for _, id in ipairs(tl) do if not D.itemInfo(id).profs[197] then allTailor = false end end
H.check(allTailor, "裁縫篩選只列裁縫相關物品（" .. #tl .. "）")

-- 使用者 2026-11-13：排序用物品等級，由高到低（同等級品質高的在前，再依 id；沒有物品等級的排最後）
local all = D.items({ kind = "all" }).list
local sorted = true
local function key(id) local i = D.itemInfo(id) return i.il or -1, D.quality(id) or -1 end
for i = 2, #all do
  local la, qa = key(all[i - 1])
  local lb, qb = key(all[i])
  if la < lb or (la == lb and (qa < qb or (qa == qb and all[i - 1] > all[i]))) then sorted = false end
end
H.check(sorted, "排序：物品等級高→低、同等級品質高→低、再依 id")
H.check((D.itemInfo(all[1]).il or 0) > 60, "第一筆是高等級物品（" .. tostring(D.itemInfo(all[1]).il) .. "）")

H.check(has(D.items({ kind = "all" }, "亞麻布").list, 2589), "搜尋物品名")
H.eq(D.items({ kind = "all" }, "亞麻布").loading, false, "有名稱時不標載入中")

-- 沒有打包名稱的語系（德文等）：名稱未載入時標載入中
ns = boot({ locale = "deDE", noNames = true })
requested = {}
H.eq(ns.DbIndex.items({ kind = "all" }, "x").loading, true, "名稱未載入時標載入中")
H.eq(requested[19019], nil, "其他語系：非專業物品不發請求（不能一次發 1.8 萬個）")
local nameCalls = 0
C_Item.GetItemNameByID = function() nameCalls = nameCalls + 1 return nil end
local profWeapons = 0
for _, id in ipairs(ns.DbIndex.items({ kind = "all", cls = 2 }).list) do
  if ns.DbIndex.itemInfo(id).total > 0 then profWeapons = profWeapons + 1 end
end
nameCalls = 0
ns.DbIndex.items({ kind = "all", cls = 2 }, "x")
H.eq(nameCalls, profWeapons, "其他語系：只對專業物品查名稱，非專業物品不呼叫 GetItemNameByID（可能觸發請求）")
H.check(requested[2589], "其他語系：專業物品照舊請求名稱")

-- ---------- 法術 ----------
ns = boot()
D = ns.DbIndex
local mage = D.spells({ kind = "class", classId = 8 }).list
local opts = { own = true, level = 18, isKnown = function(id) return known[id] == true end }
local ref = ns.Skills.list(8, opts)
local refN, refStatus = 0, {}
for _, g in ipairs(ref.groups) do for _, r in ipairs(g.rows) do refN = refN + 1; refStatus[r.spell] = r.status end end
H.eq(#mage, refN, "法師職業技能數＝職業技能分頁")
local allMage, sameStatus = true, true
for _, e in ipairs(mage) do
  if e.classId ~= 8 then allMage = false end
  if e.status ~= refStatus[e.spell] then sameStatus = false end
end
H.check(allMage, "職業篩選只列法師")
H.check(sameStatus, "自己職業的狀態與職業技能分頁一致")

-- 負控制：戰士清單沒有法師的技能，且不判斷狀態
local war = D.spells({ kind = "class", classId = 1 }).list
local noMage, noStatus = #war > 0, true
for _, e in ipairs(war) do
  if e.classId ~= 1 then noMage = false end
  if e.status ~= nil then noStatus = false end
end
H.check(noMage, "戰士篩選不出現別的職業")
H.check(noStatus, "別的職業不判斷學習狀態")

-- 訓練師快取補進來的技能、快取的等級
SkillsItemsGuideDB = { trainer = { class = { ["8"] = { spells = { ["999999"] = { lv = 20, cost = 100 } } } } } }
local found
for _, e in ipairs(D.spells({ kind = "class", classId = 8 }).list) do if e.spell == 999999 then found = e end end
H.check(found and found.lv == 20 and found.cost == 100, "訓練師快取補的技能出現在法術分頁，等級與學費用快取")
SkillsItemsGuideDB = nil

local rl = D.spells({ kind = "recipe", prof = 197 }).list
local okRecipe = #rl > 0
for _, e in ipairs(rl) do
  if not e.rid or ns.Data.recipes[e.rid].p ~= 197 or ns.Data.recipes[e.rid].spell ~= e.spell then okRecipe = false end
end
H.check(okRecipe, "配方篩選只列裁縫配方（" .. #rl .. "）")
local nRecipe = 0
for _, rec in pairs(ns.Data.recipes) do if rec.spell then nRecipe = nRecipe + 1 end end
H.eq(#D.spells({ kind = "recipe" }).list, nRecipe, "沒有法術的配方不進法術分頁")

-- 全部：職業技能在前、配方在後
local allS = D.spells({ kind = "all" }).list
H.check(allS[1].classId ~= nil and allS[#allS].rid ~= nil, "職業技能在前、配方在後")

local withSup
for _, e in ipairs(D.spells({ kind = "class" }).list) do if e.sup then withSup = e break end end
H.check(withSup and D.spellSummary(withSup):find("取代", 1, true) ~= nil, "有取代關係的摘要含「取代」")
H.check(D.spellSummary(mage[1]):find("職業技能", 1, true) == 1, "職業技能摘要開頭")
H.check(D.spellSummary(rl[1]):find("專業配方", 1, true) == 1, "配方摘要開頭")

H.check(#D.spells({ kind = "all" }, "法術133").list >= 1, "搜尋法術名")

-- review：Lua 解碼器直接驗（半形逗號在名稱裡、欄位全空、36 進位多位數）
ns = boot()
ns.Data.allItems = { rows = "z,4,2,7,1k,甲,乙, 丙\n1,,,,,只有名稱\n" }
local A = ns.DbIndex.allItems()
H.eq(A[35] and A[35].name, "甲,乙, 丙", "名稱含半形逗號")
H.eq(A[35].q, 4, "品質")
H.eq(A[35].c, 2, "類別")
H.eq(A[35].s, 7, "子類別")
H.eq(A[35].il, 56, "物品等級（36 進位 1k）")
H.check(A[36] and A[36].name == "只有名稱" and A[36].q == nil and A[36].c == nil and A[36].il == nil, "欄位全空")

-- 英文客戶端：類別名稱跟遊戲要當地語言（打包的是中文），拿不到才用打包的
ns = boot({ locale = "enUS" })
C_Item.GetItemClassInfo = function(c) if c == 2 then return "Weapon" end end
C_Item.GetItemSubClassInfo = function(c, s) if c == 2 and s == 7 then return "One-Handed Swords" end end
local cn, sn = ns.DbIndex.className(2, 7)
H.eq(cn, "Weapon", "英文客戶端類別名用遊戲的")
H.eq(sn, "One-Handed Swords", "英文客戶端子類別名用遊戲的")
local cn2 = ns.DbIndex.className(4)
H.eq(cn2, ns.Data.itemClasses[4].name, "遊戲拿不到時用打包的")

-- 英文客戶端（使用者 2026-11-13 選 B）：打包英文名稱，非專業物品也搜得到、不發請求
ns = boot({ locale = "enUS", noNames = true })
requested = {}
local hitEn = ns.DbIndex.items({ kind = "all" }, "Thunderfury").list
local fEn = false
for _, id in ipairs(hitEn) do if id == 19019 then fEn = true end end
H.check(fEn, "英文客戶端搜英文名找得到非專業物品")
H.eq(requested[19019], nil, "英文搜尋不向伺服器請求")
H.eq(ns.DbIndex.allItems()[19019].en, "Thunderfury, Blessed Blade of the Windseeker", "英文名稱解碼")
H.eq(ns.DbIndex.displayName(19019), "Thunderfury, Blessed Blade of the Windseeker", "遊戲名稱未載入時顯示打包英文名")
-- 專業分頁也受惠：英文客戶端名稱還沒載入時，Names.item 退回打包英文名（不再顯示 Item #id）
H.eq(ns.Names.item(2589), "Linen Cloth", "英文客戶端 Names.item 退回打包英文名")
