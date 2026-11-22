-- 使用者實測（2026-11-08）：完整視窗的配方圖示 tooltip 只有拆解樹，少了物品本身的資訊
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")

local calls
local function boot(withItemApi)
  calls = { lines = {} }
  local tip = {
    SetOwner = function() calls.owner = true end,
    ClearLines = function() calls.cleared = true end,
    AddLine = function(_, t) calls.lines[#calls.lines + 1] = t end,
    Show = function() calls.shown = true end, Hide = function() end, IsShown = function() return false end,
  }
  if withItemApi then
    tip.SetItemByID = function(_, id) calls.item = id; calls.lines[#calls.lines + 1] = "<item " .. id .. ">" end
    tip.SetSpellByID = function(_, id) calls.spell = id; calls.lines[#calls.lines + 1] = "<spell " .. id .. ">" end
  end
  H.reset({ locale = "zhTW", extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return "法術" end, GetSpellTexture = function() return 1 end },
    GameTooltip = tip,
    hooksecurefunc = function() end,
  } })
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end

local function firstRecipe(ns, withItem)
  for rid, rec in pairs(ns.Data.recipes) do
    if (rec.item ~= nil) == withItem and (withItem or rec.spell) and #(rec.r or {}) > 0 then return rid, rec end
  end
end

-- 有成品的配方：先放遊戲的物品 tooltip，再接拆解樹
local ns = boot(true)
local rid, rec = firstRecipe(ns, true)
ns.Window.showTree({}, rid)
H.eq(calls.item, rec.item, "配方圖示 tooltip 先顯示成品的物品資訊")
H.eq(calls.lines[1], "<item " .. rec.item .. ">", "物品資訊在最上面")
H.check(#calls.lines > 2, "下面接著拆解樹")
local dup = 0
for _, l in ipairs(calls.lines) do if l:find("名" .. rec.item, 1, true) == 1 then dup = dup + 1 end end
H.eq(dup, 0, "有物品資訊時不再重複一行成品名稱標題")
H.check(calls.shown, "最後 Show")

-- 沒有成品的配方（附魔等）：顯示法術說明
rid, rec = firstRecipe(ns, false)
if rid then
  ns.Window.showTree({}, rid)
  H.eq(calls.spell, rec.spell, "沒有成品的配方顯示法術說明")
end

-- client 沒有 SetItemByID（API 不存在）：退回原本只有拆解樹，不報錯
ns = boot(false)
rid, rec = firstRecipe(ns, true)
local ok, err = pcall(ns.Window.showTree, {}, rid)
H.check(ok, "沒有 SetItemByID 時不報錯：" .. tostring(err))
H.check(calls.lines[1]:find("名" .. rec.item, 1, true) == 1, "沒有 SetItemByID 時第一行仍是成品名稱標題")

-- 取得方式兩段：只有專業清單列的圖示 tooltip 有；DbTab（showTree 無 opts）、原生物品 tooltip、展開列都沒有
do
  local lines, colors, owner
  local tip = {
    SetOwner = function(_, o) owner = o end, ClearLines = function() end, Show = function() end, Hide = function() end,
    GetOwner = function() return owner end,
    AddLine = function(_, t, r, g, b) lines[#lines + 1] = t; colors[#lines] = { r, g, b } end,
    SetItemByID = function() end, SetSpellByID = function() end,
  }
  H.reset({ locale = "zhTW", extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    GameTooltip = tip, hooksecurefunc = function() end,
    UnitFactionGroup = function() return "Alliance" end,
    GetProfessions = function() return 1 end,
    GetProfessionInfo = function() return "裁縫", 0, 100, 300, 0, 0, 197 end,
  } })
  local n = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
  n.Window.open({ prof = 197 })
  local list = n.Window.state().list
  local rid = list[1]
  local sp = n.Data.recipes[rid].spell
  n.Data.meta.sourcesGenerated = "2026-11-22"
  n.Data.sources = { [sp] = { src = "book", books = { { item = 900, side = "H", q = 4 }, { item = 901, q = 3 } }, tr = { 10, 50, 90, 130 } } }
  n.Data.sourceNamesByLocale = { zhTW = { quest = {}, area = {}, faction = {} }, enUS = { quest = {}, area = {}, faction = {} } }
  n.Source.init()
  n.Window.state().expanded[rid] = true
  n.Window.render()

  local function find(pat) for i, l in ipairs(lines) do if tostring(l):find(pat, 1, true) then return i end end end
  local function approx(c, r, g, b) return c and c[1] == r and c[2] == g and c[3] == b end

  lines, colors = {}, {}
  n.Window._rows[1].icon._scripts.OnEnter(n.Window._rows[1].icon)
  local iT, iR = find("學會方式"), find("技能點數")
  H.check(iT and iR and iT < iR, "清單列圖示 tooltip 有兩段")
  H.check(approx(colors[iT], 1, 0.82, 0), "學會方式標題金字")
  H.check(approx(colors[iR], 1, 0.82, 0), "技能點數標題金字")
  local iBook = find("配方：名901")
  H.check(iBook and approx(colors[iBook], 0 / 255, 112 / 255, 221 / 255), "自己陣營的配方行依品質上色（rare 0070dd）")
  local iOther = find("[部落]")
  H.check(iOther and approx(colors[iOther], 0.5, 0.5, 0.5), "另一陣營整行灰字")
  H.check(iBook < iOther, "自己陣營在前")
  -- 品質色逐一斷言，索引位移會失敗
  n.Data.sources[sp].books = { { item = 902, q = 2 }, { item = 903, q = 3 }, { item = 904, q = 4 } }
  n.Window.render()
  lines, colors = {}, {}
  n.Window._rows[1].icon._scripts.OnEnter(n.Window._rows[1].icon)
  local function cval(id, r, g, b) local i = find("配方：名" .. id); return i and approx(colors[i], r / 255, g / 255, b / 255) end
  H.check(cval(902, 30, 255, 0), "q=2 uncommon 1eff00")
  H.check(cval(903, 0, 112, 221), "q=3 rare 0070dd")
  H.check(cval(904, 163, 53, 238), "q=4 epic a335ee")
  n.Data.sources[sp].books = { { item = 900, side = "H", q = 4 }, { item = 901, q = 3 } }
  n.Window.render()
  lines, colors = {}, {}
  n.Window._rows[1].icon._scripts.OnEnter(n.Window._rows[1].icon)
  local iNum = find("|cffff8040")
  H.check(iNum and lines[iNum]:find("|cffff8040%s*10|r") and lines[iNum]:find("|cffffff00%s*50|r")
    and lines[iNum]:find("|cff40bf40%s*90|r") and lines[iNum]:find("|cff808080%s*130|r"), "技能點數四個數字各自上色：" .. tostring(lines[iNum]))
  local iMat = find("原料")
  H.check(iMat and iMat > iNum, "原料在兩段之後")

  -- DbTab 走的路徑（無 opts）
  lines, colors = {}, {}
  n.Window.showTree({}, rid)
  H.eq(find("學會方式"), nil, "showTree 無 opts（DbTab）沒有學會方式")
  H.eq(find("技能點數"), nil, "showTree 無 opts（DbTab）沒有技能點數")

  -- 原生物品 tooltip（Tooltip.lua post-call）：不是圖示 owner 就不補任何樹；owner 是別人
  lines, colors = {}, {}
  n.Window.addTreeIfOwned({ GetOwner = function() return {} end, AddLine = tip.AddLine })
  H.eq(#lines, 0, "原生物品 tooltip 不加")
  -- 清單列圖示 hover 之後的 post-call 重建仍帶兩段
  local row = n.Window._rows[1]
  row.icon._scripts.OnEnter(row.icon)
  lines, colors = {}, {}
  n.Window.addTreeIfOwned(tip)
  H.check(find("學會方式") ~= nil, "清單列圖示 hover 的 post-call 重建仍帶兩段")
  -- 之後換成無 opts 的 hover，不殘留
  n.Window.showTree({}, rid)
  lines, colors = {}, {}
  n.Window.addTreeIfOwned(tip)
  H.eq(find("學會方式"), nil, "換成無 opts 的 hover 不殘留")

  -- 展開列
  local txt = n.Window._rows[1].tree:GetText() or ""
  H.check(txt ~= "" and not txt:find("學會方式", 1, true) and not txt:find("技能點數", 1, true), "展開列不含兩段")
end

-- 確認的訓練師圖示、次要行灰字、另一陣營無圖示
do
  local lines, colors, owner
  local tip = {
    SetOwner = function(_, o) owner = o end, ClearLines = function() end, Show = function() end, Hide = function() end,
    GetOwner = function() return owner end,
    AddLine = function(_, t, r, g, b) lines[#lines + 1] = t; colors[#lines] = { r, g, b } end,
  }
  H.reset({ locale = "zhTW", extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    GameTooltip = tip, hooksecurefunc = function() end,
    UnitFactionGroup = function() return "Alliance" end,
    GetProfessions = function() return 1 end,
    GetProfessionInfo = function() return "裁縫", 0, 100, 300, 0, 0, 197 end,
  } })
  local n = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
  n.Window.open({ prof = 197 })
  local rid = n.Window.state().list[1]
  local sp = n.Data.recipes[rid].spell
  n.Data.meta.sourcesGenerated = "2026-11-22"
  n.Data.sources = { [sp] = { src = "trainer", tr = { 10, 50, 90, 130 },
    books = { { item = 900, side = "H", skill = 50 }, { item = 901, skill = 60, quests = { 10, 11, 12, 13 } }, { item = 902 } } } }
  n.Data.sourceNamesByLocale = { zhTW = { quest = { [10] = "甲", [11] = "乙", [12] = "丙", [13] = "丁" }, area = {}, faction = {} },
    enUS = { quest = {}, area = {}, faction = {} } }
  n.Source.init()
  SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { [tostring(sp)] = { cost = 150 } } } } } }
  n.Window.render()
  lines, colors = {}, {}
  n.Window._rows[1].icon._scripts.OnEnter(n.Window._rows[1].icon)
  local function find(pat) for i, l in ipairs(lines) do if tostring(l):find(pat, 1, true) then return i end end end
  local i = find("|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t")
  H.check(i and colors[i][1] == 1 and colors[i][2] == 0.82 and colors[i][3] == 0, "確認的訓練師：圖示前綴＋金字")
  local d = find("需要技能 60")
  H.check(d and colors[d][1] == 0.8 and colors[d][2] == 0.8, "sourceDetail 淺灰 0.8")
  local m = find("另有")
  H.check(m and colors[m][1] == 0.8, "sourceMore 淺灰 0.8")
  local o = find("[部落]")
  H.check(o and colors[o][1] == 0.5 and not lines[o]:find("|T", 1, true), "另一陣營行灰字且沒有圖示")
  local od = find("需要技能 50")
  H.check(od and colors[od][1] == 0.5, "另一陣營的次要行灰字")
end
