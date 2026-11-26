-- Source.lua：配方取得方式的判定與 tooltip 行（純邏輯）
local FILES = { "Locale.lua", "Flavor.lua", "Data/Forever/Sources.lua", "Source.lua" }
local CJK = "[\228-\233][\128-\191][\128-\191]"

local function setup(locale, data)
  H.reset({ locale = locale })
  local ns = H.load(FILES)
  local D = ns.Data
  D.meta.sourcesGenerated = "2026-11-22"
  D.sources = data.sources or {}
  D.sourceQuestSide = data.questSide or {}
  D.sourceNamesByLocale = data.names or { zhTW = { quest = {}, area = {}, faction = {} }, enUS = { quest = {}, area = {}, faction = {} } }
  ns.Source.init()
  return ns, D
end
local function texts(lines) local t = {} for i, l in ipairs(lines) do t[i] = l.text end return t end
local function flagged(lines, flag) local n = 0 for _, l in ipairs(lines) do if l.flag == flag then n = n + 1 end end return n end
local function names(en) return { item = function(id) return (en and "Book" or "書") .. id end } end

local function NAMES_() return {
  zhTW = { quest = { [10] = "任務甲", [11] = "任務乙", [12] = "任務丙", [13] = "任務丁", [14] = "任務戊" },
           area = { [10] = "艾爾文森林", [12] = "鐵爐堡" }, faction = { [529] = "銀色黎明" } },
  enUS = { quest = { [10] = "Quest A", [11] = "Quest B" }, area = { [10] = "Elwynn Forest" }, faction = { [529] = "Argent Dawn" } },
} end

-- 沒有資料（佔位檔）
do
  H.reset({ locale = "zhTW" })
  local ns = H.load(FILES)
  H.eq(ns.Source.kind(100, { side = "A" }), nil, "佔位資料 kind 為 nil")
  H.eq(#ns.Source.lines(100, { side = "A" }), 0, "佔位資料 lines 為空")
  H.eq(ns.Source.color(100, 50), nil, "佔位資料 color 為 nil")
end

-- 種類判定
do
  local ns = setup("zhTW", { sources = {
    [1] = { src = "auto" }, [2] = { src = "trainer" }, [3] = { src = "book", books = { { item = 900 } } },
  } })
  local S = ns.Source
  H.eq(S.kind(1, { side = "A" }), "auto", "auto")
  H.eq(S.kind(2, { side = "A" }), "trainer", "訓練師推定")
  H.eq(S.kind(3, { side = "A" }), "book", "配方書")
  H.eq(S.kind(999, { side = "A" }), nil, "沒有資料的法術")
  H.eq(S.kind(2, { side = "A", trainerSpells = { [2] = true } }), "trainerOk", "訓練師確認")
  H.eq(S.kind(2, { side = "A", trainerSpells = { [5] = true } }), "trainer", "不在清單仍是推定")
  H.eq(S.kind(2, { side = "A", trainerSpells = nil }), "trainer", "trainerSpells=nil 不確認")
  H.eq(S.kind(3, { side = "A", trainerSpells = { [3] = true } }), "trainerOk", "書＋訓練師確認 → trainerOk")
  H.eq(S.kind(1, { side = "A", trainerSpells = { [1] = true } }), "auto", "自動學會不被訓練師覆蓋")
  H.eq(S.kind(3, nil), "book", "ctx 為 nil 不爆")
end

-- 書＋確認訓練師：先訓練師後書；學費
do
  local ns = setup("zhTW", { sources = { [3] = { src = "book", books = { { item = 900, skill = 150, lv = 20, bind = 1 } } } } })
  local lines = ns.Source.lines(3, { side = "A", names = names(), trainerSpells = { [3] = 12345 } })
  H.eq(lines[1].flag, "sourceTitle", "第一行是標題")
  H.eq(lines[1].text, "學會方式", "標題文字")
  H.check(lines[2].text:find("訓練師", 1, true) and lines[2].flag == "source" and lines[2].confirmed == true, "第二行確認的訓練師")
  H.check(lines[2].text:find("學費", 1, true), "有學費")
  H.check(lines[3].text == "配方：書900", "第三行才是配方書：" .. tostring(lines[3].text))
  H.eq(lines[3].item, 900, "配方書行帶 item id")
  H.eq(lines[4].flag, "sourceDetail", "條件行")
  H.check(lines[4].text:find("需要技能 150", 1, true) and lines[4].text:find("等級 20", 1, true) and lines[4].text:find("拾取後綁定", 1, true), "條件內容")
end

-- 推定訓練師有提示
do
  local ns = setup("zhTW", { sources = { [2] = { src = "trainer" } } })
  local lines = ns.Source.lines(2, { side = "A" })
  H.eq(lines[2].text, "訓練師（推定）", "推定標籤")
  H.eq(lines[2].confirmed, nil, "推定不是確認")
  H.eq(lines[3].flag, "sourceDetail", "推定提示行")
  H.check(lines[3].text:find("打開一次", 1, true), "提示內容")
end

-- 自動學會
do
  local ns = setup("zhTW", { sources = { [1] = { src = "auto", tr = { 1, 10, 20, 30 } } } })
  local lines = ns.Source.lines(1, { side = "A" })
  H.eq(lines[2].text, "學會專業時自動學會", "自動學會文字")
end

-- 雙陣營排序與 sideOther
do
  local ns = setup("zhTW", {
    sources = { [3] = { src = "book", books = {
      { item = 901, side = "H" }, { item = 902, side = "A" }, { item = 903 } } } },
    names = NAMES_() })
  local lines = ns.Source.lines(3, { side = "A", names = names() })
  local order = {}
  for _, l in ipairs(lines) do if l.item then order[#order + 1] = l.item end end
  H.eq(table.concat(order, ","), "902,903,901", "自己陣營與中立在前，另一陣營最後")
  for _, l in ipairs(lines) do
    if l.item == 901 then H.check(l.sideOther == true and l.text:find("[部落]", 1, true), "另一陣營 sideOther＋[部落]") end
    if l.item == 902 then H.check(not l.sideOther and l.text:find("[聯盟]", 1, true), "自己陣營有 [聯盟]") end
    if l.item == 903 then H.check(not l.sideOther and not l.text:find("[", 1, true), "中立無標籤") end
  end
  local h = ns.Source.lines(3, { side = "H", names = names() })
  local o2 = {}
  for _, l in ipairs(h) do if l.item then o2[#o2 + 1] = l.item end end
  H.eq(table.concat(o2, ","), "901,903,902", "部落視角")
  local none = ns.Source.lines(3, { names = names() })
  H.eq(flagged(none, "sideOther"), 0, "不知道自己陣營時不灰化")
end

-- 超過 3 本、3 個任務
do
  local books = {}
  for i = 1, 5 do books[i] = { item = 900 + i } end
  books[1].quests = { 10, 11, 12, 13, 14 }
  local ns = setup("zhTW", { sources = { [3] = { src = "book", books = books } }, names = NAMES_() })
  local lines = ns.Source.lines(3, { side = "A", names = names() })
  H.eq(flagged(lines, "sourceMore"), 2, "書與任務各一條「另有」")
  local t = table.concat(texts(lines), "\n")
  H.check(t:find("另有 2 個", 1, true), "書 5 本 → 另有 2 個")
  local q = 0
  for _, l in ipairs(lines) do if l.quest then q = q + 1 end end
  H.eq(q, 3, "任務最多 3 條")
  H.check(t:find("任務獎勵：任務甲（艾爾文森林）", 1, true), "任務名（地區）")
  local books3 = 0
  for _, l in ipairs(lines) do if l.item then books3 = books3 + 1 end end
  H.eq(books3, 3, "最多 3 本")
end

-- 任務：另一陣營的任務灰字；無名稱則看地區，都沒有就略過
do
  local ns = setup("zhTW", {
    sources = { [3] = { src = "book", books = { { item = 901, quests = { 10, 12, 99 } } } } },
    questSide = { [10] = "H" },
    names = { zhTW = { quest = { [10] = "任務甲" }, area = { [10] = "X", [12] = "鐵爐堡" }, faction = {} }, enUS = { quest = {}, area = {}, faction = {} } } })
  local lines = ns.Source.lines(3, { side = "A", names = names() })
  local found = {}
  for _, l in ipairs(lines) do if l.quest then found[l.quest] = l end end
  H.check(found[12] ~= nil, "無任務名但有地區：仍有一行")
  H.check(found[12].text:find("鐵爐堡", 1, true) ~= nil, "只顯示地區")
  H.check(found[12].text:find("任務獎勵：", 1, true) == nil, "沒有任務名就不帶「任務獎勵：」前綴")
  H.eq(found[99], nil, "名稱與地區都沒有：略過")
  H.check(found[10] and found[10].sideOther == true, "另一陣營任務 sideOther")
  H.eq(flagged(lines, "sourceMore"), 0, "略過的不算「另有」")
end

-- 英文：不出現 CJK，不顯示另一語系文字
do
  local ns = setup("enUS", {
    sources = { [3] = { src = "book", books = { { item = 901, skill = 100, bind = 2, fac = 529, rep = 5, side = "A", quests = { 10, 12 } } } },
                [2] = { src = "trainer" }, [1] = { src = "auto", tr = { 1, 2, 3, 4 } } },
    names = NAMES_() })
  -- 0.6.0 起兩種語言都保留（語言切換立即生效），顯示仍只用名稱語言那份（下面的 CJK 檢查）
  H.check(ns.Data.sourceNamesByLocale.zhTW ~= nil, "兩種語言名稱都保留，可以切換")
  for _, id in ipairs({ 1, 2, 3 }) do
    local lines = ns.Source.lines(id, { side = "A", names = names(true) })
    for _, l in ipairs(lines) do
      H.check(not l.text:find(CJK), "英文無 CJK：" .. l.text)
      for _, p in ipairs(l.parts or {}) do H.check(not p.text:find(CJK), "英文 parts 無 CJK") end
    end
  end
  local t = table.concat(texts(ns.Source.lines(3, { side = "A", names = names(true) })), "\n")
  H.check(t:find("Quest reward: Quest A (Elwynn Forest)", 1, true), "英文任務")
  H.check(t:find("Argent Dawn: Friendly", 1, true), "聲望名稱與等級（保底字串）")
  H.check(not t:find("鐵爐堡", 1, true) and not t:find("任務丙", 1, true), "不混入繁中")
  H.check(t:find("Binds when equipped", 1, true), "英文綁定")
end

-- 聲望等級用遊戲全域字串
do
  local ns = setup("enUS", { sources = { [3] = { src = "book", books = { { item = 901, fac = 529, rep = 6 } } } }, names = NAMES_() })
  _G.FACTION_STANDING_LABEL6 = "Honored!"
  local t = table.concat(texts(ns.Source.lines(3, { side = "A", names = names(true) })), "\n")
  _G.FACTION_STANDING_LABEL6 = nil
  H.check(t:find("Argent Dawn: Honored!", 1, true), "優先用 FACTION_STANDING_LABEL")
end

-- 非數字鍵的 trainerSpells（名稱|rank）不會讓 kind 變 trainerOk
do
  local ns = setup("zhTW", { sources = { [2] = { src = "trainer" } } })
  H.eq(ns.Source.kind(2, { side = "A", trainerSpells = { ["寒冰箭|等級 2"] = true } }), "trainer", "非數字鍵不確認")
end

-- 非 zhTW／enUS 客戶端：聲望等級跟著插件語系（英文），不用遊戲全域字串
do
  local ns = setup("deDE", { sources = { [3] = { src = "book", books = { { item = 901, fac = 529, rep = 6 } } } }, names = NAMES_() })
  _G.FACTION_STANDING_LABEL6 = "Geehrt"
  local t = table.concat(texts(ns.Source.lines(3, { side = "A", names = names(true) })), "\n")
  _G.FACTION_STANDING_LABEL6 = nil
  H.check(t:find("Argent Dawn: Honored", 1, true) and not t:find("Geehrt", 1, true), "deDE 用 L.REP_RANKS")
end

-- 技能點數區間與顏色
do
  local ns = setup("zhTW", { sources = { [1] = { src = "auto", tr = { 1, 30, 45, 60 } }, [2] = { src = "trainer" } } })
  local S = ns.Source
  H.eq(S.color(1, nil), nil, "沒學 → nil")
  H.eq(S.color(1, 10), "o", "橘")
  H.eq(S.color(1, 30), "y", "黃")
  H.eq(S.color(1, 44), "y", "黃（綠前）")
  H.eq(S.color(1, 45), "g", "綠")
  H.eq(S.color(1, 60), "x", "灰")
  H.eq(S.color(1, 1), "o", "橘邊界：skill == tr[1]")
  H.eq(S.color(1, 29), "o", "橘邊界：tr[2]-1")
  H.eq(S.color(1, 0), "o", "tr[1]<=1 = 門檻未知，不能說還學不了 → 橘")
  H.eq(S.color(2, 10), nil, "沒有 tr → nil")
  H.eq(S.color(999, 10), nil, "沒有資料 → nil")
  local lines = S.lines(1, { side = "A", profSkill = 50 })
  local title, range
  for _, l in ipairs(lines) do if l.flag == "skillRangeTitle" then title = l end if l.flag == "skillRange" then range = l end end
  H.eq(title and title.text, "技能點數", "技能點數標題")
  H.check(range and #range.parts == 4 and range.parts[1].color == "o" and range.parts[4].color == "x" and range.parts[3].text == "45", "四個數字各帶顏色")
  H.eq(range.current, nil, "skillRange 不再帶 current（顏色只由 Source.color 提供）")
  H.eq(S.lines(2, { side = "A" })[1].flag, "sourceTitle", "沒有 tr 時只有來源段")
  local none = S.lines(2, { side = "A" })
  H.eq(flagged(none, "skillRange"), 0, "沒有 tr 不輸出區間")
end

-- 學會門檻：tr[1]>1 為已知；<=1 先用訓練師快取，再不行就是未知
do
  local ns = setup("zhTW", { sources = {
    [1] = { src = "book", tr = { 50, 55, 57, 60 } },
    [2] = { src = "book", tr = { 1, 55, 57, 60 } },
    [3] = { src = "book", tr = { 0, 55, 57, 60 } } } })
  local S = ns.Source
  H.eq(S.color(1, 49), nil, "已知門檻 50，技能 49 → nil")
  H.eq(S.color(1, 50), "o", "已知門檻，技能到了 → 橘")
  local ctx = { trainerSkills = { [2] = 40, [3] = 0 } }
  H.eq(S.color(2, 39, ctx), nil, "tr[1]=1 改用訓練師快取 40：39 → nil")
  H.eq(S.color(2, 40, ctx), "o", "訓練師快取：40 → 橘")
  H.eq(S.color(2, 10), "o", "未知門檻、低於黃 → 橘")
  H.eq(S.color(3, 10, ctx), "o", "訓練師快取 skill=0 視為未知 → 橘")
  H.eq(S.color(3, 55), "y", "未知門檻、到黃 → 黃")
  local function range(spell, c)
    for _, l in ipairs(S.lines(spell, c)) do if l.flag == "skillRange" then return l end end
  end
  H.eq(range(1, {}).parts[1].text, "50", "已知門檻顯示數字")
  H.eq(range(2, {}).parts[1].text, "-", "未知門檻顯示 -")
  H.eq(range(2, {}).parts[1].color, "o", "- 保持橘色")
  H.eq(range(2, {}).text, "- 55 57 60", "整行文字")
  H.eq(range(2, ctx).parts[1].text, "40", "訓練師快取補上數字")
  H.eq(range(3, ctx).parts[1].text, "-", "訓練師 skill=0 仍未知")
end

-- 配方書品質：lines 的來源行帶 q（交給 Window 上色）；缺 q 不帶
do
  local ns = setup("zhTW", { sources = {
    [1] = { src = "book", books = { { item = 10, q = 4 }, { item = 11 }, { item = 12, q = 4, side = "H" } } } } })
  local out = ns.Source.lines(1, { side = "A", names = names() })
  local src = {}
  for _, l in ipairs(out) do if l.flag == "source" then src[#src + 1] = l end end
  H.eq(src[1].q, 4, "書有 q → 來源行帶 q")
  H.eq(src[2].q, nil, "書沒 q → 來源行不帶 q")
  H.eq(src[3].q, 4, "另一陣營行也帶 q（顏色由 sideOther 蓋掉）")
  H.eq(src[3].sideOther, true, "另一陣營標記")
end

-- Locale 鍵對照
do
  H.reset({ locale = "zhTW" })
  local ns = H.load(FILES)
  local bad = 0
  for k in pairs(ns.LOCALES.enUS) do if k:find("^SRC_") or k == "REP_RANKS" then if ns.LOCALES.zhTW[k] == nil then bad = bad + 1 end end end
  for k in pairs(ns.LOCALES.zhTW) do if k:find("^SRC_") or k == "REP_RANKS" then if ns.LOCALES.enUS[k] == nil then bad = bad + 1 end end end
  H.eq(bad, 0, "SRC_ 字串兩種語系都有")
  H.eq(#ns.LOCALES.enUS.REP_RANKS, 8, "聲望等級 8 個")
  H.eq(#ns.LOCALES.zhTW.REP_RANKS, 8, "聲望等級 8 個（zhTW）")
end

-- 外部名稱含 WoW 跳脫字元：| 一律變 ||
do
  local ns = setup("zhTW", { sources = { [1] = { src = "book", books = { { item = 900, fac = 529, quests = { 10 } } } } },
    names = { zhTW = { quest = { [10] = "|cffff0000X|r" }, area = { [10] = "|TFoo|t" }, faction = { [529] = "|cff00ff00F|r" } }, enUS = { quest = {}, area = {}, faction = {} } } })
  local all = table.concat(texts(ns.Source.lines(1, { side = "A", names = { item = function() return "|cffff0000B|r" end } })), "\n")
  H.check(all:find("||cffff0000X||r", 1, true) ~= nil, "任務名稱的 | 被跳脫")
  H.check(all:find("||TFoo||t", 1, true) ~= nil, "地區名稱的 | 被跳脫")
  H.check(all:find("||cff00ff00F||r", 1, true) ~= nil, "陣營名稱的 | 被跳脫")
  H.check(all:find("||cffff0000B||r", 1, true) ~= nil, "書名的 | 被跳脫")
  H.check(not all:find("[^|]|c") and not all:find("[^|]|T"), "沒有未跳脫的色碼")
end

-- 聲望等級：資料 1 起算（Source 不再換算）：8 = 崇拜、1 = 仇恨；用遊戲全域字串
do
  local ns = setup("zhTW", { sources = { [3] = { src = "book", books = { { item = 901, fac = 529, rep = 8 } } },
                                         [4] = { src = "book", books = { { item = 902, fac = 529, rep = 1 } } } }, names = NAMES_() })
  _G.FACTION_STANDING_LABEL8, _G.FACTION_STANDING_LABEL1 = "崇拜", "仇恨"
  local t3 = table.concat(texts(ns.Source.lines(3, { side = "A", names = names() })), "\n")
  local t4 = table.concat(texts(ns.Source.lines(4, { side = "A", names = names() })), "\n")
  _G.FACTION_STANDING_LABEL8, _G.FACTION_STANDING_LABEL1 = nil, nil
  H.check(t3:find("銀色黎明：崇拜", 1, true) or t3:find("銀色黎明", 1, true) and t3:find("崇拜", 1, true), "rep 8 → 崇拜")
  H.check(t4:find("仇恨", 1, true), "rep 1（來自原始 0）→ 仇恨，不被丟掉")
end

-- 學費 0 視為沒有學費；推定訓練師提示帶專業名稱
do
  local ns = setup("zhTW", { sources = { [2] = { src = "trainer" } } })
  local lines = ns.Source.lines(2, { side = "A", trainerSpells = { [2] = 0 } })
  H.eq(lines[2].text, "訓練師", "學費 0 → 不顯示學費")
  H.check(not lines[2].text:find("學費", 1, true), "學費 0 無「學費」字樣")
  local g = ns.Source.lines(2, { side = "A", profName = "裁縫" })
  H.eq(g[3].text, "到裁縫訓練師打開一次即可確認，並顯示學費", "推定提示含專業名稱")
  H.eq(ns.Source.lines(2, { side = "A" })[3].text, "到訓練師打開一次即可確認，並顯示學費", "沒有專業名稱退回通用提示")
  local ne = setup("enUS", { sources = { [2] = { src = "trainer" } } })
  H.eq(ne.Source.lines(2, { side = "A", profName = "Tailoring" })[3].text, "Open a Tailoring trainer once to confirm and show the cost", "英文提示含專業名稱")
end
