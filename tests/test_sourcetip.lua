-- SourceTip.lua：並排的原生配方書 tooltip
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")

-- placement 純函式
do
  H.reset({ locale = "zhTW" })
  local ns = H.load({ "SourceTip.lua" })
  local P = ns.SourceTip.placement
  H.eq(P(100, 400, 300, 1920), "RIGHT", "右邊放得下放右邊")
  H.eq(P(100, 400, 300, 700), "RIGHT", "剛好貼齊右緣仍放右邊")
  H.eq(P(900, 1700, 300, 1920), "LEFT", "右緣放不下翻到左邊")
  H.eq(P(100, 800, 900, 1000), "RIGHT", "兩邊都放不下取空間較大那邊（右）")
  H.eq(P(500, 900, 900, 1000), "LEFT", "兩邊都放不下取空間較大那邊（左）")
end

-- placeAround 純函式：spans = { {left,right}, ... }（第 1 個是主 tooltip，其餘是顯示中的比較 tooltip）
do
  H.reset({ locale = "zhTW" })
  local ns = H.load({ "SourceTip.lua" })
  local PA = ns.SourceTip.placeAround
  local side, idx = PA({ { 100, 400 } }, 300, 1920)
  H.eq(side, "RIGHT", "沒有比較 tooltip：舊行為放右")
  H.eq(idx, 1, "錨在主 tooltip")
  side, idx = PA({ { 1700, 1900 } }, 300, 1920)
  H.eq(side, "LEFT", "沒有比較 tooltip：放不下翻左")
  H.eq(idx, 1, "翻左錨主 tooltip")
  side, idx = PA({ { 100, 400 }, { 400, 700 } }, 300, 1920)
  H.eq(side, "RIGHT", "比較在右、仍放得下：放比較的右邊")
  H.eq(idx, 2, "錨在比較 tooltip")
  side, idx = PA({ { 100, 400 }, { 400, 700 }, { 700, 1000 } }, 300, 1920)
  H.eq(side, "RIGHT", "兩個比較 tooltip")
  H.eq(idx, 3, "錨在最右的那個")
  side, idx = PA({ { 1000, 1300 }, { 1300, 1600 } }, 400, 1920)
  H.eq(side, "LEFT", "比較在右、右邊放不下：放主 tooltip 左邊")
  H.eq(idx, 1, "翻左錨最左的（主 tooltip）")
  side, idx = PA({ { 1000, 1300 }, { 700, 1000 } }, 400, 1920)
  H.eq(side, "RIGHT", "比較在左（主在右）、右邊放得下：錨主 tooltip")
  H.eq(idx, 1, "最右的是主 tooltip")
  side, idx = PA({ { 1000, 1300 }, { 700, 1000 } }, 800, 1500)
  H.eq(side, "LEFT", "右邊放不下、左邊也要換算最左緣")
  H.eq(idx, 2, "翻左錨最左的比較 tooltip")
end

local mainTip, postCalls
local function boot(factionGroup)
  postCalls = {}
  mainTip = { _owner = nil, _left = 100, _right = 400, shown = false, items = 0 }
  local lines = {}
  mainTip.lines = lines
  function mainTip:SetOwner(o) self._owner = o end
  function mainTip:GetOwner() return self._owner end
  function mainTip:ClearLines() end
  function mainTip:AddLine(t) lines[#lines + 1] = t end
  function mainTip:Show() self.shown = true end
  function mainTip:IsShown() return self.shown end
  function mainTip:GetLeft() return self._left end
  function mainTip:GetRight() return self._right end
  function mainTip:SetItemByID() end
  function mainTip:HookScript(ev, fn) self._hooks = self._hooks or {}; self._hooks[ev] = fn end
  function mainTip:Hide() self.shown = false; if self._hooks and self._hooks.OnHide then self._hooks.OnHide(self) end end
  function mainTip:SetSpellByID() end
  H.reset({ locale = "zhTW", extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    GameTooltip = mainTip, hooksecurefunc = function() end,
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[kind] = fn end },
    Enum = { TooltipDataType = { Item = "ITEM", Spell = "SPELL" } },
    UnitFactionGroup = function() return factionGroup end,
    GetProfessions = function() return 1 end,
    GetProfessionInfo = function() return "裁縫", 0, 100, 300, 0, 0, 197 end,
  } })
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
  return ns
end

-- 只建一次、show 兩次不累加、hide、翻左
do
  local ns = boot("Alliance")
  H.check(_G.SkillsItemsGuideSourceTip == nil, "載入時不建 frame")
  local S = ns.SourceTip
  local owner = {}
  S.show(owner, 900)
  local f = _G.SkillsItemsGuideSourceTip
  H.check(f ~= nil, "第一次 show 建立 SkillsItemsGuideSourceTip")
  local function tipFrames()
    local n = 0
    for _, fr in ipairs(H.frames) do if fr._name == "SkillsItemsGuideSourceTip" then n = n + 1 end end
    return n
  end
  local before = tipFrames()
  S.show(owner, 901)
  H.eq(tipFrames(), before, "第二次 show 不新增 frame")
  H.eq(_G.SkillsItemsGuideSourceTip, f, "frame 沒被重建")
  H.eq(f._tipItem, 901, "第二次 show 換成新的書")
  H.check(f:IsShown(), "show 後可見")
  H.eq(f._points[1], "TOPLEFT", "右邊放得下：TOPLEFT 接主 tooltip 的 TOPRIGHT")
  H.eq(f._points[2], mainTip, "錨在主 tooltip")
  H.eq(f._points[3], "TOPRIGHT", "對到主 tooltip 右上角")
  H.eq(f._anchor, "ANCHOR_NONE", "ANCHOR_NONE 自己擺位置")
  mainTip._left, mainTip._right = 1700, 1900
  f._width = 300
  S.show(owner, 900)
  H.eq(f._points[1], "TOPRIGHT", "右緣放不下翻左：TOPRIGHT")
  H.eq(f._points[3], "TOPLEFT", "對到主 tooltip 左上角")
  S.hide()
  H.check(not f:IsShown(), "hide 後隱藏")
end

-- 內容定案後才擺位置；大小改變重算；主 tooltip 被別的路徑隱藏時一起收
do
  local ns = boot("Alliance")
  local S = ns.SourceTip
  UIParent._width = 1920 -- UIParent 座標空間的螢幕寬（實機沒有 Frame:GetScreenWidth，2026-11-22 /sigprobe）
  mainTip._left, mainTip._right = 1500, 1700
  S.show({}, 900) -- 此時寬度 0（未快取物品）→ 放得下右邊
  local f = _G.SkillsItemsGuideSourceTip
  H.eq(f._points[1], "TOPLEFT", "寬度 0 時先放右邊")
  f._width = 400 -- 物品資料載入後變寬
  f._scripts.OnSizeChanged(f, 400, 100)
  H.eq(f._points[1], "TOPRIGHT", "大小改變後重算：右緣放不下翻到左邊")
  f._width = 100
  f._scripts.OnSizeChanged(f, 100, 100)
  H.eq(f._points[1], "TOPLEFT", "變窄後又回到右邊")
  mainTip:Hide()
  H.check(not f:IsShown(), "主 tooltip 被 Hide（非 OnLeave）時並排 tooltip 一起隱藏")
  S.show({}, 900)
  S.show({}, 901)
  local hookCount = 0
  mainTip._hooks.OnHide = function() hookCount = hookCount + 1 end
  S.show({}, 902)
  mainTip._hooks.OnHide(mainTip)
  H.eq(hookCount, 1, "OnHide 只在第一次建立時掛一次（之後 show 不再掛）")
end

-- 主 tooltip 與側 tooltip 縮放不同：換算到同一座標空間再決定左右
do
  local ns = boot("Alliance")
  local S = ns.SourceTip
  UIParent._width = 1920 -- UIParent 座標空間的螢幕寬（實機沒有 Frame:GetScreenWidth，2026-11-22 /sigprobe）
  UIParent.GetEffectiveScale = function() return 1 end
  mainTip._left, mainTip._right = 900, 1000 -- 本身座標；縮放 2 倍 → UIParent 空間 1800~2000
  mainTip.GetEffectiveScale = function() return 2 end
  S.show({}, 900)
  local f = _G.SkillsItemsGuideSourceTip
  f.GetEffectiveScale = function() return 1 end
  f._width = 100
  S.show({}, 900)
  H.eq(f._points[1], "TOPRIGHT", "主 tooltip 放大 2 倍：實際右緣超出螢幕 → 翻左")
  mainTip.GetEffectiveScale = function() return 1 end
  S.show({}, 900)
  H.eq(f._points[1], "TOPLEFT", "同樣座標縮放 1 倍：放得下右邊")
  mainTip.GetEffectiveScale = nil
  f.GetEffectiveScale = nil
  S.show({}, 900)
  H.eq(f._points[1], "TOPLEFT", "沒有 GetEffectiveScale（或回傳非數字）：退回原本行為")
  f.GetEffectiveScale = function() return 3 end
  mainTip.GetEffectiveScale = function() return 1 end
  S.show({}, 900) -- 側 tooltip 寬 100 × 3 = 300：1000+300 仍放得下
  H.eq(f._points[1], "TOPLEFT", "側 tooltip 放大：寬度也換算（1300 < 1920）")
  mainTip._left, mainTip._right = 1500, 1700
  S.show({}, 900)
  H.eq(f._points[1], "TOPRIGHT", "側 tooltip 放大後 1700+300 > 1920 → 翻左")
end

-- 比較 tooltip（ShoppingTooltip1/2）：只算顯示中的；晚一格才出現時 OnShow 重新擺位
do
  local function shop(l, r)
    local t = { _left = l, _right = r, shown = true }
    function t:IsShown() return self.shown end
    function t:GetLeft() return self._left end
    function t:GetRight() return self._right end
    function t:HookScript(ev, fn) self._hooks = self._hooks or {}; self._hooks[ev] = fn; self._hookN = (self._hookN or 0) + 1 end
    return t
  end
  local ns = boot("Alliance")
  local S = ns.SourceTip
  UIParent._width = 1920
  mainTip._left, mainTip._right = 100, 400
  local s1, s2 = shop(400, 700), shop(700, 1000)
  _G.ShoppingTooltip1, _G.ShoppingTooltip2 = s1, s2
  S.show({}, 900)
  local f = _G.SkillsItemsGuideSourceTip
  H.eq(f._points[1], "TOPLEFT", "有比較 tooltip：放右邊")
  H.eq(f._points[2], s2, "錨在最右的比較 tooltip")
  H.eq(f._points[3], "TOPRIGHT", "對到比較 tooltip 右上角")
  s2.shown = false
  S.show({}, 900)
  H.eq(f._points[2], s1, "第二個比較 tooltip 沒顯示 → 忽略，錨第一個")
  s1.shown = false
  S.show({}, 900)
  H.eq(f._points[2], mainTip, "都沒顯示 → 回到主 tooltip")
  -- 晚一格出現：OnShow 重擺
  s1.shown = true
  H.check(s1._hooks and s1._hooks.OnShow, "比較 tooltip 掛了 OnShow")
  s1._hooks.OnShow(s1)
  H.eq(f._points[2], s1, "OnShow 後重擺到比較 tooltip 旁")
  H.eq(s1._hookN, 1, "只掛一次")
  S.show({}, 900)
  H.eq(s1._hookN, 1, "再 show 不重掛")
  -- 右邊放不下：放主 tooltip 左邊
  mainTip._left, mainTip._right, s1._left, s1._right = 800, 1100, 1100, 1400
  f._width = 600
  s1._hooks.OnShow(s1)
  H.eq(f._points[1], "TOPRIGHT", "右邊放不下翻左")
  H.eq(f._points[2], mainTip, "錨最左的（主 tooltip）")
  -- 側 tooltip 沒顯示時 OnShow 不動作
  S.hide()
  f._points = nil
  s1._hooks.OnShow(s1)
  H.eq(f._points, nil, "側 tooltip 隱藏時不擺位")
  _G.ShoppingTooltip1, _G.ShoppingTooltip2 = nil, nil
end

-- OnShow 當下比較 tooltip 還沒排版（沒座標）：立即擺一次，C_Timer.After(0) 之後再擺一次
do
  local ns = boot("Alliance")
  local S = ns.SourceTip
  UIParent._width = 1920
  mainTip._left, mainTip._right = 100, 400
  local s1 = { shown = false }
  function s1:IsShown() return self.shown end
  function s1:GetLeft() return self._left end
  function s1:GetRight() return self._right end
  function s1:HookScript(ev, fn) self._hooks = self._hooks or {}; self._hooks[ev] = fn end
  local deferred = {}
  _G.C_Timer = { After = function(_, fn) deferred[#deferred + 1] = fn end }
  _G.ShoppingTooltip1 = s1
  S.show({}, 900)
  local f = _G.SkillsItemsGuideSourceTip
  H.eq(f._points[2], mainTip, "比較 tooltip 未顯示：錨主 tooltip")
  s1.shown = true -- 顯示了，但還沒座標
  s1._hooks.OnShow(s1)
  H.eq(#deferred, 1, "OnShow 排了一個 C_Timer.After(0)")
  H.eq(f._points[2], mainTip, "立即那次沒座標：仍錨主 tooltip，不報錯")
  s1._left, s1._right = 400, 700 -- 排版完成
  deferred[1]()
  H.eq(f._points[2], s1, "延後那次：避開比較 tooltip")
  _G.C_Timer = nil
  s1._hooks.OnShow(s1) -- 沒有 C_Timer 也不報錯
  _G.ShoppingTooltip1 = nil
end

-- 視窗隱藏時收掉並排 tooltip
do
  local ns = boot("Alliance")
  ns.Window.open({ prof = 197 })
  ns.SourceTip.show({}, 900)
  local f = _G.SkillsItemsGuideSourceTip
  H.check(f:IsShown(), "前置：顯示中")
  local win
  for _, fr in ipairs(H.frames) do if fr._scripts.OnHide and fr._shown and fr ~= f then win = fr end end
  -- 視窗是第一個有 OnHide 並可見的主框架
  for _, fr in ipairs(H.frames) do if fr._scripts.OnHide and fr._shown and fr ~= f and fr._kind == "Frame" then win = fr break end end
  win:Hide()
  H.check(not f:IsShown(), "視窗隱藏時並排 tooltip 也隱藏")
end

-- Window 整合：選書、hideTree、只有列圖示帶 withSource、重繪不累加
do
  local ns = boot("Alliance")
  local D = ns.Data
  ns.Window.open({ prof = 197 })
  local list = ns.Window.state().list
  local rid = list[1]
  local sp = D.recipes[rid].spell
  D.meta.sourcesGenerated = "2026-11-22"
  D.sources = { [sp] = { src = "book", books = { { item = 900, side = "H" }, { item = 901, side = "A" }, { item = 902 } } } }
  D.sourceNamesByLocale = { zhTW = { quest = {}, area = {}, faction = {} }, enUS = { quest = {}, area = {}, faction = {} } }
  ns.Source.init()
  ns.Window.render()
  local icon = ns.Window._rows[1].icon
  icon._scripts.OnEnter(icon)
  local f = _G.SkillsItemsGuideSourceTip
  H.check(f and f:IsShown(), "列圖示 OnEnter 顯示並排 tooltip")
  H.eq(f._tipItem, 901, "取自己陣營（聯盟）第一本，不是排在前面的部落書")
  icon._scripts.OnEnter(icon)
  H.eq(_G.SkillsItemsGuideSourceTip, f, "再進一次仍是同一個 frame")
  H.eq(f._tipSets, 2, "每次 OnEnter 只設一次物品（不累加）")
  -- Shift 刷新（RefreshData 路徑不重建 frame）：此處以 refreshTree 模擬非原生路徑
  H.check(mainTip.shown and f:IsShown(), "兩個 tooltip 都在")
  icon._scripts.OnLeave(icon)
  H.check(not f:IsShown(), "hideTree 隱藏並排 tooltip")
  H.check(not mainTip.shown, "主 tooltip 也隱藏")
  -- 沒有 withSource（DbTab 呼叫）→ 不顯示
  ns.Window.showTree({}, rid)
  H.check(not f:IsShown(), "沒帶 withSource 不顯示並排 tooltip")
  -- 另一陣營書：部落玩家選到 902（中立）？聯盟只有部落書 → 不顯示
  D.sources[sp].books = { { item = 900, side = "H" } }
  icon._scripts.OnEnter(icon)
  H.check(not f:IsShown(), "只有另一陣營的書 → 不顯示")
  D.sources[sp] = { src = "auto" }
  icon._scripts.OnEnter(icon)
  H.check(not f:IsShown(), "自動學會 → 不顯示")
  -- 並排 tooltip 本身觸發 post-call：不加數量行與拆解樹
  D.sources[sp] = { src = "book", books = { { item = 901, side = "A" } } }
  icon._scripts.OnEnter(icon)
  H.check(f:IsShown(), "又有書了")
  f._tipLines = {}
  f._owner = icon -- 與主 tooltip 同一個 owner：addTreeIfOwned 若沒擋就會加拆解樹
  postCalls.ITEM(f, { id = 2589 })
  H.eq(#f._tipLines, 0, "並排 tooltip 上 Item post-call 不加任何行")
  postCalls.SPELL(f, {})
  H.eq(#f._tipLines, 0, "Spell post-call 也不加")
  local before = #mainTip.lines
  postCalls.ITEM(mainTip, { id = 2589 })
  H.check(#mainTip.lines > before, "主 tooltip 的 post-call 照常加拆解樹")
end

-- 部落玩家：自己陣營第一本是部落書
do
  local ns = boot("Horde")
  local D = ns.Data
  ns.Window.open({ prof = 197 })
  local rid = ns.Window.state().list[1]
  local sp = D.recipes[rid].spell
  D.meta.sourcesGenerated = "2026-11-22"
  D.sources = { [sp] = { src = "book", books = { { item = 901, side = "A" }, { item = 900, side = "H" } } } }
  D.sourceNamesByLocale = { zhTW = { quest = {}, area = {}, faction = {} }, enUS = { quest = {}, area = {}, faction = {} } }
  ns.Source.init()
  ns.Window.render()
  local icon = ns.Window._rows[1].icon
  icon._scripts.OnEnter(icon)
  H.eq(_G.SkillsItemsGuideSourceTip._tipItem, 900, "部落玩家取部落書")
end

-- 正式版（無 SourceTip／Source）不報錯、不建 frame
do
  H.reset({ locale = "zhTW" })
  local ns = H.load({ "Locale.lua", "Flavor.lua", "Source.lua" })
  H.eq(ns.Source.firstOwnBook(1, {}), nil, "沒有資料 firstOwnBook 為 nil")
end
