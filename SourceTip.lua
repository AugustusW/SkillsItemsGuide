-- 並排的原生配方書 tooltip（只進永恆 TOC）：游標停在專業清單配方圖示時，
-- 在主 tooltip 旁邊顯示自己陣營第一本配方書的遊戲原生物品 tooltip。
-- SourceTip.show(owner, itemId)／SourceTip.hide()／SourceTip.placement(mainLeft, mainRight, width, screenW) -> "RIGHT"|"LEFT"
-- 位置在內容定案後決定（Show 之後，且側 tooltip 大小改變時重算，涵蓋未快取物品的非同步載入）
-- SourceTip.isSourceTip(tooltip)：Tooltip.lua 的 post-call 用來跳過這個 tooltip（不加數量行與拆解樹）
local _, ns = ...
local SourceTip = {}
ns.SourceTip = SourceTip

local frame, hooked
local COMPARE = { "ShoppingTooltip1", "ShoppingTooltip2" }
local compareHooked = {}

-- 右邊放得下就放右邊；放不下且左邊放得下（或左邊空間較大）才翻到左邊
function SourceTip.placement(mainLeft, mainRight, width, screenW)
  if mainRight + width <= screenW then return "RIGHT" end
  if mainLeft - width >= 0 then return "LEFT" end
  return (screenW - mainRight) >= mainLeft and "RIGHT" or "LEFT"
end

function SourceTip.isSourceTip(tooltip)
  return frame ~= nil and tooltip == frame
end

-- spans = { {left, right}, ... }：第 1 個是主 tooltip，其餘是顯示中的比較 tooltip（皆已在 UIParent 座標空間）。
-- 整段佔用區間 = 最左到最右；回傳 side（"RIGHT"|"LEFT"）與要錨定的 span 序號（右邊＝最右那個、左邊＝最左那個）
function SourceTip.placeAround(spans, width, screenW)
  local minI, maxI = 1, 1
  for i, sp in ipairs(spans) do
    if sp[1] < spans[minI][1] then minI = i end
    if sp[2] > spans[maxI][2] then maxI = i end
  end
  local side = SourceTip.placement(spans[minI][1], spans[maxI][2], width, screenW)
  return side, side == "RIGHT" and maxI or minI
end

-- 取 tooltip 在 UIParent 空間的 left/right；沒有座標（尚未排版）回 nil
local function spanOf(t, ui)
  if not (t and t.GetLeft and t.GetRight) then return nil end
  local l, r = t:GetLeft(), t:GetRight()
  if not (l and r) then return nil end
  if ui and t.GetEffectiveScale then
    local sc = t:GetEffectiveScale()
    if type(sc) == "number" then l, r = l * sc / ui, r * sc / ui end
  end
  return l, r
end

-- 依主 tooltip、顯示中的比較 tooltip 與側 tooltip 目前的位置與寬度（重新）擺放；沒有座標資料（尚未排版）時預設放右邊
local function place()
  local f = frame
  if not (f and f:IsShown() and GameTooltip) then return end
  local ui
  if UIParent and UIParent.GetEffectiveScale then
    ui = UIParent:GetEffectiveScale()
    if not (type(ui) == "number" and ui > 0) then ui = nil end
  end
  local frames, spans = { GameTooltip }, {}
  local ml, mr = spanOf(GameTooltip, ui)
  if ml then spans[1] = { ml, mr } end
  -- 遊戲在主 tooltip 右邊並排的裝備比較 tooltip（2026-11-22 實測會蓋住側 tooltip）；全域用 _G 取，不存在就略過
  if ml then
    for _, name in ipairs(COMPARE) do
      local t = _G[name]
      if t and t.IsShown and t:IsShown() then
        local l, r = spanOf(t, ui)
        if l then frames[#frames + 1] = t; spans[#spans + 1] = { l, r } end
      end
    end
  end
  local side, idx = "RIGHT", 1
  -- 螢幕寬取 UIParent:GetWidth()（UIParent 座標空間）；實機沒有 Frame:GetScreenWidth（2026-11-22 /sigprobe）
  if ml and UIParent and UIParent.GetWidth then
    local width = f:GetWidth() or 0
    if ui and f.GetEffectiveScale then
      local fs = f:GetEffectiveScale()
      if type(fs) == "number" then width = width * fs / ui end
    end
    side, idx = SourceTip.placeAround(spans, width, UIParent:GetWidth())
  end
  local anchor = frames[idx]
  f:ClearAllPoints()
  if side == "RIGHT" then
    f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
  else
    f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, 0)
  end
end

local function getFrame()
  if not frame then
    frame = CreateFrame("GameTooltip", "SkillsItemsGuideSourceTip", UIParent, "GameTooltipTemplate")
    if frame.HookScript then frame:HookScript("OnSizeChanged", place) end
  end
  -- 主 tooltip 被別的路徑隱藏（Esc、其他插件、OnLeave 沒觸發）時一起收掉；只掛一次
  if not hooked and GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnHide", function() SourceTip.hide() end)
    hooked = true
  end
  -- 比較 tooltip 可能晚一格（或按 Shift）才出現：OnShow 時重擺（place 內會檢查側 tooltip 是否顯示）
  for _, name in ipairs(COMPARE) do
    local t = _G[name]
    if t and t.HookScript and not compareHooked[t] then
      -- OnShow 當下比較 tooltip 可能還沒排版（沒座標）：立即擺一次，下一格再擺一次
      t:HookScript("OnShow", function()
        place()
        if C_Timer and C_Timer.After then C_Timer.After(0, place) end
      end)
      compareHooked[t] = true
    end
  end
  return frame
end

function SourceTip.show(owner, itemId)
  if not (itemId and GameTooltip) then return end
  local f = getFrame()
  if not f.SetItemByID then return end
  f:SetOwner(owner, "ANCHOR_NONE")
  f:ClearLines()
  f:SetItemByID(itemId)
  f:Show()
  place()
end

function SourceTip.hide()
  if frame then frame:Hide() end
end
