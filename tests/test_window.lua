local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local NAMES = { [2589] = "亞麻布", [2996] = "亞麻布卷", [5762] = "紅色亞麻包", [2321] = "細線", [2604] = "紅色染料" }
local cached = {}
local function boot(locale)
  H.reset({ locale = locale or "zhTW", extra = {
    C_Item = {
      GetItemNameByID = function(id) if cached[id] == false then return nil end return NAMES[id] or ("名" .. id) end,
      RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 134400 end,
      GetItemInfo = function(id) return NAMES[id], "|cff|Hitem:" .. id .. "|h[" .. tostring(NAMES[id]) .. "]|h|r" end,
    },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end, Hide = function() end },
    hooksecurefunc = function() end,
  } })
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end

local ns = boot()
H.check(ns.Window and type(ns.Window.open) == "function", "Window.open 存在")
local ok, err = pcall(ns.Window.open, { material = 2589 })
H.check(ok, "材料反查模式開啟不報錯：" .. tostring(err))
local st = ns.Window.state()
H.eq(st.header, "亞麻布：被 12 條配方使用", "反查模式標題")
H.eq(#st.list, 12, "清單只列用到它的配方")
H.eq(st.tab, "prof", "預設專業分頁")

ok, err = pcall(ns.Window.open, {})
H.check(ok, "不帶參數開啟不報錯：" .. tostring(err))
H.eq(ns.Window.state().material, nil, "不帶材料時不是反查模式")

-- 名稱未快取：繁中改用打包的官方名稱（0.1.1，使用者回報代碼與搜尋卡住）；英文的佔位與載入中見 test_names.lua
cached[2589] = false
ns.Window.open({ material = 2589 })
H.eq(ns.Window.state().header, ns.Data.itemNames[2589] .. "：被 12 條配方使用", "繁中名稱未快取時標題用打包的官方名稱")
ns.Window.setSearch("亞麻")
H.check(ns.Window.state().loading == false, "繁中有打包名稱時，搜尋不必等 client 載入")
cached[2589] = nil
H.fire("GET_ITEM_INFO_RECEIVED", 2589, true)
H.eq(ns.Window.state().header, "亞麻布：被 12 條配方使用", "名稱回來後刷新標題")

-- 搜尋：比對產物名與材料名
ns.Window.open({ prof = 197 })
ns.Window.setSearch("亞麻布卷")
local hasBag, hasBolt = false, false
for _, rid in ipairs(ns.Window.state().list) do
  if rid == 4019 then hasBag = true end
  if rid == 2359 then hasBolt = true end
end
H.check(hasBolt and hasBag, "搜尋同時比對產物（亞麻布卷）與材料（紅色亞麻包用到亞麻布卷）")
ns.Window.setSearch("不存在的東西zzz")
H.eq(#ns.Window.state().list, 0, "搜尋無結果")
H.check(type(ns.Window.state().empty) == "string", "搜尋無結果有空狀態文字")

-- 使用者實測：選取與「貼到對話框」多餘（習慣 Shift+點圖示貼連結），整個拿掉
H.eq(ns.Window.pasteText, nil, "沒有貼到對話框功能")
H.eq(ns.Window.paste, nil, "沒有貼到對話框按鈕的處理")

-- 數量
H.eq(ns.Window.clampQty("0"), 1, "數量 0 改成 1")
H.eq(ns.Window.clampQty("abc"), 1, "非數字改成 1")
H.eq(ns.Window.clampQty("5000"), 999, "超過上限夾到 999")
H.eq(ns.Window.clampQty("12"), 12, "正常值保留")

-- 視窗關閉時釋放所有文字框焦點
ns.Window.open({})
SkillsItemsGuideFrame:Hide()
H.check(H.focus == nil, "關閉視窗後沒有文字框持有焦點")

-- 審查 #2 #8 #15 #7：效能與名稱載入
local timers = {}
local requests = {}
local refreshes = 0
H.reset({ locale = "zhTW", extra = {
  C_Item = {
    GetItemNameByID = function(id) return NAMES[id] end,
    RequestLoadItemDataByID = function(id) requests[id] = (requests[id] or 0) + 1 end,
    GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end,
  },
  C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
  C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
  GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
    Hide = function() end, IsShown = function() return true end, RefreshData = function() refreshes = refreshes + 1 end },
  hooksecurefunc = function() end,
} })
ns = H.load(files)
SkillsItemsGuideCharDB = { professions = { ["197"] = true, ["129"] = true } }
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("PLAYER_LOGIN")
local computes = 0
local orig = ns.Window.recompute
ns.Window.recompute = function(...) computes = computes + 1 return orig(...) end
ns.Window.open({})
H.eq(ns.Window.state().prof, 129, "沒指定時預設開自己學的第一個專業（不是全部 2493 條）")
H.eq(computes, 1, "開視窗只重算一次")
ns.Window.setProf(nil)
H.check(#ns.Window.state().list > 100 and ns.Window.state().rendered <= 100, "清單超過 100 條時只畫前 100 條")
H.check(ns.Window.state().overflow == #ns.Window.state().list - ns.Window.state().rendered, "記下沒畫出來的條數")
computes = 0
timers = {}
for i = 1, 50 do H.fire("GET_ITEM_INFO_RECEIVED", 1000 + i, true) end
H.eq(computes, 0, "物品資料回來時不立刻重算")
H.check(#timers >= 1, "排一次延後刷新")
for _, fn in ipairs(timers) do fn() end
H.eq(computes, 1, "50 個事件合併成一次重算")
H.check(refreshes >= 1, "顯示中的 tooltip 也刷新")
requests = {}
ns.Names.item(424242); ns.Names.item(424242); ns.Names.item(424242)
H.eq(requests[424242], 1, "同一個物品只請求載入一次")

-- 實測：「還有 N 條」蓋在第一列上、未開專業的提示超出視窗 → 各自獨立放
SkillsItemsGuideCharDB = { professions = { ["197"] = true, ["129"] = true }, opened = { ["197"] = true } }
ns.Window.open({})
ns.Window.setProf(nil)
local st2 = ns.Window.state()
H.check(st2.footer and st2.footer:find(tostring(st2.overflow), 1, true), "超過上限的提示放在清單最後（footer），不放在空狀態位置")
H.eq(st2.empty, nil, "有結果時空狀態文字是空的")
H.eq(ns.Window.hintText(), "滑鼠移到圖示看拆解，點 + 展開", "第一行提示只放操作說明")
H.check(ns.Window.notOpenedText():find("急救", 1, true) ~= nil, "未開專業的提示獨立一行")

-- 使用者實測：文字超出視窗 → 材料行與展開的樹限寬換行，列高跟著文字高度
ns.Window.open({ material = 2321 })
local r1 = ns.Window._rows[1]
H.check(r1 and r1.mats._wrap == true and r1.mats._width ~= nil, "材料行限寬並自動換行")
local longRid
for _, rid in ipairs(ns.Window.state().list) do if #ns.Data.recipes[rid].r >= 4 then longRid = rid break end end
ns.Window.state().expanded[ns.Window.state().list[1]] = true
ns.Window.render()
local h = r1._height
H.check(h and h > 36 + r1.tree:GetStringHeight() - 1, "展開時列高包含樹的實際文字高度（" .. tostring(h) .. "）")

-- 使用者要求：視窗顯示版本、作者與回報信箱
H.check(ns.Window.footerText():find("support@augustusw.com", 1, true) ~= nil, "視窗底部有回報信箱")
H.check(ns.Window.footerText():find("AugustusW", 1, true) ~= nil, "視窗底部有作者")

-- 改名後長指令也要跟著改（/skillsitemsguide）
H.check(SLASH_SKILLSITEMSGUIDE1 == "/skillsitemsguide", "長指令是 /skillsitemsguide")

-- 分頁註冊表（物品／法術分頁）：職業技能分頁由 SkillTab 註冊；未註冊的分頁回到專業
ns.Window.open({})
H.check(ns.Window._ui().tabs and ns.Window._ui().tabs.skill ~= nil, "永恆有職業技能分頁按鈕（註冊表）")
ns.Window.setTab("nope")
H.eq(ns.Window.state().tab, "prof", "未註冊的分頁回到專業")

-- 單一配方模式（物品／法術分頁跳過來）：清單只有那一條、已展開，「清除」回該專業
local rid = ns.Index.madeBy(2996)[1]
ok, err = pcall(ns.Window.open, { recipe = rid, from = "item" })
H.check(ok, "單一配方模式開啟不報錯：" .. tostring(err))
st = ns.Window.state()
H.eq(st.tab, "prof", "單一配方模式在專業分頁")
H.eq(#st.list, 1, "清單只有一條")
H.eq(st.list[1], rid, "清單是指定的配方")
H.eq(st.expanded[rid], true, "預設展開")
H.check(st.header:find("配方：", 1, true) == 1, "標題「配方：<名稱>」（" .. tostring(st.header) .. "）")
H.eq(st.from, "item", "記住從哪個分頁來")
H.eq(st.prof, ns.Data.recipes[rid].p, "專業切到該配方的專業")
ns.Window.setSearch("不存在的字")
H.eq(ns.Window.state().recipe, nil, "在搜尋框打字就離開單一配方模式（review：原本打字沒反應）")
H.eq(#ns.Window.state().list, 0, "搜尋套用到該專業清單")
ns.Window.open({ recipe = rid, from = "item" })
ns.Window.setProf(st.prof)
st = ns.Window.state()
H.eq(st.recipe, nil, "清除後離開單一配方模式")
H.eq(st.from, nil, "清除後不再顯示返回")
ns.Window.setSearch("")
H.check(#ns.Window.state().list > 1, "清除後回到該專業清單")
ns.Window.open({ recipe = rid, from = "item" })
ns.Window.open({ material = 2589 })
H.eq(ns.Window.state().recipe, nil, "開材料反查時離開單一配方模式")
H.eq(ns.Window.state().from, nil, "開材料反查時清掉返回")

-- 配方列對外函式（物品明細共用）
SkillsItemsGuideCharDB = {}
H.eq(ns.Window.recipeLearned(rid), nil, "專業視窗沒開過：已學未知")
SkillsItemsGuideCharDB = { opened = { [tostring(ns.Data.recipes[rid].p)] = true }, known = {} }
H.eq(ns.Window.recipeLearned(rid), false, "開過、沒學")
H.check(type(ns.Window.recipeTitle(rid)) == "string", "配方標題")
H.check(type(ns.Window.recipeFirstLayer(rid)) == "string", "第一層材料")
H.check(ns.Window.recipeIcon(rid) ~= nil, "配方圖示")
H.check(type(ns.Window.recipeColor(rid)) == "table", "配方品質色")

-- review：返回後專業分頁不能還停在單一配方模式；自動展開的配方要收回
local rid2 = ns.Index.madeBy(2996)[1]
ns.Window.open({})
ns.Window.state().expanded[rid2] = nil
ns.Window.open({ recipe = rid2, from = "item" })
ns.Window.back()
H.eq(ns.Window.state().tab, "item", "返回原分頁")
H.eq(ns.Window.state().recipe, nil, "返回後離開單一配方模式")
H.eq(ns.Window.state().from, nil, "返回後清掉返回")
H.eq(ns.Window.state().expanded[rid2], nil, "跳轉自動展開的配方收回")
ns.Window.open({ recipe = rid2 })
ns.Window.setProf(ns.Window.state().prof)
H.eq(ns.Window.state().expanded[rid2], nil, "清除後自動展開的配方收回")
ns.Window.state().expanded[rid2] = true
ns.Window.open({ recipe = rid2 })
ns.Window.setProf(ns.Window.state().prof)
H.eq(ns.Window.state().expanded[rid2], true, "原本就展開的配方不收回")
ns.Window.state().expanded[rid2] = nil

-- review：離開專業分頁期間名稱載入回來，切回專業分頁要重算（否則一直卡在「載入中」）
local calls, orig = 0, ns.Window.recompute
ns.Window.recompute = function() calls = calls + 1 return orig() end
ns.Window.setTab("item")
ns.Window.setTab("prof")
H.check(calls >= 1, "切回專業分頁會重算")
ns.Window.recompute = orig

-- ---------- 取得方式標籤與技能顏色圓點（Task 4）----------
do
  local skill, faction = 100, "Alliance"
  local function bootSrc(locale, opts)
    opts = opts or {}
    H.reset({ locale = locale or "zhTW", extra = {
      C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
        GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
      C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
      GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end, Hide = function() end },
      hooksecurefunc = function() end,
      UnitFactionGroup = function() return faction end,
      GetProfessions = function() if opts.noProf then return nil end return 1 end,
      GetProfessionInfo = function() return "裁縫", 0, skill, 300, 0, 0, 197 end,
    } })
    local n = H.load(files)
    H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
    return n
  end
  local n = bootSrc()
  n.Data.meta.sourcesGenerated = "2026-11-22" -- 列在建立時依這個決定寬度與換行，要在第一次 open 前設好
  n.Window.open({ prof = 197 })
  local list = n.Window.state().list
  local sp = {}
  for i = 1, 5 do sp[i] = n.Data.recipes[list[i]].spell end
  local D = n.Data
  D.meta.sourcesGenerated = "2026-11-22"
  D.sources = {
    [sp[1]] = { src = "auto" },
    [sp[2]] = { src = "book", books = { { item = 900 } }, tr = { 10, 20, 30, 40 } },
    [sp[3]] = { src = "trainer", tr = { 10, 50, 150, 200 } },
    [sp[4]] = { src = "trainer", tr = { 90, 130, 140, 150 } },
    -- sp[5] 沒有資料
  }
  D.sourceNamesByLocale = { zhTW = { quest = {}, area = {}, faction = {} }, enUS = { quest = {}, area = {}, faction = {} } }
  n.Source.init()
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { [tostring(sp[3])] = { cost = 150 } } } } } }
  n.Window.render()
  local rows = n.Window._rows
  H.eq(rows[1].name._width, 470, "永恆名稱寬度縮為 470")
  H.eq(rows[1].name._wrap, false, "永恆名稱不換行")
  H.eq(rows[1].src.text, "自動學會", "自動學會標籤")
  H.eq(rows[1].src.color, n.Window.TAG_COLORS.auto, "自動學會灰白字")
  H.eq(rows[2].src.text, "配方", "配方標籤")
  H.eq(rows[2].src.color, n.Window.TAG_COLORS.book, "配方藍字")
  H.eq(rows[3].src.kind, "trainerOk", "快取有這個法術 → 訓練師確認")
  H.eq(rows[3].src.text, "訓練師", "訓練師標籤")
  H.eq(rows[3].src.color, n.Window.TAG_COLORS.trainerOk, "訓練師確認金字")
  H.eq(rows[4].src.kind, "trainer", "快取沒有 → 推定")
  H.eq(rows[4].src.color, n.Window.TAG_COLORS.trainer, "訓練師推定灰字")
  H.eq(rows[5].src, nil, "沒有資料的配方沒有標籤")
  H.check(rows[1].tag._shown and not rows[5].tag._shown, "有資料才顯示標籤")
  H.check(rows[3].tick._shown, "確認的訓練師顯示勾圖示")
  H.check(not rows[1].tick._shown and not rows[2].tick._shown and not rows[4].tick._shown, "只有確認的訓練師有勾圖示")
  -- 圓點：技能 100
  H.eq(rows[1].src.dot, nil, "沒有 tr 不顯示圓點")
  H.check(not rows[1].dot._shown, "沒有 tr 圓點隱藏")
  H.eq(rows[2].src.dot, "x", "技能 100 >= 灰起點 40 → 灰")
  H.eq(rows[3].src.dot, "y", "技能 100 介於黃 50 與綠 150 → 黃")
  H.eq(rows[4].src.dot, "o", "技能 100 < 黃 130 → 橘")
  H.eq(rows[4].dot._color[1], 1, "橘點色塊 R")
  H.eq(rows[4].dot._color[2], 0.5, "橘點色塊 G")
  H.eq(rows[4].dot._color[3], 0.25, "橘點色塊 B")
  H.check(rows[4].dot._shown, "有顏色就顯示圓點")
  skill = 160
  n.Window.render()
  H.eq(rows[3].src.dot, "g", "技能 160 → 綠")
  H.eq(rows[3].dot._color[2], 0.75, "綠點色塊 G")
  H.eq(rows[4].dot._color[1], 0.5, "灰點色塊 R")
  H.eq(rows[4].src.dot, "x", "技能 160 >= 150 → 灰")
  -- 沒學這個專業：沒有圓點，標籤仍在
  local n2 = bootSrc("zhTW", { noProf = true })
  n2.Data.meta.sourcesGenerated = "x"
  n2.Data.sources = { [sp[2]] = { src = "book", books = { { item = 900 } }, tr = { 10, 20, 30, 40 } } }
  n2.Window.open({ prof = 197 })
  local r2
  for _, r in ipairs(n2.Window._rows) do if r.rid and n2.Data.recipes[r.rid].spell == sp[2] and r._shown then r2 = r end end
  H.check(r2 and r2.src and r2.src.kind == "book", "沒學專業仍有標籤")
  H.eq(r2.src.dot, nil, "沒學這個專業 → 沒有圓點資訊")
  H.check(not r2.dot._shown, "沒學這個專業 → 圓點隱藏")
  -- 訓練師快取鍵格式
  local set = n.Window.trainerSpellSet
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["100"] = { cost = 5 }, ["200"] = { skill = 1 } } } } } }
  local ts = set(197)
  H.eq(ts[100], 5, "數字鍵：有學費用學費")
  H.eq(ts[200], true, "數字鍵：沒學費用 true")
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["100"] = {}, ["亞麻繃帶|1"] = {} } } } } }
  local partial = set(197)
  H.eq(partial and partial[100], true, "混有非數字鍵：數字鍵仍確認")
  local cnt = 0
  for _ in pairs(partial or {}) do cnt = cnt + 1 end
  H.eq(cnt, 1, "非數字鍵逐筆略過，不納入集合")
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["1x"] = {} } } } } }
  H.eq(set(197), nil, "全部都是非純數字字串 → 沒有可確認的 → nil")
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["100"] = { skill = 40, cost = 5 }, ["200"] = { skill = 0 }, ["x|1"] = { skill = 9 }, ["300"] = {} } } } } }
  local sk = n.Window.trainerSkillSet(197)
  H.eq(sk[100], 40, "訓練師快取 skill 欄 → 學會門檻")
  H.eq(sk[200], nil, "skill=0 視為未知")
  H.eq(sk[300], nil, "沒有 skill 欄 → 不收")
  H.eq(sk[0], nil, "非數字鍵略過")
  H.eq(n.Window.trainerSkillSet(171), nil, "沒有快取 → nil")
  SkillsItemsGuideDB = {}
  H.eq(set(197), nil, "沒有快取 → nil")
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["100"] = {} } } } } }
  H.eq(set(171), nil, "別的專業沒有快取 → nil")
  -- 非數字鍵：推定的訓練師不會變確認
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["名稱|1"] = {} } } } } }
  n.Window.render()
  H.eq(rows[3].src.kind, "trainer", "快取鍵全是非數字時清單不確認")
  H.check(not rows[3].tick._shown, "非數字鍵不顯示勾")
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { [tostring(sp[3])] = {}, ["名稱|1"] = {} } } } } }
  n.Window.render()
  H.eq(rows[3].src.kind, "trainerOk", "混有非數字鍵時，數字鍵那筆仍確認")
  -- 佔位資料（sourcesGenerated 為 nil）：永恆也維持舊寬度與換行、沒有標籤
  local np = bootSrc("zhTW")
  np.Data.meta.sourcesGenerated = nil -- 本來就是佔位；明寫以示意圖
  np.Window.open({ prof = 197 })
  H.eq(np.Window._rows[1].name._width, 600, "佔位資料：名稱維持 600 寬")
  H.check(np.Window._rows[1].name._wrap ~= false, "佔位資料：名稱維持換行")
  H.check(not np.Window._rows[1].tag._shown, "佔位資料：沒有標籤")
  -- 英文客戶端：標籤無 CJK
  local ne = bootSrc("enUS")
  ne.Data.meta.sourcesGenerated = "x"
  ne.Data.sources = { [sp[1]] = { src = "auto" }, [sp[2]] = { src = "book", books = { { item = 900 } } }, [sp[3]] = { src = "trainer" } }
  ne.Window.open({ prof = 197 })
  for i = 1, 3 do
    local t = ne.Window._rows[i].tag:GetText()
    H.check(t ~= "" and not t:find("[\228-\233][\128-\191][\128-\191]"), "英文標籤無 CJK：" .. t)
  end
  H.eq(ne.Window._rows[2].tag:GetText(), "Recipe", "英文配方標籤")
end
