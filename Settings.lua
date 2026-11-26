-- 設定頁（只在永恆載入）：選項 → 插件 → 技能物品指南。
-- 三個單選：跟隨遊戲／繁體中文／English，點了立即生效（spec 2026-11-27 語言切換 §5）
local _, ns = ...
local L = ns.L

local S = {}
ns.Settings = S

local NATIVE = { zhTW = "繁體中文", enUS = "English" } -- 語言名稱用該語言本身書寫，不翻譯
local CHOICES = {
  { value = nil, label = function() return string.format(L.SET_FOLLOW_FMT, NATIVE[ns.clientLang() or "enUS"]) end },
  { value = "zhTW", label = function() return NATIVE.zhTW end },
  { value = "enUS", label = function() return NATIVE.enUS end },
}
local boxes = {}

local function sync()
  local cur = ns.langSetting()
  for i, c in ipairs(CHOICES) do if boxes[i] then boxes[i]:SetChecked(c.value == cur) end end
end

function S.select(v)
  ns.setLang(v)
  sync() -- 設成與目前相同的語言時 setLang 不通知，勾選仍要更新
end

local function build(panel)
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  L.bind(title, "SET_TITLE")
  local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  desc:SetPoint("TOPLEFT", 16, -44)
  desc:SetWidth(560)
  desc:SetJustifyH("LEFT")
  desc:SetWordWrap(true)
  L.bind(desc, "SET_DESC")
  for i, c in ipairs(CHOICES) do
    -- 單選：manifest 沒有 radio 樣板，用勾選框自己做互斥
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 16, -80 - (i - 1) * 28)
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    L.bind(t, c.label)
    cb:SetScript("OnClick", function() S.select(c.value) end)
    boxes[i] = cb
  end
  sync()
end

local function register()
  local panel = CreateFrame("Frame")
  build(panel)
  S.category = Settings.RegisterCanvasLayoutCategory(panel, L.ADDON_TITLE)
  Settings.RegisterAddOnCategory(S.category)
end

table.insert(ns.onLangChanged, sync)
ns.onLoad = ns.onLoad or {}
table.insert(ns.onLoad, function()
  -- 存檔在 ADDON_LOADED 才讀得到：此時才建頁面，勾選與分類名稱才對
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local try = ns.ErrorLog and ns.ErrorLog.try or pcall
    try(register)
  end
end)
