-- 設定頁（永恆）：選項 → 插件 → 技能物品指南，三個單選，點了立即生效（spec 2026-11-27 §5）
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local reg, checks
local function boot(client, setting, withSettings)
  reg, checks = {}, {}
  local extra = {
    C_Item = { GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    C_Timer = { After = function() end }, hooksecurefunc = function() end,
    GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
      Hide = function() end, IsShown = function() return false end },
  }
  if withSettings ~= false then
    extra.Settings = {
      RegisterCanvasLayoutCategory = function(frame, name) reg.frame, reg.name = frame, name return { name = name } end,
      RegisterAddOnCategory = function(cat) reg.added = cat end,
      OpenToCategory = function() end,
    }
  end
  H.reset({ locale = client, extra = extra })
  local create = CreateFrame
  CreateFrame = function(kind, ...)
    local f = create(kind, ...)
    if kind == "CheckButton" then
      checks[#checks + 1] = f
      f.SetChecked = function(self, v) self._checked = v and true or false end
      f.GetChecked = function(self) return self._checked end
    end
    local cfs = f.CreateFontString
    if cfs then f.CreateFontString = function(self, ...) local fs = cfs(self, ...); f._fs = f._fs or {}; table.insert(f._fs, fs); return fs end end
    return f
  end
  SkillsItemsGuideDB = setting and { lang = setting } or nil
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  return ns
end
local function checked() local t = {} for i, c in ipairs(checks) do t[i] = c._checked and "x" or "." end return table.concat(t) end
local function pageTexts() local t = {} for _, fs in ipairs(reg.frame._fs or {}) do t[#t + 1] = fs._text end return table.concat(t, "\n") end

local ns = boot("enUS", nil)
H.check(reg.frame ~= nil and reg.added ~= nil, "註冊 canvas 設定頁並加進插件分類")
H.eq(reg.name, "SkillsItemsGuide", "英文客戶端分類名稱")
H.eq(#checks, 3, "三個選項")
H.eq(checked(), "x..", "預設勾跟隨遊戲")
H.check(pageTexts():find("Follow game (now: English)", 1, true) ~= nil, "跟隨遊戲標示目前語言")
H.check(pageTexts():find("繁體中文", 1, true) and pageTexts():find("English", 1, true), "語言名稱用該語言本身書寫")

ns.Settings.select("zhTW")
H.eq(checked(), ".x.", "選繁中後只勾中間")
H.eq(ns.lang(), "zhTW", "立即生效")
H.eq(SkillsItemsGuideDB.lang, "zhTW", "寫入存檔")
H.check(pageTexts():find("跟隨遊戲（目前：English）", 1, true) ~= nil, "設定頁本身的文字也換成繁中")
checks[1]._scripts.OnClick(checks[1])
H.eq(ns.lang(), "enUS", "點跟隨遊戲回到客戶端語言")
H.eq(checked(), "x..", "勾回跟隨遊戲")
checks[3]._scripts.OnClick(checks[3])
H.eq(checked(), "..x", "點 English")
H.eq(SkillsItemsGuideDB.lang, "enUS", "英文客戶端選 English 也記住")

ns = boot("zhTW", "enUS")
H.eq(checked(), "..x", "載入時依存檔勾選")
H.eq(reg.name, "SkillsItemsGuide", "存檔設英文：分類名稱英文")

local ok = pcall(boot, "enUS", nil, false)
H.check(ok, "沒有 Settings API 的客戶端載入不報錯")
H.eq(reg.frame, nil, "沒有 Settings API 時不註冊")

-- 正式服沒有設定頁
local retail = H.tocFiles("SkillsItemsGuide_Mainline.toc")
local has = false
for _, f in ipairs(retail) do if f == "Settings.lua" then has = true end end
H.check(not has, "正式服 TOC 不載入 Settings.lua")
