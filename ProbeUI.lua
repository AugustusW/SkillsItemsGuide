-- 探測視窗：可全選複製的文字框（使用者在另一台 PC，要貼回 Telegram），並記錄背包點擊測試
local ADDON, ns = ...
local L = ns.L

local UI = {}
ns.ProbeUI = UI

local function meta(key)
  local f = C_AddOns and C_AddOns.GetAddOnMetadata
  return f and f(ADDON, key) or "?"
end

function UI.collect()
  local db = SkillsItemsGuideDB
  db.probe = db.probe or {}
  db.probe.results = ns.Probe.run()
  db.probe.glyphs = ns.Probe.glyphs()
  db.probe.build = table.concat({ GetBuildInfo() }, " ")
  db.probe.date = date("%Y-%m-%d %H:%M")
  db.manifest = ns.Probe.manifest()
  db.probe.behavior = ns.Probe.behavior()
  db.probe.projectId = WOW_PROJECT_ID
end

function UI.recordClick(c)
  local p = SkillsItemsGuideDB.probe or {}
  SkillsItemsGuideDB.probe = p
  p.clicks = p.clicks or {}
  c.sold = (c.moneyAfter or 0) > (c.moneyBefore or 0)
  p.clicks[#p.clicks + 1] = c
  while #p.clicks > 20 do table.remove(p.clicks, 1) end
end

function UI.text()
  local p = SkillsItemsGuideDB.probe or {}
  local lines = {
    L.PROBE_TITLE .. " " .. meta("Version") .. " X-Build: " .. meta("X-Build"),
    "build " .. tostring(p.build) .. " / " .. tostring(p.date),
  }
  for _, r in ipairs(p.results or {}) do lines[#lines + 1] = r.name .. ": " .. (r.ok and r.note or "missing") end
  local m = SkillsItemsGuideDB.manifest or {}
  for _, t in ipairs(ns.Probe.TEMPLATES) do
    lines[#lines + 1] = "template " .. t .. ": " .. tostring((m.templates or {})[t])
  end
  for kind, list in pairs(m.methods or {}) do lines[#lines + 1] = "methods " .. kind .. ": " .. #list end
  for ch, w in pairs(p.glyphs or {}) do lines[#lines + 1] = "glyph " .. ch .. " width " .. tostring(w) end
  lines[#lines + 1] = "MODIFIER_STATE_CHANGED fired: " .. tostring(p.modEvents or 0)
  local b = p.behavior or {}
  lines[#lines + 1] = "WOW_PROJECT_ID " .. tostring(p.projectId) .. " / recipes " .. tostring(b.recipeCount)
    .. " / learned " .. tostring(b.learnedCount)
  for _, s in ipairs(b.samples or {}) do
    lines[#lines + 1] = string.format("recipe %s learned=%s playerSpell=%s spellKnown=%s", tostring(s.id),
      tostring(s.learned), tostring(s.isPlayerSpell), tostring(s.isSpellKnown))
  end
  for i, c in ipairs(p.clicks or {}) do
    lines[#lines + 1] = string.format("click %d: shift=%s alt=%s merchant=%s split=%s chat=%q sold=%s hook=%s",
      i, tostring(c.shift), tostring(c.alt), tostring(c.merchant), tostring(c.split), c.chat or "", tostring(c.sold), tostring(c.hook))
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = L.PROBE_CLICK_STEPS
  return table.concat(lines, "\n")
end

local frame, box
local function build()
  frame = CreateFrame("Frame", "SkillsItemsGuideProbeFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(520, 420)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 12, -30)
  hint:SetText(L.PROBE_HINT)
  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -50)
  scroll:SetSize(470, 350)
  box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetFontObject("ChatFontNormal")
  box:SetWidth(460)
  box:SetAutoFocus(false)
  box:ClearFocus() -- EditBox 預設 autoFocus，建立當下就會搶焦點，要立刻放掉
  -- 鍵盤焦點：只有使用者點進文字框才取得；Esc 或視窗關閉時一定釋放，
  -- 否則遊戲的所有快捷鍵（含跳躍）都會被文字框吃掉（2026-11-08 實測）
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Hide() end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  box:SetScript("OnHide", function(self) self:ClearFocus() end)
  frame:SetScript("OnHide", function() box:ClearFocus() end)
  scroll:SetScrollChild(box)
  tinsert(UISpecialFrames, "SkillsItemsGuideProbeFrame")
end

function UI.show()
  UI.collect()
  if not frame then build() end
  box:SetText(UI.text())
  frame:Show()
  box:ClearFocus()
end

-- 背包點擊測試：按著 Alt 的點擊都記錄前後狀態（Shift+Alt 與 Alt 單獨都要測）
local function snapshot(hookName)
  local c = {
    hook = hookName,
    shift = IsShiftKeyDown and IsShiftKeyDown() or nil,
    alt = IsAltKeyDown and IsAltKeyDown() or nil,
    merchant = MerchantFrame and MerchantFrame:IsShown() or false,
    moneyBefore = GetMoney and GetMoney() or 0,
  }
  if not c.alt then return end
  local function after()
    c.moneyAfter = GetMoney and GetMoney() or 0
    c.split = StackSplitFrame and StackSplitFrame:IsShown() or false
    local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    c.chat = eb and eb:GetText() or ""
    UI.recordClick(c)
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, after) else after() end
end

local hooksInstalled = false
function UI.installHooks()
  if hooksInstalled or not hooksecurefunc then return end
  hooksInstalled = true
  if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function() snapshot("HandleModifiedItemClick") end)
  end
  if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick then
    hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", function() snapshot("Mixin.OnModifiedClick") end)
  elseif ContainerFrameItemButton_OnModifiedClick then
    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function() snapshot("ContainerFrameItemButton_OnModifiedClick") end)
  end
  local f = CreateFrame("Frame")
  f:RegisterEvent("MODIFIER_STATE_CHANGED")
  f:SetScript("OnEvent", function()
    local p = SkillsItemsGuideDB.probe or {}
    SkillsItemsGuideDB.probe = p
    p.modEvents = (p.modEvents or 0) + 1
  end)
end
