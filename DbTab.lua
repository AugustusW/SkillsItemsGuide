-- 物品／法術查詢分頁（永恆限定）：左側篩選、上方搜尋、一列一筆；
-- 物品點了看明細（製作來源＋用途），法術點了跳到職業技能或專業分頁的那一列。
-- 狀態留在本模組：從專業分頁「← 返回」或重開視窗，篩選、搜尋、明細都還在。
local _, ns = ...
local L = ns.L

local DbTab = {}
ns.DbTab = DbTab

local MAX_ROWS = 100
local ROW_W, TEXT_W = 700, 560
local W = ns.Window

local I = { key = "item", filter = { kind = "all" }, list = {}, rendered = 0, overflow = 0, limit = MAX_ROWS }
local P = { key = "spell", filter = { kind = "all" }, list = {}, rendered = 0, overflow = 0, limit = MAX_ROWS }
function DbTab.itemState() return I end
function DbTab.spellState() return P end

local function profIds()
  local ids = {}
  for id in pairs(ns.Data.professions or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

local function itemQualityColor(id) return W.itemColor(id) end

local function classColorCode(classId)
  local c = ns.SkillTab and ns.SkillTab.classColor(classId)
  if c then return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, L.class(classId)) end
  return L.class(classId)
end

-- 遊戲名稱優先；還沒載入時繁中用打包名稱（全部物品），都沒有才顯示代碼
local function itemName(id)
  return ns.DbIndex.displayName(id) or string.format(L.ITEM_PLACEHOLDER, id)
end

-- ---------- 狀態計算 ----------

-- 清單或明細 → 要畫的列（entries）
local function computeItems()
  if I.detail then
    local id = I.detail
    local made, used = ns.Index.madeBy(id), ns.Index.usedBy(id)
    I.madeCount, I.usedCount = #made, #used
    local e = {}
    e[#e + 1] = { section = string.format(L.DB_MADE_BY_FMT, #made) }
    for _, rid in ipairs(made) do e[#e + 1] = { rid = rid } end
    e[#e + 1] = { section = string.format(L.DB_USED_BY_FMT, #used) }
    for _, rid in ipairs(used) do e[#e + 1] = { rid = rid } end
    I.entries = e
    I.header = itemName(id)
    I.headerColor = itemQualityColor(id)
    local it = ns.Data.items[id]
    local sum = ns.DbIndex.itemSummary(id)
    if it and it.il then sum = sum .. L.DOT .. string.format(L.DB_ILVL_FMT, it.il) end
    I.hint = sum
    I.empty = nil
    return
  end
  local res = ns.DbIndex.items(I.filter, I.search)
  I.list = res.list
  local e = {}
  for _, id in ipairs(res.list) do e[#e + 1] = { item = id } end
  I.entries = e
  local label = I.filter.prof and L.prof(I.filter.prof)
    or (I.filter.kind == "mat" and L.DB_MAT) or (I.filter.kind == "product" and L.DB_PRODUCT) or L.DB_ALL_ITEMS
  local cname = I.filter.cls and ns.DbIndex.className(I.filter.cls)
  if cname then label = label .. L.DOT .. cname end
  if I.filter.q then label = label .. L.DOT .. L.QUALITY_NAMES[I.filter.q] end
  I.header = L.paren(label, #res.list)
  if res.loading then I.header = L.label(I.header, L.NAMES_LOADING) end
  I.headerColor = nil
  I.hint = L.DB_ITEM_HINT
  if #res.list > 0 then I.empty = nil
  elseif res.loading then I.empty = L.NAMES_LOADING
  else I.empty = L.SEARCH_EMPTY end
end

local function computeSpells()
  local res = ns.DbIndex.spells(P.filter, P.search)
  P.list = res.list
  local e = {}
  for _, s in ipairs(res.list) do e[#e + 1] = { spellEntry = s } end
  P.entries = e
  local f = P.filter
  local label = (f.classId and L.class(f.classId)) or (f.prof and L.prof(f.prof))
    or (f.kind == "recipe" and L.DB_RECIPE) or (f.kind == "class" and L.DB_CLASS) or L.DB_ALL_SPELLS
  P.header = L.paren(label, #res.list)
  if res.loading then P.header = L.label(P.header, L.NAMES_LOADING) end
  P.hint = L.DB_SPELL_HINT
  P.empty = #res.list == 0 and (res.loading and L.NAMES_LOADING or L.SEARCH_EMPTY) or nil
end

local function compute(S)
  ns.DbIndex.resetKnown()
  if S == I then computeItems() else computeSpells() end
end

-- ---------- 畫面 ----------

local function newRow(S)
  local r = CreateFrame("Button", nil, S.ui.content)
  r:SetSize(ROW_W, 34)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(28, 28)
  r.icon:SetPoint("TOPLEFT", 2, -3)
  r.hl = r:CreateTexture(nil, "BACKGROUND")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 1, 1, 0.06)
  r.hl:Hide()
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", 36, -3)
  r.name:SetJustifyH("LEFT")
  r.name:SetWidth(TEXT_W)
  r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
  r.sub:SetJustifyH("LEFT")
  r.sub:SetWidth(TEXT_W)
  r.sub:SetWordWrap(true)
  r.go = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.go:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnEnter", function(self)
    self.hl:Show()
    local e = self.entry
    if not (e and GameTooltip) then return end
    if e.rid then W.showTree(self, e.rid) return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if e.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.item)
    elseif e.spellEntry and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(e.spellEntry.spell) end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function(self)
    self.hl:Hide()
    if self.entry and self.entry.rid then W._hideTree() elseif GameTooltip then GameTooltip:Hide() end
  end)
  r:SetScript("OnClick", function(self) DbTab.activate(self.entry) end)
  return r
end

local function textH(fs) return fs.GetStringHeight and fs:GetStringHeight() or 14 end

local function fillRow(r, e)
  r.entry = e
  if e.section then
    r.icon:Hide()
    r.name:SetText(e.section)
    r.name:SetTextColor(1, 0.82, 0)
    r.sub:SetText("")
    r.go:SetText("")
    r:EnableMouse(false)
    return 24
  end
  r:EnableMouse(true)
  r.icon:Show()
  local c, title, sub, subC, go
  if e.item then
    r.icon:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.item) or 134400)
    local hasDetail = ns.DbIndex.itemInfo(e.item).total > 0 -- 無關配方的物品沒有「>」（點了不展開）
    c, title, sub, subC, go = itemQualityColor(e.item), itemName(e.item), ns.DbIndex.itemSummary(e.item), W.GREY,
      hasDetail and ">" or ""
  elseif e.rid then
    r.icon:SetTexture(W.recipeIcon(e.rid))
    c, title, sub, go = W.recipeColor(e.rid), W.recipeTitle(e.rid), W.recipeFirstLayer(e.rid), L.TO_PROF
    subC = W.recipeLearned(e.rid) and W.LEARNED or W.GREY
  else
    local s = e.spellEntry
    r.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(s.spell) or 134400)
    c, title = W.QUALITY[1], ns.DbIndex.spellTitle(s.spell)
    sub = ns.DbIndex.spellSummary(s, s.classId and classColorCode(s.classId) or nil)
    if s.classId then
      subC = s.status == "learned" and W.GREY or s.status == "available" and W.LEARNED
        or s.status == "tooLow" and { 1, 0.3, 0.3 } or { 0.8, 0.8, 0.8 }
      go = L.TO_SKILL
    else
      subC = W.recipeLearned(s.rid) and W.LEARNED or W.GREY
      go = L.TO_PROF
    end
  end
  r.name:SetText(title)
  r.name:SetTextColor(c[1], c[2], c[3])
  r.sub:SetText(sub)
  r.sub:SetTextColor(subC[1], subC[2], subC[3])
  r.go:SetText(go)
  return math.max(34, 8 + textH(r.name) + textH(r.sub))
end

local function render(S, resetScroll)
  local ui = S.ui
  if not ui then return end
  ui.header:SetText(S.header or "")
  local hc = S.headerColor or { 1, 0.82, 0 }
  ui.header:SetTextColor(hc[1], hc[2], hc[3])
  ui.hint:SetText(S.hint or "")
  ui.empty:SetText(S.empty or "")
  if ui.back then if S.detail then ui.back:Show() else ui.back:Hide() end end
  -- 明細：標題左邊放物品圖示（遊戲 tooltip、修飾鍵點擊），標題往右移
  if ui.headBtn then
    ui.header:ClearAllPoints()
    if S.detail then
      ui.headBtn.itemId = S.detail
      ui.headBtn.tex:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(S.detail) or 134400)
      ui.headBtn:Show()
      ui.header:SetPoint("TOPLEFT", 186, -30)
      ui.hint:ClearAllPoints(); ui.hint:SetPoint("TOPLEFT", 186, -50)
    else
      ui.headBtn:Hide()
      ui.header:SetPoint("TOPLEFT", 152, -30)
      ui.hint:ClearAllPoints(); ui.hint:SetPoint("TOPLEFT", 152, -50)
    end
  end
  for _, b in ipairs(ui.side) do
    local on = b.match(S.filter)
    if on and b.LockHighlight then b:LockHighlight() elseif b.UnlockHighlight then b:UnlockHighlight() end
  end
  local entries = S.entries or {}
  S.rendered = math.min(#entries, S.limit or MAX_ROWS)
  S.overflow = #entries - S.rendered
  local y = 0
  for i = 1, S.rendered do
    S.rows[i] = S.rows[i] or newRow(S)
    local r = S.rows[i]
    local h = fillRow(r, entries[i])
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r:SetHeight(h)
    r:Show()
    y = y + h
  end
  for i = S.rendered + 1, #S.rows do S.rows[i]:Hide() end
  -- 超過上限：清單最後放「顯示更多」，每按一次多畫 100 筆（使用者實測：聖騎士 190 個法術看不到後面）
  S.footer = S.overflow > 0 and string.format(L.DB_MORE_FMT, S.overflow) or nil
  ui.footer:SetText("")
  ui.more:ClearAllPoints()
  ui.more:SetPoint("TOPLEFT", 4, -y - 6)
  if S.footer then
    ui.more:SetText(S.footer)
    ui.more:Show()
    y = y + 32
  else
    ui.more:Hide()
  end
  ui.content:SetHeight(math.max(y, 1))
  if resetScroll then ui.scroll:SetVerticalScroll(resetScroll == true and 0 or resetScroll) end
end

-- resetScroll 為真＝篩選、搜尋或明細變了：清單回到前 100 筆
local function refresh(S, resetScroll)
  if resetScroll then S.limit = MAX_ROWS end
  compute(S); render(S, resetScroll)
end

-- ---------- 操作 ----------

-- 左側篩選（全部／材料／成品／專業）與類別下拉各自獨立：換一個不清掉另一個
local function setFilter(kind, prof, cls, q)
  I.filter = { kind = kind, prof = prof, cls = cls, q = q }
  I.detail = nil
  refresh(I, true)
  for _, dd in ipairs({ I.ui and I.ui.dd, I.ui and I.ui.qdd }) do if dd and dd.GenerateMenu then dd:GenerateMenu() end end
end
function DbTab.setItemFilter(f) setFilter(f.kind, f.prof, I.filter.cls, I.filter.q) end
function DbTab.setItemClass(cls) setFilter(I.filter.kind, I.filter.prof, cls, I.filter.q) end
function DbTab.setItemQuality(q) setFilter(I.filter.kind, I.filter.prof, I.filter.cls, q) end
function DbTab.setItemSearch(text) I.search, I.detail = text ~= "" and text or nil, nil; refresh(I, true) end
function DbTab.setSpellFilter(f) P.filter = f; refresh(P, true) end
function DbTab.setSpellSearch(text) P.search = text ~= "" and text or nil; refresh(P, true) end

function DbTab.openItem(id)
  local info = ns.DbIndex.itemInfo(id)
  if not (info and info.total > 0) then return end -- 跟配方無關的物品沒有明細可看（使用者 2026-11-13）
  I.listScroll = I.ui and I.ui.scroll.GetVerticalScroll and I.ui.scroll:GetVerticalScroll() or 0
  I.detail = id
  refresh(I, true)
end

function DbTab.backToList()
  I.detail = nil
  refresh(I, I.listScroll or true)
end

function DbTab.openRecipe(rid, from) W.open({ recipe = rid, from = from or "item" }) end

function DbTab.activateSpell(s)
  if s.classId then ns.SkillTab.focus(s.classId, s.spell)
  else DbTab.openRecipe(s.rid, "spell") end
end

-- 點一列：Shift 貼連結，否則看明細／跳轉
function DbTab.activate(e)
  if not e or e.section then return end
  -- 物品（含配方的成品）：修飾鍵點擊交給遊戲（Shift 貼連結、Ctrl 試穿）
  local item = e.item or (e.rid and ns.Data.recipes[e.rid].item)
  if item and W.modifiedItemClick(item) then return end
  if e.spellEntry and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then
    local link = ns.Names.spellLink(e.spellEntry.spell)
    if link then ChatEdit_InsertLink(link) end
    return
  end
  if e.item then DbTab.openItem(e.item)
  elseif e.rid then DbTab.openRecipe(e.rid, "item")
  elseif e.spellEntry then DbTab.activateSpell(e.spellEntry) end
end

-- ---------- 建立 ----------

local function sideButton(S, parent, i, gap, label, filter, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(130, 18)
  b:SetPoint("TOPLEFT", 6, -4 - (i - 1) * 20 - gap)
  b:SetText(label)
  b.match = function(f) -- 類別下拉（cls）不影響左側按鈕的亮起
    return f.kind == filter.kind and f.prof == filter.prof and f.classId == filter.classId
  end
  b:SetScript("OnClick", onClick)
  S.ui.side[#S.ui.side + 1] = b
end

local function buildPanel(S, panel, searchLabel, sourceText)
  S.ui = { side = {} }
  S.rows = {}
  local ui = S.ui
  ui.search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  ui.search:SetSize(220, 20)
  ui.search:SetPoint("TOPLEFT", 152, -4)
  ui.search:SetAutoFocus(false)
  ui.search:ClearFocus() -- EditBox 建立當下會搶焦點（記憶 2077）
  ui.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ui.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  ui.search:SetScript("OnHide", function(self) self:ClearFocus() end)
  ui.searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.searchLabel:SetPoint("LEFT", ui.search, "RIGHT", 8, 0)
  ui.searchLabel:SetText(searchLabel)
  ui.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ui.header:SetPoint("TOPLEFT", 152, -30)
  ui.header:SetWidth(560)
  ui.header:SetJustifyH("LEFT")
  ui.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.hint:SetPoint("TOPLEFT", 152, -50)
  ui.hint:SetWidth(700)
  ui.hint:SetJustifyH("LEFT")
  ui.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  ui.scroll:SetPoint("TOPLEFT", 148, -68)
  ui.scroll:SetPoint("BOTTOMRIGHT", -28, 26)
  ui.content = CreateFrame("Frame", nil, ui.scroll)
  ui.content:SetSize(ROW_W + 10, 1)
  ui.scroll:SetScrollChild(ui.content)
  ui.footer = ui.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.more = CreateFrame("Button", nil, ui.content, "UIPanelButtonTemplate")
  ui.more:SetSize(320, 24)
  ui.more:SetScript("OnClick", function()
    S.limit = (S.limit or MAX_ROWS) + MAX_ROWS
    render(S)
  end)
  ui.more:Hide()
  ui.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.empty:SetPoint("TOPLEFT", 156, -76)
  -- 暴雪 API 條款：清楚標明資料來源（物品資料的版本與匯出日期）
  ui.source = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.source:SetPoint("BOTTOMRIGHT", -10, 8)
  ui.source:SetText(sourceText)
end

local function buildItems(panel)
  local m = ns.Data.meta or {}
  buildPanel(I, panel, L.DB_SEARCH_ITEM,
    string.format(L.DB_SOURCE_FMT, tostring(m.itemsVersion or m.profVersion), tostring(m.itemsGenerated or m.generated)))
  local ui = I.ui
  ui.search:SetScript("OnTextChanged", function(self) DbTab.setItemSearch(self:GetText()) end)
  ui.back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  ui.back:SetSize(80, 20)
  ui.back:SetPoint("TOPRIGHT", -12, -2)
  ui.back:SetText(L.DB_BACK_LIST)
  ui.back:SetScript("OnClick", DbTab.backToList)
  ui.back:Hide()
  ui.headBtn = CreateFrame("Button", nil, panel)
  ui.headBtn:SetSize(30, 30)
  ui.headBtn:SetPoint("TOPLEFT", 152, -30)
  ui.headBtn.tex = ui.headBtn:CreateTexture(nil, "ARTWORK")
  ui.headBtn.tex:SetAllPoints()
  ui.headBtn:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.itemId) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemId) end
    GameTooltip:Show()
  end)
  ui.headBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  ui.headBtn:SetScript("OnClick", function(self) W.modifiedItemClick(self.itemId) end)
  ui.headBtn:Hide()
  local n = 0
  local function add(label, filter, gap)
    n = n + 1
    sideButton(I, panel, n, gap, label, filter, function() DbTab.setItemFilter(filter) end)
  end
  add(L.DB_ALL, { kind = "all" }, 0)
  add(L.DB_MAT, { kind = "mat" }, 0)
  add(L.DB_PRODUCT, { kind = "product" }, 0)
  for _, id in ipairs(profIds()) do add(L.prof(id), { kind = "all", prof = id }, 8) end
  -- 類別下拉（新式下拉，永恆實測可用；沒有 SetupMenu 的客戶端就不顯示）
  local ok, dd = pcall(CreateFrame, "DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
  if ok and dd and dd.SetupMenu then
    ui.searchLabel:Hide()
    ui.dd = dd
    dd:SetSize(150, 22)
    dd:SetPoint("LEFT", ui.search, "RIGHT", 12, 0)
    local ids = {}
    for c in pairs(ns.Data.itemClasses or {}) do ids[#ids + 1] = c end
    table.sort(ids)
    dd:SetupMenu(function(_, root)
      root:CreateRadio(L.DB_ALL_CLASSES, function() return I.filter.cls == nil end, function() DbTab.setItemClass(nil) end)
      for _, c in ipairs(ids) do
        root:CreateRadio((ns.DbIndex.className(c)), function() return I.filter.cls == c end,
          function() DbTab.setItemClass(c) end)
      end
    end)
    -- 品質下拉（名稱用品質色）
    local ok2, qdd = pcall(CreateFrame, "DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    if ok2 and qdd and qdd.SetupMenu then
      ui.qdd = qdd
      qdd:SetSize(120, 22)
      qdd:SetPoint("LEFT", dd, "RIGHT", 8, 0)
      qdd:SetupMenu(function(_, root)
        root:CreateRadio(L.DB_ALL_QUALITY, function() return I.filter.q == nil end, function() DbTab.setItemQuality(nil) end)
        for q = 0, 7 do
          local c = W.QUALITY[q]
          local label = string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, L.QUALITY_NAMES[q])
          root:CreateRadio(label, function() return I.filter.q == q end, function() DbTab.setItemQuality(q) end)
        end
      end)
    end
  end
end

local function buildSpells(panel)
  -- 法術：職業技能來自遊戲客戶端資料表（wago.tools），配方法術的配方來自 Blizzard API
  local m = ns.Data.meta or {}
  buildPanel(P, panel, L.DB_SEARCH_SPELL,
    string.format(L.DB_SPELL_SOURCE_FMT, tostring(m.classBuild), tostring(m.profVersion)))
  P.ui.search:SetScript("OnTextChanged", function(self) DbTab.setSpellSearch(self:GetText()) end)
  local n = 0
  local function add(label, filter, gap)
    n = n + 1
    sideButton(P, panel, n, gap, label, filter, function() DbTab.setSpellFilter(filter) end)
  end
  add(L.DB_ALL, { kind = "all" }, 0)
  add(L.DB_RECIPE, { kind = "recipe" }, 0)
  add(L.DB_CLASS, { kind = "class" }, 0)
  for _, id in ipairs(profIds()) do add(L.prof(id), { kind = "recipe", prof = id }, 8) end
  for _, id in ipairs(ns.Skills.CLASS_ORDER) do
    add(classColorCode(id), { kind = "class", classId = id }, 16) -- 職業名用職業色
  end
end

W.registerTab("item", L.TAB_ITEM, buildItems, function() refresh(I) end, function() refresh(I) end)
W.registerTab("spell", L.TAB_SPELL, buildSpells, function() refresh(P) end, function() refresh(P) end)
