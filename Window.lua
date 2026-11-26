-- 完整視窗：專業分頁（清單、搜尋、材料反查、展開樹狀拆解、貼到對話框）
-- 狀態（state）與畫面分開：state 可在測試裡直接檢查，畫面只負責把 state 畫出來。
local _, ns = ...
local L = ns.L

local Window = {}
ns.Window = Window

-- 遊戲原色（品質）
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 } }
local GREY = { 0.6, 0.6, 0.6 }
local LEARNED = { 0.25, 1, 0.25 }
Window.QUALITY = QUALITY

local S = { tab = "prof", list = {}, qty = 1, expanded = {}, rendered = 0, overflow = 0 }
local MAX_ROWS = 100 -- 一次最多畫 100 列；更多請用搜尋或專業縮小（避免一次建 2493 列）

local function knownSet()
  local set = {}
  local char = SkillsItemsGuideCharDB or {}
  for k in pairs(char.known or {}) do local n = tonumber(k) if n then set[n] = true end end
  return set
end

function Window.state() return S end

function Window.clampQty(v)
  local n = tonumber(v)
  if not n or n < 1 then return 1 end
  if n > 999 then return 999 end
  return math.floor(n)
end

local function itemName(id) return ns.Names.item(id) end
local function titleOf(rid)
  local title = ns.Format.recipeTitle(ns.Names, rid)
  -- 正式版：舊資料片的配方標資料片名稱（與 Shift 清單一致）
  local t = ns.Data.tiers and ns.Data.tiers[ns.Data.recipes[rid].t or -1]
  if t and t.cur == false and t.name then title = title .. L.OPEN .. t.name .. L.CLOSE end
  return title
end

-- 搜尋：比對產物名與第一層材料名；有名稱還沒載入時標示 loading
local function matches(rid, q)
  local rec = ns.Data.recipes[rid]
  local pending = false
  local function test(name, id)
    if name == nil then
      if ns.Names.isPending(id) then pending = true end -- 重試用完或伺服器回失敗的不算載入中
      return false
    end
    return name:find(q, 1, true) ~= nil
  end
  if rec.item then
    if test(itemName(rec.item), rec.item) then return true, pending end
  else
    local n = ns.Names.recipe(rid)
    if n and n:find(q, 1, true) then return true, pending end
  end
  for _, rg in ipairs(rec.r or {}) do if test(itemName(rg[1]), rg[1]) then return true, pending end end
  return false, pending
end

local function recomputeImpl()
  if S.recipe then
    S.list, S.loading, S.empty = { S.recipe }, false, nil
    S.header = string.format(L.RECIPE_FMT, titleOf(S.recipe))
    return
  end
  local base
  if S.material then
    base = ns.Index.usedBy(S.material)
    local name = itemName(S.material) or string.format(L.ITEM_PLACEHOLDER, S.material)
    S.header = L.label(name, string.format(L.USED_BY_FMT, #base))
  else
    base = {}
    for rid, rec in pairs(ns.Data.recipes or {}) do
      if not S.prof or rec.p == S.prof then base[#base + 1] = rid end
    end
    ns.Breakdown.sortRecipes(base)
    S.header = S.prof and L.prof(S.prof) or L.ALL_PROFESSIONS
  end
  local list, loading = {}, false
  local q = S.search
  if q and q ~= "" then
    for _, rid in ipairs(base) do
      local ok, pending = matches(rid, q)
      if pending then loading = true end
      if ok then list[#list + 1] = rid end
    end
  else
    list = base
  end
  S.list, S.loading = list, loading
  if #list > 0 then
    S.empty = nil
    if loading then S.header = L.label(S.header, L.NAMES_LOADING) end -- 結果先列出，還有名稱在載入就在標題提示
  elseif q and q ~= "" then
    S.empty = loading and L.NAMES_LOADING or L.SEARCH_EMPTY
  else
    S.empty = L.PROF_EMPTY
  end
end
Window.recompute = recomputeImpl
local function recompute() return Window.recompute() end

-- 跳轉自動展開的配方：離開單一配方模式時收回（原本就展開的不動）
local function leaveRecipe()
  if S.autoExpanded then S.expanded[S.autoExpanded] = nil end
  S.recipe, S.from, S.autoExpanded = nil, nil, nil
end

function Window.setSearch(text)
  if S.recipe and text and text ~= "" then leaveRecipe() end -- 單一配方模式下打字：回到該專業清單再搜尋
  S.search = text
  recompute()
  Window.render()
end

function Window.setProf(prof)
  leaveRecipe()
  S.prof, S.material = prof, nil
  recompute()
  Window.render(true)
end

-- ---------- 畫面 ----------

local frame, ui
local registered, byKey = {}, {}

local function releaseFocusOnHide(box)
  box:SetAutoFocus(false)
  box:ClearFocus() -- EditBox 建立當下會搶焦點（記憶 2077）
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnHide", function(self) self:ClearFocus() end)
end


local function isLearned(rid)
  local sp = ns.Data.recipes[rid].spell
  local char = SkillsItemsGuideCharDB or {}
  if not (char.opened or {})[tostring(ns.Data.recipes[rid].p)] then return nil end
  return sp and ns.Index.learned(ns.Data.recipes[rid], char.known or {}) or false
end
Window.recipeLearned = isLearned
Window.recipeTitle = titleOf
Window.LEARNED, Window.GREY = LEARNED, GREY
-- 物品品質色：打包資料優先；永恆新物品打包沒有品質（約 345 個，例：正義護腿）就問遊戲，還沒載入時先白色
function Window.itemQuality(id)
  local it = id and ns.Data.items and ns.Data.items[id]
  local q = it and it.q
  if not q and id and ns.DbIndex then q = ns.DbIndex.quality(id) end -- 永恆全部物品
  if not q and id and C_Item then
    if C_Item.GetItemQualityByID then q = C_Item.GetItemQualityByID(id) end
    if not q and C_Item.GetItemInfo then q = select(3, C_Item.GetItemInfo(id)) end
  end
  return q
end

function Window.itemColor(id)
  return QUALITY[Window.itemQuality(id) or 1] or QUALITY[1]
end

-- 物品的修飾鍵點擊交給遊戲（Shift 貼連結、Ctrl 試穿，跟背包一樣）。
-- 有按 Shift／Ctrl 就回 true（吃掉這次點擊），不看遊戲回傳值（試穿那條路可能回 nil）；
-- 物品還沒快取時拿不到連結：請求載入，這次不動作（再點一次即可），也不穿透成打開明細
function Window.modifiedItemClick(itemId)
  local mod = (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
  if not (mod and itemId) then return false end
  local link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(itemId))
  if link then
    if HandleModifiedItemClick then HandleModifiedItemClick(link) end
  elseif C_Item and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(itemId)
  end
  return true
end

-- 配方名稱的品質色（成品的品質；沒有成品用白色）
function Window.recipeColor(rid)
  local rec = ns.Data.recipes[rid]
  return rec.item and Window.itemColor(rec.item) or QUALITY[1]
end

-- 配方圖示 tooltip 的拆解樹。遊戲會照 tooltip 資料重建（按 Shift 時的 RefreshData、物品資料載入後），
-- 手動加在後面的行會被洗掉，所以拆解樹由物品／法術 post-call 補上（Tooltip.lua），每次重建都會再加一次。
-- 沒有 TooltipDataProcessor 的 client 不會跑 post-call，就由 showTree 自己加。
local tree = { owner = nil, rid = nil, added = false, native = false, opts = nil }

-- 取得方式行的顏色（GameTooltip 一行一色；技能點數四個數字用色碼）
local function hex(r, g, b) return { r / 255, g / 255, b / 255 } end
local BOOK_QUALITY = { [0] = hex(157, 157, 157), hex(255, 255, 255), hex(30, 255, 0), hex(0, 112, 221),
  hex(163, 53, 238), hex(255, 128, 0) } -- 9d9d9d ffffff 1eff00 0070dd a335ee ff8000（寫死，不依賴全域色表）
local RANGE_HEX = { o = "ff8040", y = "ffff00", g = "40bf40", x = "808080" }
local function sourceLine(l)
  local f = l.flag
  if l.sideOther then return l.text, { 0.5, 0.5, 0.5 } end
  if f == "sourceTitle" or f == "skillRangeTitle" then return l.text, { 1, 0.82, 0 } end
  if f == "skillRange" and l.parts then
    local t = {}
    for i, p in ipairs(l.parts) do t[i] = "|cff" .. RANGE_HEX[p.color] .. p.text .. "|r" end
    return table.concat(t, " "), { 1, 1, 1 }
  end
  if f == "source" and l.q and BOOK_QUALITY[l.q] and not l.confirmed then return l.text, BOOK_QUALITY[l.q] end
  if f == "source" and l.confirmed then
    return "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t " .. l.text, { 1, 0.82, 0 }
  end
  if f == "sourceDetail" or f == "sourceMore" then return l.text, { 0.8, 0.8, 0.8 } end
  return l.text, { 1, 1, 1 }
end

local function appendTree(tooltip, native)
  local res = ns.Breakdown.build(tree.rid, S.qty, knownSet())
  local tt = ns.Format.treeTooltip(res, ns.Names, 12, tree.opts)
  if native then tooltip:AddLine(" ") end
  for _, l in ipairs(tt.lines) do
    local text = l.text
    if not (native and l.title) then -- 已經有物品／法術 tooltip，不再重複成品名稱標題
      local c = { 1, 1, 1 }
      if l.title then
        c = l.item and Window.itemColor(l.item) or c
      elseif l.flag then
        text, c = sourceLine(l)
      elseif l.cooldown then c = { 1, 0.3, 0.3 }
      elseif l.materials then c = { 1, 0.82, 0 }
      elseif l.more or l.hint then c = GREY end
      tooltip:AddLine(text, c[1], c[2], c[3], true)
    end
  end
  tree.added = true
end

-- post-call 用：這個 tooltip 現在是不是某個配方圖示的拆解 tooltip，是就補上拆解樹
function Window.addTreeIfOwned(tooltip)
  if tree.owner and tooltip.GetOwner and tooltip:GetOwner() == tree.owner then appendTree(tooltip, true) end
end

-- opts.withSource = Source ctx：只有專業清單列的圖示帶（DbTab 與其他呼叫端不帶）
local function showTree(owner, rid, opts)
  if not GameTooltip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()
  tree.owner, tree.rid, tree.added, tree.opts = owner, rid, false, opts
  -- 使用者實測：只有拆解樹不夠，物品本身的資訊（屬性、類型、售價）最重要 → 先放遊戲原本的 tooltip
  -- API 不存在時（永恆未必都有）退回只有拆解樹
  local rec = ns.Data.recipes[rid]
  local native = false
  if rec.item and GameTooltip.SetItemByID then
    GameTooltip:SetItemByID(rec.item); native = true
  elseif not rec.item and rec.spell and GameTooltip.SetSpellByID then
    GameTooltip:SetSpellByID(rec.spell); native = true
  end
  tree.native = native
  if not tree.added then appendTree(GameTooltip, native) end
  GameTooltip:Show()
  -- 並排配方書 tooltip（永恆才有 SourceTip／Source）；只有專業清單列帶 withSource
  if ns.SourceTip then
    local ctx = opts and opts.withSource
    local book = ctx and rec.spell and ns.Source and ns.Source.firstOwnBook(rec.spell, ctx)
    if book then ns.SourceTip.show(owner, book) else ns.SourceTip.hide() end
  end
end

-- 按 Shift 刷新用：沒有遊戲資料（沒有成品也沒有法術）的拆解 tooltip，RefreshData 只會清空，改成整個重畫
function Window.refreshTree(tooltip)
  if tree.owner and not tree.native and tooltip.GetOwner and tooltip:GetOwner() == tree.owner then
    showTree(tree.owner, tree.rid, tree.opts)
    return true
  end
  return false
end

local function hideTree()
  tree.owner = nil
  if ns.SourceTip then ns.SourceTip.hide() end
  if GameTooltip then GameTooltip:Hide() end
end
Window._hideTree = hideTree
Window.showTree = showTree

local function iconOf(rid)
  local rec = ns.Data.recipes[rid]
  if rec.item and C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(rec.item) end
  if rec.spell and C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(rec.spell) end
  return 134400
end

local function firstLayer(rid) return ns.Format.firstLayer(rid, ns.Names) end
Window.recipeIcon, Window.recipeFirstLayer = iconOf, firstLayer

local ROW_H = 36
local TEXT_W = 600 -- 名稱、材料、樹的文字寬度；超過自動換行（實測：長材料超出視窗）
local NAME_W_SRC = 470 -- 永恆：名稱縮短，右側留給取得方式標籤與技能顏色圓點（不換行，名稱優先）
local TAG_COLORS = { auto = { 0.8, 0.8, 0.8 }, book = { 0.4, 0.7, 1 }, trainerOk = { 1, 0.82, 0 }, trainer = GREY }
local DOT_COLORS = { o = { 1, 0.5, 0.25 }, y = { 1, 1, 0 }, g = { 0.25, 0.75, 0.25 }, x = { 0.5, 0.5, 0.5 } }
local READY_CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"
Window.TAG_COLORS, Window.DOT_COLORS = TAG_COLORS, DOT_COLORS

-- 清單的取得方式標籤只在永恆（有 ns.Source）時啟用，正式版整列維持原樣；沒有來源資料時 Source.kind 回 nil，不畫標籤與圓點
local function sourceOn()
  return ns.Source ~= nil and ns.Flavor.isForever() and ns.Data ~= nil and ns.Data.meta ~= nil and ns.Data.meta.sourcesGenerated ~= nil
end

-- 訓練師快取 → 法術 id 集合。只收十進位數字字串的鍵 → { [法術id] = 學費 | true }；
-- 非數字鍵（例："名稱|等級"）逐筆略過（寧可不確認，也不誤判）；一筆都沒有回 nil。
-- 實際鍵格式待使用者遊戲內 SavedVariables 確認，要調整只改這一個函式。
function Window.trainerSpellSet(professionId)
  local prof = SkillsItemsGuideDB and SkillsItemsGuideDB.trainer and SkillsItemsGuideDB.trainer.prof
  local entry = prof and prof[tostring(professionId)]
  local spells = entry and entry.spells
  if type(spells) ~= "table" then return nil end
  local set, n = {}, 0
  for k, row in pairs(spells) do
    if type(k) == "string" and k:match("^%d+$") then -- 非數字鍵逐筆略過，不連累其他法術
      set[tonumber(k)] = (type(row) == "table" and row.cost) or true
      n = n + 1
    end
  end
  if n == 0 then return nil end
  return set
end

-- 訓練師快取 → { [法術id] = 學會所需技能 }（skill > 1 才收；0/1 在快取與資料表裡都是「不知道」）；沒有回 nil
function Window.trainerSkillSet(professionId)
  local prof = SkillsItemsGuideDB and SkillsItemsGuideDB.trainer and SkillsItemsGuideDB.trainer.prof
  local entry = prof and prof[tostring(professionId)]
  local spells = entry and entry.spells
  if type(spells) ~= "table" then return nil end
  local set, n = {}, 0
  for k, row in pairs(spells) do
    if type(k) == "string" and k:match("^%d+$") and type(row) == "table"
        and type(row.skill) == "number" and row.skill > 1 then
      set[tonumber(k)] = row.skill
      n = n + 1
    end
  end
  if n == 0 then return nil end
  return set
end

-- 角色目前某專業的技能點數；沒學這個專業回 nil
function Window.playerSkill(professionId)
  if not (GetProfessions and GetProfessionInfo) then return nil end
  local list = { GetProfessions() }
  for i = 1, 6 do
    local idx = list[i]
    if idx then
      local _, _, skillLevel, _, _, _, skillLine = GetProfessionInfo(idx)
      if skillLine == professionId then return skillLevel end
    end
  end
  return nil
end

local function playerSide()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end

-- 一個配方的來源判定情境（每個專業每次繪製只建一次，清單標籤與 tooltip 共用）；沒有來源功能或沒有法術回 nil
local function sourceCtx(rid, cache)
  if not sourceOn() then return nil end
  local rec = ns.Data.recipes[rid]
  if not (rec and rec.spell) then return nil end
  local p = rec.p
  local c = cache[p]
  if not c then
    c = { ctx = { side = playerSide(), profSkill = Window.playerSkill(p), trainerSpells = Window.trainerSpellSet(p), trainerSkills = Window.trainerSkillSet(p), names = ns.Names,
             profName = ns.Names and ns.Names.prof and ns.Names.prof(p) or nil } }
    cache[p] = c
  end
  return c.ctx
end

-- 一個配方的清單標籤資訊：{ kind, text, color, tick, dot } 或 nil
local function sourceInfo(rid, cache)
  local ctx = sourceCtx(rid, cache)
  if not ctx then return nil end
  local spell = ns.Data.recipes[rid].spell
  local kind = ns.Source.kind(spell, ctx)
  if not kind then return nil end
  local text = kind == "auto" and L.SRC_TAG_AUTO or kind == "book" and L.SRC_TAG_BOOK or L.SRC_TAG_TRAINER
  return { kind = kind, text = text, color = TAG_COLORS[kind], tick = kind == "trainerOk",
    dot = ns.Source.color(spell, ctx.profSkill, ctx) }
end
local rows = {}
Window._rows = rows
local function textH(fs, fallbackLines)
  if fs.GetStringHeight then return fs:GetStringHeight() end
  return 14 * fallbackLines
end

local function getRow(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Button", nil, ui.content)
  r:SetSize(660, ROW_H)
  r.icon = CreateFrame("Button", nil, r)
  r.icon:SetSize(28, 28)
  r.icon:SetPoint("TOPLEFT", 2, -4)
  r.tex = r.icon:CreateTexture(nil, "ARTWORK")
  r.tex:SetAllPoints()
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", 36, -4)
  r.name:SetJustifyH("LEFT")
  r.name:SetWidth(sourceOn() and NAME_W_SRC or TEXT_W)
  if sourceOn() then r.name:SetWordWrap(false) end
  r.dot = r:CreateTexture(nil, "OVERLAY") -- 色塊而非「●」字元：拉丁字型不保證有該字形
  r.dot:SetSize(8, 8)
  r.dot:SetPoint("TOPLEFT", 36 + NAME_W_SRC + 4, -9)
  r.dot:Hide()
  r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.tag:SetPoint("TOPRIGHT", -30, -8)
  r.tag:SetJustifyH("RIGHT")
  r.tick = r:CreateTexture(nil, "OVERLAY")
  r.tick:SetSize(12, 12)
  r.tick:SetPoint("RIGHT", r.tag, "LEFT", -2, 0)
  r.tick:SetTexture(READY_CHECK)
  r.tick:Hide()
  r.mats = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.mats:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
  r.mats:SetJustifyH("LEFT")
  r.mats:SetWidth(TEXT_W)
  r.mats:SetWordWrap(true)
  r.toggle = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.toggle:SetSize(24, 20)
  r.toggle:SetPoint("TOPRIGHT", -2, -6)
  r.tree = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.tree:SetPoint("TOPLEFT", r.mats, "BOTTOMLEFT", 0, -2)
  r.tree:SetJustifyH("LEFT")
  r.tree:SetWidth(TEXT_W)
  r.tree:SetWordWrap(true)
  r.icon:SetScript("OnEnter", function(self) showTree(self, r.rid, { withSource = r.srcCtx }) end)
  r.icon:SetScript("OnLeave", hideTree)
  r.icon:SetScript("OnClick", function()
    local rec = ns.Data.recipes[r.rid]
    if rec.item then Window.modifiedItemClick(rec.item) end
  end)
  r.toggle:SetScript("OnClick", function()
    S.expanded[r.rid] = not S.expanded[r.rid] or nil
    Window.render()
  end)
  rows[i] = r
  return r
end

function Window.render(resetScroll)
  if not frame then return end
  ui.header:SetText(S.header or "")
  ui.hint:SetText(Window.hintText())
  ui.notOpened:SetText(Window.notOpenedText())
  ui.clear:SetShown(S.material ~= nil or S.recipe ~= nil)
  ui.back:SetShown(S.from ~= nil)
  ui.empty:SetText(S.empty or "")
  local y = 0
  local srcCache = {}
  S.rendered = math.min(#S.list, MAX_ROWS)
  S.overflow = #S.list - S.rendered
  for i = 1, S.rendered do
    local rid = S.list[i]
    local r = getRow(i)
    r.rid = rid
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, -y)
    r.tex:SetTexture(iconOf(rid))
    local c = Window.recipeColor(rid)
    r.name:SetText(titleOf(rid))
    r.name:SetTextColor(c[1], c[2], c[3])
    local lc = isLearned(rid) and LEARNED or GREY
    r.mats:SetText(firstLayer(rid))
    r.mats:SetTextColor(lc[1], lc[2], lc[3])
    local info = sourceInfo(rid, srcCache)
    r.srcCtx = sourceCtx(rid, srcCache)
    r.src = info
    r.tag:SetText(info and info.text or "")
    if info then r.tag:SetTextColor(info.color[1], info.color[2], info.color[3]) end
    r.tag:SetShown(info ~= nil)
    r.tick:SetShown(info ~= nil and info.tick)
    local dc = info and info.dot and DOT_COLORS[info.dot]
    if dc then r.dot:SetColorTexture(dc[1], dc[2], dc[3], 1) end
    r.dot:SetShown(dc ~= nil)
    r.toggle:SetText(S.expanded[rid] and "-" or "+")
    local h = math.max(ROW_H, 8 + textH(r.name, 1) + textH(r.mats, 1))
    if S.expanded[rid] then
      local tt = ns.Format.treeTooltip(ns.Breakdown.build(rid, S.qty, knownSet()), ns.Names, 999)
      local t = {}
      for k = 2, #tt.lines do t[#t + 1] = tt.lines[k].text end
      r.tree:SetText(table.concat(t, "\n"))
      r.tree:Show()
      h = h + textH(r.tree, #t) + 4
    else
      r.tree:Hide()
    end
    r:SetHeight(h)
    r:Show()
    y = y + h
  end
  for i = S.rendered + 1, #rows do rows[i]:Hide() end
  -- 超過上限：提示放在清單最後一列之後（不要蓋在第一列上）
  S.footer = S.overflow > 0 and string.format(L.OVERFLOW_FMT, S.overflow) or nil
  ui.footer:ClearAllPoints()
  ui.footer:SetPoint("TOPLEFT", 4, -y - 6)
  ui.footer:SetText(S.footer or "")
  if S.footer then y = y + 26 end
  ui.content:SetHeight(math.max(y, 1))
  if resetScroll then ui.scroll:SetVerticalScroll(0) end
end

local function build()
  frame = CreateFrame("Frame", "SkillsItemsGuideFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(920, 640) -- 使用者實測要求放大（原 700×500）
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  tinsert(UISpecialFrames, "SkillsItemsGuideFrame")
  ui = {}
  local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if not frame.TitleText then title:SetPoint("TOP", 0, -5) end
  L.bind(title, "ADDON_TITLE")
  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(18, 18)
  icon:SetPoint("RIGHT", title, "LEFT", -4, 0)
  icon:SetTexture("Interface\\AddOns\\SkillsItemsGuide\\Media\\icon")

  ui.tabs = {}
  ui.tabProf = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  ui.tabProf:SetSize(100, 22)
  ui.tabProf:SetPoint("TOPLEFT", 12, -28)
  L.bind(ui.tabProf, "TAB_PROF")
  ui.tabProf:SetScript("OnClick", function() Window.setTab("prof") end)
  ui.tabs.prof = ui.tabProf

  ui.prof = CreateFrame("Frame", nil, frame)
  ui.prof:SetPoint("TOPLEFT", 8, -56)
  ui.prof:SetPoint("BOTTOMRIGHT", -8, 8)
  Window.tabs = { prof = ui.prof }
  -- 其他分頁（職業技能、物品、法術）依註冊順序排在「專業」之後；正式版 TOC 不載入那些檔，自然只有專業
  local prev = ui.tabProf
  for _, t in ipairs(registered) do
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(100, 22)
    b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    L.bind(b, t.label) -- Locale key 或函式：存檔設定在 ADDON_LOADED 才讀得到，建立時才取字
    b:SetScript("OnClick", function() Window.setTab(t.key) end)
    ui.tabs[t.key] = b
    prev = b
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", 8, -56)
    p:SetPoint("BOTTOMRIGHT", -8, 8)
    p:Hide()
    Window.tabs[t.key] = p
  end

  -- 左：搜尋與專業
  ui.search = CreateFrame("EditBox", nil, ui.prof, "InputBoxTemplate")
  ui.search:SetSize(150, 20)
  ui.search:SetPoint("TOPLEFT", 10, -4)
  releaseFocusOnHide(ui.search)
  ui.search:SetScript("OnTextChanged", function(self) if not S.suppress then Window.setSearch(self:GetText()) end end)
  local profIds = {}
  for id in pairs(ns.Data.professions or {}) do profIds[#profIds + 1] = id end
  table.sort(profIds)
  for i, id in ipairs(profIds) do
    local b = CreateFrame("Button", nil, ui.prof, "UIPanelButtonTemplate")
    b:SetSize(150, 20)
    b:SetPoint("TOPLEFT", 6, -30 - (i - 1) * 22)
    L.bind(b, function() return L.prof(id) end)
    b:SetScript("OnClick", function() Window.setProf(id) end)
  end

  -- 右：標題列、數量、提示、清單
  ui.header = ui.prof:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ui.header:SetWidth(300)
  ui.header:SetWordWrap(false)
  ui.header:SetPoint("TOPLEFT", 172, -6)
  ui.clear = CreateFrame("Button", nil, ui.prof, "UIPanelButtonTemplate")
  ui.clear:SetSize(60, 20)
  ui.clear:SetPoint("TOPRIGHT", -130, -2)
  L.bind(ui.clear, "CLEAR")
  ui.clear:SetScript("OnClick", function() Window.setProf(S.prof) end)
  -- 從物品／法術分頁跳過來時，回到原分頁（該分頁的狀態保留在自己的模組裡）
  ui.back = CreateFrame("Button", nil, ui.prof, "UIPanelButtonTemplate")
  ui.back:SetSize(70, 20)
  ui.back:SetPoint("RIGHT", ui.clear, "LEFT", -4, 0)
  L.bind(ui.back, "BACK")
  ui.back:SetScript("OnClick", function() Window.back() end)
  ui.qty = CreateFrame("EditBox", nil, ui.prof, "InputBoxTemplate")
  ui.qty:SetSize(40, 20)
  ui.qty:SetPoint("TOPRIGHT", -10, -2)
  ui.qty:SetNumeric(true)
  ui.qty:SetMaxLetters(3)
  releaseFocusOnHide(ui.qty)
  ui.qty:SetText("1")
  ui.qty:SetScript("OnTextChanged", function(self) S.qty = Window.clampQty(self:GetText()); Window.render() end)
  ui.qtyLabel = ui.prof:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.qtyLabel:SetPoint("RIGHT", ui.qty, "LEFT", -6, 0)
  L.bind(ui.qtyLabel, "QUANTITY")
  ui.hint = ui.prof:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.hint:SetPoint("TOPLEFT", 172, -28)
  L.bind(ui.hint, "LIST_HINT")
  ui.notOpened = ui.prof:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ui.notOpened:SetPoint("TOPLEFT", 172, -42)
  ui.notOpened:SetWidth(700)
  ui.notOpened:SetJustifyH("LEFT")
  ui.notOpened:SetWordWrap(true)
  ui.scroll = CreateFrame("ScrollFrame", nil, ui.prof, "UIPanelScrollFrameTemplate")
  ui.scroll:SetPoint("TOPLEFT", 168, -60)
  ui.scroll:SetPoint("BOTTOMRIGHT", -28, 34)
  ui.content = CreateFrame("Frame", nil, ui.scroll)
  ui.content:SetSize(670, 1)
  ui.scroll:SetScrollChild(ui.content)
  ui.footer = ui.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.empty = ui.prof:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.empty:SetPoint("TOPLEFT", 176, -70)
  ui.version = ui.prof:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.version:SetPoint("BOTTOMRIGHT", -10, 10)
  L.bind(ui.version, Window.footerText)

  frame:SetScript("OnHide", function()
    ui.search:ClearFocus(); ui.qty:ClearFocus()
    if ns.SourceTip then ns.SourceTip.hide() end
    if Window.onHide then Window.onHide() end
  end)
  for _, t in ipairs(registered) do t.build(Window.tabs[t.key]) end
end

-- 分頁註冊：label 是 Locale key（或回傳字串的函式），按鈕文字跟著顯示語言；build(panel) 在視窗建立時呼叫一次，onShow() 每次切到該分頁時呼叫，
-- refresh()（可省略）在物品名稱載入回來時呼叫，不重置捲動
function Window.registerTab(key, label, buildFn, onShow, refresh)
  registered[#registered + 1] = { key = key, label = label, build = buildFn, onShow = onShow, refresh = refresh }
  byKey[key] = registered[#registered]
end

function Window.setTab(tab)
  if tab ~= "prof" and not byKey[tab] then tab = "prof" end
  S.tab = tab
  if not frame then return end
  for key, p in pairs(Window.tabs) do p:SetShown(key == tab) end
  local t = byKey[tab]
  if t then
    if t.onShow then t.onShow() end
  else
    recompute(); Window.render() -- 離開期間名稱可能已載入回來（不重置捲動）
  end
end

-- 「← 返回」：回到跳過來的分頁，專業分頁回到該專業清單
function Window.back()
  local from = S.from
  leaveRecipe()
  if from then Window.setTab(from) end
end

-- opts = { tab=分頁, material=itemId, prof=profId, recipe=rid, from=返回的分頁 }
function Window.open(opts)
  opts = opts or {}
  if not frame then build() end
  S.material = opts.material
  leaveRecipe()
  if opts.recipe then
    S.recipe, S.from = opts.recipe, opts.from
    S.material, S.prof = nil, ns.Data.recipes[opts.recipe].p
    if not S.expanded[opts.recipe] then S.expanded[opts.recipe], S.autoExpanded = true, opts.recipe end
  end
  if opts.prof then S.prof = opts.prof end
  S.search = nil
  if not S.prof and not S.material then S.prof = Window.defaultProf() end
  -- 清空搜尋框會觸發 OnTextChanged；先擋掉，最後只重算一次（切到專業分頁時由 setTab 重算）
  S.suppress = true
  if ui.search then ui.search:SetText("") end
  S.suppress = false
  frame:Show()
  Window.setTab(opts.recipe and "prof" or opts.tab or "prof")
  Window.render(true)
end

function Window.hintText() return L.LIST_HINT end

-- 視窗底部：插件版本、作者、回報信箱、資料版本
function Window.footerText()
  local get = C_AddOns and C_AddOns.GetAddOnMetadata
  local ver = get and get("SkillsItemsGuide", "Version") or "?"
  return string.format(L.FOOTER_FMT, ver, "AugustusW", "support@augustusw.com",
    tostring(ns.Data.meta and ns.Data.meta.profVersion))
end

-- 學了但還沒開過視窗的專業（獨立一行，避免超出視窗寬度）
function Window.notOpenedText()
  local char = SkillsItemsGuideCharDB or {}
  local missing = {}
  for p in pairs(char.professions or {}) do
    local id = tonumber(p)
    if id and not (char.opened or {})[p] and ns.Data.professions and ns.Data.professions[id] then
      missing[#missing + 1] = L.prof(id)
    end
  end
  table.sort(missing)
  if #missing == 0 then return "" end
  return string.format(L.NOT_OPENED_FMT, L.join(missing))
end

-- 預設專業：角色學的第一個（依 id），沒有就第一個有資料的專業
function Window.defaultProf()
  local mine = {}
  for k in pairs((SkillsItemsGuideCharDB or {}).professions or {}) do
    local n = tonumber(k)
    if n and ns.Data.professions and ns.Data.professions[n] then mine[#mine + 1] = n end
  end
  if #mine == 0 then for id in pairs(ns.Data.professions or {}) do mine[#mine + 1] = id end end
  table.sort(mine)
  return mine[1]
end

-- 名稱重試的下一輪：視窗開著就重算（會觸發還沒回來的物品再請求一次）
function Window.refreshIfShown()
  if not (frame and frame:IsShown()) then return end
  local t = byKey[S.tab]
  if t then
    if t.refresh then t.refresh() end
  else
    recompute(); Window.render()
  end
end

-- 語言切換：固定文字已由 L.rebind 重套；這裡把每個分頁算出來的字（標題、清單、詳情）都重算，
-- 切到別的分頁時不會先看到舊語言（職業技能分頁自己處理）
function Window.onLangChanged()
  if not frame then return end
  recompute(); Window.render()
  for _, t in ipairs(registered) do if t.refresh then t.refresh() end end
end
table.insert(ns.onLangChanged, Window.onLangChanged)

function Window.toggle()
  if frame and frame:IsShown() then frame:Hide() else Window.open({}) end
end

-- 名稱非同步載入：回來時刷新（保留捲動位置）
ns.onLoad = ns.onLoad or {}
table.insert(ns.onLoad, function()
  local f = CreateFrame("Frame")
  f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  -- 名稱一次會回來很多個：0.2 秒內合併成一次刷新（視窗與顯示中的 tooltip）
  local pending = false
  local function flush()
    pending = false
    Window.refreshIfShown()
    if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() and GameTooltip.RefreshData then GameTooltip:RefreshData() end
  end
  f:SetScript("OnEvent", function(_, _, itemId, success)
    if success == false then ns.Names.markFailed(itemId) end -- 失敗也走下面的合併刷新，搜尋狀態立刻更新
    if pending then return end
    pending = true
    if C_Timer and C_Timer.After then C_Timer.After(0.2, flush) else flush() end
  end)
  ns.registerSlash("SKILLSITEMSGUIDE", "/skillsitemsguide", Window.toggle)
  ns.registerSlash("SIG", "/sig", Window.toggle)
end)

-- 小地圖旁官方「插件收納」按鈕（Addon Compartment）：TOC 的 AddonCompartmentFunc* 指名這三個全域函式
-- 使用者 2026-11-09：永恆與正式版同位置；不另做小地圖圓形按鈕
function SkillsItemsGuide_OnAddonCompartmentClick() Window.toggle() end

function SkillsItemsGuide_OnAddonCompartmentEnter(_, button)
  if not GameTooltip then return end
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:ClearLines()
  GameTooltip:AddLine(L.ADDON_TITLE)
  GameTooltip:AddLine(L.COMPARTMENT_HINT, GREY[1], GREY[2], GREY[3], true)
  GameTooltip:Show()
end

function SkillsItemsGuide_OnAddonCompartmentLeave()
  if GameTooltip then GameTooltip:Hide() end
end

function Window._ui() return ui end -- 測試用
