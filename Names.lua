-- 遊戲內名稱：物品用 C_Item（未快取時回 nil 並請求載入）、配方用法術名、專業用語系表
local _, ns = ...

local Names = {}
ns.Names = Names

local requested = {}
function Names.item(id)
  if not id then return nil end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  -- 每個物品只請求一次，避免「請求 → 事件 → 重畫 → 再請求」循環
  if not name and not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
    requested[id] = true
    C_Item.RequestLoadItemDataByID(id)
  end
  return name
end

function Names.prof(id) return ns.L.prof(id) end

function Names.recipe(rid)
  local rec = ns.Data.recipes[rid]
  local sp = rec and rec.spell
  return sp and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sp) or nil
end
