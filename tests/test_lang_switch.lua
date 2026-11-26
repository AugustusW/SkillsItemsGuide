-- 語言切換：視窗所有元件的文字（spec 2026-11-27 Standards 對齊 4、6、8）
-- 差分：同樣操作下，「客戶端 X 跟隨遊戲」與「客戶端 Y 設定成 X」每個元件的文字要完全相同；
-- 「開著視窗即時切換」與「一開始就是那個語言」也要相同（抓漏登記的固定文字）
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local tracked, menus

local function boot(client, setting)
  tracked, menus = {}, {}
  local ns
  H.reset({ locale = client, extra = {
    C_Item = {
      GetItemNameByID = function() return nil end, -- 名稱一律走打包資料，兩邊來源相同
      RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 134400 end,
      GetItemInfo = function() return nil end,
      GetItemClassInfo = function(c) local e = ns.Data.itemClassesEn[c] return e and e.name end,
      GetItemSubClassInfo = function(c, s) local e = ns.Data.itemClassesEn[c] return e and e.sub[s] end,
    },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    C_Timer = { After = function() end },
    C_CurrencyInfo = { GetCoinTextureString = function(c) return "coin" .. c end },
    UnitClass = function() return "Mage", "MAGE", 8 end, UnitLevel = function() return 18 end,
    IsSpellKnown = function() return false end,
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } },
    hooksecurefunc = function() end,
    GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
      Hide = function() end, IsShown = function() return false end },
  } })
  -- 追蹤所有 frame 與 FontString（依建立順序）；新式下拉補上 SetupMenu／GenerateMenu
  local create = CreateFrame
  CreateFrame = function(kind, ...)
    local f = create(kind, ...)
    tracked[#tracked + 1] = f
    local cfs = f.CreateFontString
    if cfs then
      f.CreateFontString = function(self, ...)
        local fs = cfs(self, ...)
        tracked[#tracked + 1] = fs
        return fs
      end
    end
    if kind == "DropdownButton" then
      local m = { gen = 0 }
      menus[#menus + 1] = m
      f.SetupMenu = function(self, fn) m.fn = fn; self:GenerateMenu() end
      f.GenerateMenu = function(self)
        m.gen, m.labels = m.gen + 1, {}
        m.fn(self, { CreateRadio = function(_, label) m.labels[#m.labels + 1] = label end })
        self._text = m.labels[1]
      end
    end
    return f
  end
  SkillsItemsGuideDB = setting and { lang = setting } or nil
  ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  ns.Data.spellNames = { n = 0, ids = "", zhTW = "", enUS = "" } -- 法術名稱兩邊都用遊戲的（nil）
  ns.Names._resetSpellCache()
  return ns
end

local TABS = { "prof", "skill", "item", "spell" }
local function visit(ns)
  ns.Window.open({})
  for _, t in ipairs(TABS) do ns.Window.setTab(t) end
  ns.Window.open({ prof = 197 })
  ns.Window.setTab("item")
end
local function snapshot()
  local out = {}
  for i, w in ipairs(tracked) do out[i] = tostring(w._text) end
  for _, m in ipairs(menus) do out[#out + 1] = "menu:" .. table.concat(m.labels or {}, "|") end
  return out
end
local function same(a, b, msg)
  H.eq(#a, #b, msg .. "：元件數")
  local diffs = 0
  for i = 1, math.max(#a, #b) do
    if a[i] ~= b[i] then
      diffs = diffs + 1
      if diffs <= 5 then H.eq(b[i], a[i], msg .. "：第 " .. i .. " 個元件") end
    end
  end
  H.eq(diffs, 0, msg .. "：不同的元件數")
end

-- 1. 設定與客戶端不同，第一次開視窗（存檔在 ADDON_LOADED 才讀得到）
local ns = boot("enUS", nil); visit(ns); local enFollow = snapshot()
ns = boot("zhTW", "enUS"); visit(ns); local enSet = snapshot()
H.check(#enFollow > 100, "測試前提：收集到足夠的元件（" .. #enFollow .. "）")
same(enFollow, enSet, "繁中客戶端設英文＝英文客戶端")
ns = boot("zhTW", nil); visit(ns); local zhFollow = snapshot()
ns = boot("enUS", "zhTW"); visit(ns); local zhSet = snapshot()
same(zhFollow, zhSet, "英文客戶端設繁中＝繁中客戶端")
H.check(enFollow[1] ~= zhFollow[1] or enFollow[2] ~= zhFollow[2] or #enFollow ~= #zhFollow
  or table.concat(enFollow) ~= table.concat(zhFollow), "測試前提：兩種語言的畫面確實不同")

-- 2. 視窗開著即時切換＝一開始就是那個語言
ns = boot("enUS", nil); visit(ns)
ns.setLang("zhTW")
visit(ns)
local live = snapshot()
ns = boot("enUS", "zhTW"); visit(ns); visit(ns)
same(snapshot(), live, "即時切到繁中＝一開始就是繁中")

ns = boot("zhTW", nil); visit(ns)
local gens = {}
for i, m in ipairs(menus) do gens[i] = m.gen end
ns.setLang("enUS")
for i, m in ipairs(menus) do H.check(m.gen > gens[i], "切換後下拉 " .. i .. " 重新產生") end
H.check(#menus >= 3, "三個下拉（類別、品質、職業）都有（" .. #menus .. "）")
visit(ns)
local live2 = snapshot()
ns = boot("zhTW", "enUS"); visit(ns); visit(ns)
same(snapshot(), live2, "即時切到英文＝一開始就是英文")

-- 2b. 切換後不再操作就直接比對（review Important 2：上面切換後又 visit 會強制重畫，看不出即時刷新有沒有做）
ns = boot("enUS", nil); visit(ns)
ns.setLang("zhTW")
local instant = snapshot()
ns = boot("enUS", "zhTW"); visit(ns)
same(snapshot(), instant, "即時切到繁中、不再操作＝一開始就是繁中")
ns = boot("zhTW", nil); visit(ns)
ns.setLang("enUS")
instant = snapshot()
ns = boot("zhTW", "enUS"); visit(ns)
same(snapshot(), instant, "即時切到英文、不再操作＝一開始就是英文")

-- 3. 停在詳情＋搜尋中切換：搜尋字保留、標題換語言
ns = boot("zhTW", nil)
ns.Window.open({ material = 2589 })
ns.Window.setSearch("亞麻")
local headerZh = ns.Window.state().header
ns.setLang("enUS")
H.eq(ns.Window.state().search, "亞麻", "切換後搜尋字保留")
H.check(ns.Window.state().header ~= headerZh and ns.Window.state().header:find("Linen Cloth", 1, true) ~= nil,
  "切換後反查標題換成英文（" .. tostring(ns.Window.state().header) .. "）")
