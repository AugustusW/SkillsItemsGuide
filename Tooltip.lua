-- 物品 tooltip：平常一行「專業（數量）」，按住 Shift 列有學專業的配方（最多 8 條）
local _, ns = ...
local L = ns.L

local Tooltip = {}
ns.Tooltip = Tooltip

local GREY = { 0.8, 0.8, 0.8 }
local LEARNED = { 0.25, 1, 0.25 }
local UNLEARNED = { 0.6, 0.6, 0.6 }
local HINT = { 0.5, 0.5, 0.5 }

local function isBagButton(owner)
  return type(owner) == "table" and owner.GetBagID ~= nil
end

function Tooltip.add(tooltip, itemId)
  if not itemId then return end
  local line = ns.Format.countsLine(itemId, ns.Names)
  if not line then return end
  tooltip:AddLine(line, GREY[1], GREY[2], GREY[3], true)
  if IsShiftKeyDown and IsShiftKeyDown() then
    local sl = ns.Format.shiftLines(itemId, SkillsItemsGuideCharDB or {}, ns.Names)
    for _, l in ipairs(sl.lines) do
      local c = l.learned and LEARNED or UNLEARNED
      tooltip:AddLine(l.text, c[1], c[2], c[3], true)
    end
    if sl.more > 0 then tooltip:AddLine(string.format(L.SHIFT_MORE, sl.more), HINT[1], HINT[2], HINT[3]) end
    if sl.empty then tooltip:AddLine(sl.empty, HINT[1], HINT[2], HINT[3]) end
    if sl.notOpened then tooltip:AddLine(sl.notOpened, HINT[1], HINT[2], HINT[3]) end
    if isBagButton(tooltip:GetOwner()) then tooltip:AddLine(L.OPEN_HINT, HINT[1], HINT[2], HINT[3]) end
  end
end

-- 游標停在物品上按／放 Shift 時重新產生 tooltip
local function refresh()
  local tt = GameTooltip
  if not (tt and tt:IsShown()) then return end
  if ns.Window and ns.Window.refreshTree and ns.Window.refreshTree(tt) then return end
  if tt.RefreshData then
    tt:RefreshData()
  else
    local owner = tt:GetOwner()
    local onEnter = owner and owner.GetScript and owner:GetScript("OnEnter")
    if onEnter then onEnter(owner) end
  end
end

ns.onLoad = ns.onLoad or {}
table.insert(ns.onLoad, function()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      Tooltip.add(tooltip, data and data.id)
      if ns.Window and ns.Window.addTreeIfOwned then ns.Window.addTreeIfOwned(tooltip) end
    end)
    if Enum.TooltipDataType.Spell then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip)
        if ns.Window and ns.Window.addTreeIfOwned then ns.Window.addTreeIfOwned(tooltip) end
      end)
    end
  end
  local f = CreateFrame("Frame")
  f:RegisterEvent("MODIFIER_STATE_CHANGED")
  f:SetScript("OnEvent", function(_, _, key)
    if key == "LSHIFT" or key == "RSHIFT" then refresh() end
  end)
end)
