-- 使用者實測（2026-11-08）：完整視窗的配方圖示 tooltip 只有拆解樹，少了物品本身的資訊
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")

local calls
local function boot(withItemApi)
  calls = { lines = {} }
  local tip = {
    SetOwner = function() calls.owner = true end,
    ClearLines = function() calls.cleared = true end,
    AddLine = function(_, t) calls.lines[#calls.lines + 1] = t end,
    Show = function() calls.shown = true end, Hide = function() end, IsShown = function() return false end,
  }
  if withItemApi then
    tip.SetItemByID = function(_, id) calls.item = id; calls.lines[#calls.lines + 1] = "<item " .. id .. ">" end
    tip.SetSpellByID = function(_, id) calls.spell = id; calls.lines[#calls.lines + 1] = "<spell " .. id .. ">" end
  end
  H.reset({ locale = "zhTW", extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return "法術" end, GetSpellTexture = function() return 1 end },
    GameTooltip = tip,
    hooksecurefunc = function() end,
  } })
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end

local function firstRecipe(ns, withItem)
  for rid, rec in pairs(ns.Data.recipes) do
    if (rec.item ~= nil) == withItem and (withItem or rec.spell) and #(rec.r or {}) > 0 then return rid, rec end
  end
end

-- 有成品的配方：先放遊戲的物品 tooltip，再接拆解樹
local ns = boot(true)
local rid, rec = firstRecipe(ns, true)
ns.Window.showTree({}, rid)
H.eq(calls.item, rec.item, "配方圖示 tooltip 先顯示成品的物品資訊")
H.eq(calls.lines[1], "<item " .. rec.item .. ">", "物品資訊在最上面")
H.check(#calls.lines > 2, "下面接著拆解樹")
local dup = 0
for _, l in ipairs(calls.lines) do if l:find("名" .. rec.item, 1, true) == 1 then dup = dup + 1 end end
H.eq(dup, 0, "有物品資訊時不再重複一行成品名稱標題")
H.check(calls.shown, "最後 Show")

-- 沒有成品的配方（附魔等）：顯示法術說明
rid, rec = firstRecipe(ns, false)
if rid then
  ns.Window.showTree({}, rid)
  H.eq(calls.spell, rec.spell, "沒有成品的配方顯示法術說明")
end

-- client 沒有 SetItemByID（API 不存在）：退回原本只有拆解樹，不報錯
ns = boot(false)
rid, rec = firstRecipe(ns, true)
local ok, err = pcall(ns.Window.showTree, {}, rid)
H.check(ok, "沒有 SetItemByID 時不報錯：" .. tostring(err))
H.check(calls.lines[1]:find("名" .. rec.item, 1, true) == 1, "沒有 SetItemByID 時第一行仍是成品名稱標題")
