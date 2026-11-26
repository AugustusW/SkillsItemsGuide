-- 物品 tooltip 的物品等級（永恆限定；正式版遊戲本身就有）。
-- 使用者 2026-11-24 選 B：插在名稱的下一行（正式版原生的位置），只限武器與護甲。
-- 做法：不搬動 tooltip 的每一行（售價的金錢圖示、比較框等是錨在固定行上的，搬了會錯位），
-- 而是把等級加在「名稱下一行」的開頭並換行：那一行變成兩行高，下面的行跟著往下排。
-- 那一行有右欄時，右欄前面也加換行，讓右欄留在原本內容的那一列。
local _, ns = ...
local L = ns.L

local ItemLevel = {}
ns.ItemLevel = ItemLevel

local GOLD = "|cffffd100"
local GEAR = { [2] = true, [4] = true } -- 物品類別：武器、護甲
local NAME_SCAN = 3                     -- 名稱最多在第幾行找（比較框第 1 行是「目前已裝備」）
local NO_LEVEL_SLOT = { INVTYPE_BODY = true, INVTYPE_TABARD = true } -- 襯衫、公會袍：等級都是 1，不顯示

-- 物品等級：遊戲回報的優先（tooltip 顯示中的物品一定有快取），沒有才用打包資料；不是武器或護甲回 nil
function ItemLevel.of(id)
  if not id then return nil end
  local name, il, cls, slot
  if C_Item and C_Item.GetItemInfo then
    local r = { C_Item.GetItemInfo(id) }
    name, il, slot, cls = r[1], r[4], r[9], r[12]
  end
  if slot and NO_LEVEL_SLOT[slot] then return nil end
  local rec = ns.DbIndex and ns.DbIndex.allItems()[id]
  if rec then
    il = (il and il > 0) and il or rec.il
    cls = cls or rec.c
    name = name or ns.DbIndex.clientName(id) -- 比對遊戲 tooltip 的名稱行：客戶端語言，跟顯示語言無關
  end
  if not (il and il > 0 and cls and GEAR[cls]) then return nil end
  return il, name
end

function ItemLevel.text(il) return GOLD .. string.format(L.TT_ILVL_FMT, il) .. "|r" end

local function line(base, side, i) return _G[base .. "Text" .. side .. i] end

function ItemLevel.add(tooltip, id)
  local il, name = ItemLevel.of(id)
  if not il or not tooltip.GetName then return end
  local base = tooltip:GetName()
  if not base then return end
  local n = tooltip.NumLines and tooltip:NumLines() or 0
  local text = ItemLevel.text(il)
  local at
  for i = 1, math.min(NAME_SCAN, n) do
    local fs = line(base, "Left", i)
    -- 包含比對：帶隨機後綴的綠裝（「…之猴」）名稱行比 GetItemInfo 的基底名長
    local t = fs and fs:GetText()
    if t and name and name ~= "" and t:find(name, 1, true) then at = i + 1; break end
  end
  if not at then return end
  if at > n then
    tooltip:AddLine(text)
    return
  end
  local left = line(base, "Left", at)
  if not left then return end
  local old = left:GetText() or ""
  if old:sub(1, #text) == text then return end -- 同一個 tooltip 已經加過
  left:SetText(text .. "\n" .. old)
  local right = line(base, "Right", at)
  local rt = right and right:GetText()
  local rightShown = right and (not right.IsShown or right:IsShown())
  if rightShown and rt and rt ~= "" then right:SetText("\n" .. rt) end
  -- 已經顯示中（例如 Shift 重新整理）才重算大小；還沒顯示的由遊戲自己的 Show 處理，
  -- 不替別的 addon 的隱藏掃描 tooltip 或尚未 SetOwner 的 tooltip 呼叫 Show
  if tooltip.IsShown and tooltip:IsShown() then tooltip:Show() end
end

-- 掛勾在 Tooltip.lua 的 Item post-call 裡呼叫 ItemLevel.add（同一個 post-call，不另外註冊）
