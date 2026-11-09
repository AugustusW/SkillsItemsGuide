-- 探測：在永恆客戶端確認哪些 API、widget 方法、template 存在，結果寫入 SavedVariables 並顯示可複製的視窗。
local _, ns = ...

local Probe = {}
ns.Probe = Probe

Probe.APIS = {
  "CreateFrame", "IsSpellKnown", "IsPlayerSpell", "C_Spell.GetSpellTexture", "C_Spell.GetSpellName",
  "GetSpellSubtext", "GetItemIcon", "GetItemInfo", "C_Item.GetItemInfo", "C_ClassColor.GetClassColor",
  "RAID_CLASS_COLORS", "GetCoinTextureString", "SecondsToTime", "GetProfessions", "GetProfessionInfo",
  "C_TradeSkillUI.GetAllRecipeIDs", "C_TradeSkillUI.GetRecipeInfo", "C_TradeSkillUI.GetRecipeCooldown",
  "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillRecipeLink", "GetNumCrafts", "GetCraftInfo",
  "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceLevelReq", "GetTrainerServiceCost",
  "GetTrainerServiceSkillReq", "GetTrainerServiceTypeFilter", "SetTrainerServiceTypeFilter",
  "TooltipDataProcessor.AddTooltipPostCall", "GameTooltip", "GameTooltip.GetOwner", "GameTooltip.HookScript",
  "MenuUtil.CreateContextMenu", "UIDropDownMenu_Initialize", "ChatEdit_InsertLink", "ChatFrame_OpenChat",
  "ChatEdit_GetActiveWindow", "GetBuildInfo", "C_AddOns.GetAddOnMetadata", "IsShiftKeyDown", "IsAltKeyDown",
  "ContainerFrameItemButton_OnModifiedClick", "ContainerFrameItemButtonMixin", "HandleModifiedItemClick",
  "StackSplitFrame", "GetMoney", "MerchantFrame", "C_Container.GetContainerItemInfo", "Enum.TooltipDataType",
  -- 正式版（plan Task 2）
  "WOW_PROJECT_ID", "C_TradeSkillUI.GetChildProfessionInfo", "C_TradeSkillUI.GetBaseProfessionInfo",
  "C_TradeSkillUI.GetProfessionInfoBySkillLineID", "C_Item.GetItemNameByID", "C_Item.RequestLoadItemDataByID",
  "GameTooltip.SetItemByID", "GameTooltip.SetSpellByID", "InCombatLockdown", "C_Timer.After",
}

Probe.TEMPLATES = {
  "BasicFrameTemplateWithInset", "UIPanelButtonTemplate", "UICheckButtonTemplate", "InputBoxTemplate",
  "UIPanelScrollFrameTemplate", "WowStyle1DropdownTemplate", "UIDropDownMenuTemplate", "TabSystemTemplate",
  "PanelTabButtonTemplate",
}

Probe.WIDGETS = { "Frame", "Button", "EditBox", "ScrollFrame", "CheckButton" }

-- 用 "A.B.C" 路徑在 _G 底下找，任何一層不存在就回 nil
local function resolve(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    local ok, v = pcall(function() return cur[part] end)
    if not ok then return nil end
    cur = v
  end
  return cur
end
Probe.resolve = resolve

function Probe.run()
  local results = {}
  for _, name in ipairs(Probe.APIS) do
    local ok, v = pcall(resolve, name)
    local exists = ok and v ~= nil
    results[#results + 1] = { name = name, ok = exists, note = exists and type(v) or "missing" }
  end
  return results
end

-- 傾印 widget 方法名（metatable 的 __index）與 template 是否可建
function Probe.manifest()
  local m = { methods = {}, templates = {}, globals = {} }
  for _, kind in ipairs(Probe.WIDGETS) do
    local ok, f = pcall(CreateFrame, kind)
    local list = {}
    if ok and f then
      -- EditBox 建立當下會搶鍵盤焦點（記憶 2077）；探測用的元件一律放焦點並隱藏
      if f.SetAutoFocus then f:SetAutoFocus(false) end
      if f.ClearFocus then f:ClearFocus() end
      if f.Hide then f:Hide() end
      local mt = getmetatable(f)
      local idx = mt and mt.__index
      if type(idx) == "table" then
        for k, v in pairs(idx) do if type(v) == "function" then list[#list + 1] = k end end
        table.sort(list)
      end
    end
    m.methods[kind] = list
  end
  for _, t in ipairs(Probe.TEMPLATES) do
    m.templates[t] = (pcall(CreateFrame, "Frame", nil, nil, t)) and true or false
  end
  for _, r in ipairs(Probe.run()) do m.globals[r.name] = r.ok end
  return m
end

-- 字元探測：繪框字元寬度（0 代表缺字）
function Probe.glyphs()
  local holder = CreateFrame("Frame")
  local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local w = {}
  for _, ch in ipairs({ "├", "└", "│", "-" }) do
    if fs.SetText and fs.GetStringWidth then fs:SetText(ch); w[ch] = fs:GetStringWidth() end
  end
  return w
end

-- 行為探測（不只存在與否）：開著專業視窗時 GetAllRecipeIDs 回幾筆、learned 欄位、recipeID 是否就是 spellID
function Probe.behavior()
  local b = {}
  local ui = C_TradeSkillUI
  if not (ui and ui.GetAllRecipeIDs) then return b end
  local ok, ids = pcall(ui.GetAllRecipeIDs)
  if not ok or type(ids) ~= "table" then return b end
  b.recipeCount = #ids
  -- 已學的優先取樣（未學的看不出 recipeID 是否等於 spellID），再補一筆未學的當對照
  local learned, unlearned = {}, {}
  for _, id in ipairs(ids) do
    local info = ui.GetRecipeInfo and ui.GetRecipeInfo(id) or {}
    if info.learned then learned[#learned + 1] = id elseif #unlearned < 1 then unlearned[#unlearned + 1] = id end
  end
  b.learnedCount = #learned
  local pick = {}
  for i = 1, math.min(3, #learned) do pick[#pick + 1] = learned[i] end
  for _, id in ipairs(unlearned) do pick[#pick + 1] = id end
  b.samples = {}
  for i, id in ipairs(pick) do
    local info = ui.GetRecipeInfo and ui.GetRecipeInfo(id) or {}
    b.samples[i] = {
      id = id,
      learned = info.learned,
      isPlayerSpell = IsPlayerSpell and IsPlayerSpell(id) or false,
      isSpellKnown = IsSpellKnown and IsSpellKnown(id) or false,
    }
  end
  return b
end
