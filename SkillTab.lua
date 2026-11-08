-- 職業技能分頁：職業下拉（職業色）、搜尋、三個狀態勾選、依等級分組的技能清單
local _, ns = ...
local L = ns.L

local SkillTab = {}
ns.SkillTab = SkillTab

-- 訓練師視窗的原色：已學灰、可學綠、等級不足紅
local STATUS_COLOR = { learned = { 0.6, 0.6, 0.6 }, available = { 0.25, 1, 0.25 }, tooLow = { 1, 0.3, 0.3 },
  other = { 0.5, 0.5, 0.5 } }
local STATUS_LABEL = { learned = "SHOW_LEARNED", available = "SHOW_AVAILABLE", tooLow = "SHOW_TOOLOW", other = "NOT_TRAINER" }
local CLASS_ORDER = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }

local S = { show = {}, rowCount = 0 }
function SkillTab.state() return S end

local function playerClass() return select(3, UnitClass("player")) end
local function playerLevel() return UnitLevel and UnitLevel("player") or 0 end

function SkillTab.classColor(classId)
  local token = ns.CLASS_TOKEN[classId]
  local c = RAID_CLASS_COLORS and token and RAID_CLASS_COLORS[token]
  return c
end

function SkillTab.costText(cost)
  if cost == nil then return "—" end
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(cost) end
  if GetMoneyString then return GetMoneyString(cost) end
  return tostring(cost)
end

local function spellName(id) return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end

local function compute()
  local own = S.classId == playerClass()
  local q = S.search
  local match
  if q and q ~= "" then match = function(id) local n = spellName(id) return n ~= nil and n:find(q, 1, true) ~= nil end end
  local res = ns.Skills.list(S.classId, {
    own = own, level = playerLevel(), show = S.show, match = match,
    isKnown = own and function(id)
      if IsPlayerSpell and IsPlayerSpell(id) then return true end
      return IsSpellKnown and IsSpellKnown(id) or false
    end or nil,
  })
  S.own, S.result = own, res
  S.checksEnabled = own and (IsSpellKnown ~= nil or IsPlayerSpell ~= nil)
  S.scrollTo = res.scrollTo
  local n = 0
  for _, g in ipairs(res.groups) do n = n + #g.rows end
  S.rowCount = n
  local cname = L.class(S.classId)
  S.header = own and string.format(L.YOU_FMT, cname, playerLevel()) or string.format(L.BROWSE_FMT, cname)
  local src = res.source
  S.source = src.kind == "verified" and string.format(L.SOURCE_VERIFIED, tostring(src.build), tostring(src.date))
    or string.format(L.SOURCE_CLIENT, tostring(src.build))
  S.hint = src.hint
end

-- ---------- 畫面 ----------
local panel, ui
local lines = {}

local function line(i)
  if lines[i] then return lines[i] end
  local r = CreateFrame("Button", nil, ui.content)
  r:SetSize(840, 24)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20)
  r.icon:SetPoint("LEFT", 4, 0)
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.text:SetPoint("LEFT", 30, 0)
  r.text:SetJustifyH("LEFT")
  r.cost = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.cost:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnEnter", function(self)
    if self.spell and GameTooltip and GameTooltip.SetSpellByID then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(self.spell)
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  r:SetScript("OnClick", function(self)
    if self.spell and IsShiftKeyDown and IsShiftKeyDown() and C_Spell and C_Spell.GetSpellLink and ChatEdit_InsertLink then
      local link = C_Spell.GetSpellLink(self.spell)
      if link then ChatEdit_InsertLink(link) end
    end
  end)
  lines[i] = r
  return r
end

function SkillTab.render()
  if not panel then return end
  local c = SkillTab.classColor(S.classId)
  ui.classText:SetText(L.class(S.classId))
  if c then ui.classText:SetTextColor(c.r, c.g, c.b) end
  ui.header:SetText(S.header or "")
  ui.source:SetText(S.source or "")
  for key, cb in pairs(ui.checks) do
    cb:SetEnabled(S.checksEnabled)
    cb:SetChecked(S.show[key] and true or false)
  end
  local i, y, scrollY = 0, 0, nil
  for _, g in ipairs(S.result.groups) do
    i = i + 1
    local h = line(i)
    h.spell = nil
    h.icon:Hide()
    h.cost:SetText("")
    local title = string.format(L.LV_FMT, g.lv) .. (g.tag == "current" and L.LV_CURRENT or g.tag == "next" and L.LV_NEXT or "")
    h.text:SetText(title)
    h.text:SetTextColor(1, 0.82, 0)
    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:Show()
    if g.lv == S.scrollTo then scrollY = y end
    y = y + 24
    for _, r in ipairs(g.rows) do
      i = i + 1
      local row = line(i)
      row.spell = r.spell
      row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(r.spell) or 134400)
      row.icon:Show()
      local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(r.spell)
      local text = (spellName(r.spell) or ("#" .. r.spell)) .. (sub and sub ~= "" and (" " .. sub) or "")
      if r.status then text = text .. "  " .. L[STATUS_LABEL[r.status]] end
      row.text:SetText(text)
      local col = r.status and STATUS_COLOR[r.status] or { 1, 1, 1 }
      row.text:SetTextColor(col[1], col[2], col[3])
      row.cost:SetText(SkillTab.costText(r.cost))
      row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:Show()
      y = y + 24
    end
  end
  for k = i + 1, #lines do lines[k]:Hide() end
  ui.empty:SetText(i == 0 and L.NO_SKILLS or "")
  ui.hint:SetText(S.hint or "")
  ui.content:SetHeight(math.max(y, 1))
  ui.scroll:SetVerticalScroll(scrollY or 0)
end

-- 下拉選單建立時職業還沒決定，之後要叫它重新產生才會顯示目前選擇（實測：預設空白）
function SkillTab.refreshDropdown()
  local dd = SkillTab._dd
  if dd and dd.GenerateMenu then dd:GenerateMenu() end
end

function SkillTab.selectClass(classId)
  if classId ~= S.classId then S.show = {} end -- 換職業清掉勾選（看別的職業時勾選本來就不作用）
  S.classId = classId
  compute()
  SkillTab.render()
  SkillTab.refreshDropdown()
end

function SkillTab.setShow(show)
  S.show = show or {}
  compute()
  SkillTab.render()
end

local function buildDropdown(parent)
  -- 新式下拉（WowStyle1DropdownTemplate＋SetupMenu）；沒有 SetupMenu 就退回職業按鈕列
  local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  if ok and dd and dd.SetupMenu then
    SkillTab._dd = dd
    dd:SetSize(140, 24)
    dd:SetPoint("TOPLEFT", 60, -4)
    dd:SetupMenu(function(_, root)
      for _, id in ipairs(CLASS_ORDER) do
        local c = SkillTab.classColor(id)
        local label = L.class(id)
        if c and c.WrapTextInColorCode then label = c:WrapTextInColorCode(label) end
        root:CreateRadio(label, function() return S.classId == id end, function() SkillTab.selectClass(id) end)
      end
    end)
    return
  end
  for k, id in ipairs(CLASS_ORDER) do
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(52, 20)
    b:SetPoint("TOPLEFT", 60 + (k - 1) * 54, -4)
    b:SetText(L.class(id))
    b:SetScript("OnClick", function() SkillTab.selectClass(id) end)
  end
end

local function build(container)
  panel = container
  ui = { checks = {} }
  local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", 10, -8)
  label:SetText(L.CLASS_LABEL)
  ui.classText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ui.classText:SetPoint("TOPRIGHT", -12, -8)
  buildDropdown(panel)
  ui.search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  ui.search:SetSize(160, 20)
  ui.search:SetPoint("TOPLEFT", 14, -34)
  ui.search:SetAutoFocus(false)
  ui.search:ClearFocus() -- 建立當下會搶焦點（記憶 2077）
  ui.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ui.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  ui.search:SetScript("OnHide", function(self) self:ClearFocus() end)
  ui.search:SetScript("OnTextChanged", function(self) S.search = self:GetText(); compute(); SkillTab.render() end)
  -- 三個勾選依前一個文字的實際寬度往右排、間距相同（實測：固定 130px 時長標籤會擠到下一個）
  local prev
  for _, key in ipairs({ "learned", "available", "tooLow" }) do
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    if prev then cb:SetPoint("LEFT", prev, "RIGHT", 24, 0) else cb:SetPoint("LEFT", ui.search, "RIGHT", 20, 0) end
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    t:SetText(L[STATUS_LABEL[key]])
    local col = STATUS_COLOR[key]
    t:SetTextColor(col[1], col[2], col[3])
    cb:SetScript("OnClick", function(self)
      S.show[key] = self:GetChecked() and true or nil
      compute(); SkillTab.render()
    end)
    ui.checks[key] = cb
    prev = t
  end
  ui.header = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.header:SetPoint("TOPLEFT", 14, -60)
  ui.source = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.source:SetPoint("TOPRIGHT", -14, -60)
  ui.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  ui.scroll:SetPoint("TOPLEFT", 10, -88)
  ui.scroll:SetPoint("BOTTOMRIGHT", -30, 10)
  ui.content = CreateFrame("Frame", nil, ui.scroll)
  ui.content:SetSize(860, 1)
  ui.scroll:SetScrollChild(ui.content)
  ui.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ui.hint:SetPoint("TOPLEFT", 14, -72)
  ui.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.empty:SetPoint("TOPLEFT", 20, -90)
end

ns.Window.onBuild = build
ns.Window.onSkillTab = function()
  if not S.classId then S.classId = playerClass() end
  compute()
  SkillTab.render()
  SkillTab.refreshDropdown()
end
