-- 初始化、SavedVariables、指令註冊
local ADDON, ns = ...
local L = ns.L

local DB_VERSION = 1

local function slashTaken(cmd)
  if hash_SlashCmdList and hash_SlashCmdList[cmd] then return true end
  for k, v in pairs(_G) do
    if type(k) == "string" and k:match("^SLASH_") and type(v) == "string" and v:lower() == cmd then return true end
  end
  return false
end
ns.slashTaken = slashTaken

-- 指令名稱沒被佔用才註冊；回傳是否註冊成功
function ns.registerSlash(key, cmd, fn)
  if slashTaken(cmd) then
    print(string.format(L.SLASH_TAKEN, cmd))
    return false
  end
  _G["SLASH_" .. key .. "1"] = cmd
  SlashCmdList[key] = fn
  return true
end

local function initDB()
  SkillsItemsGuideDB = SkillsItemsGuideDB or {}
  SkillsItemsGuideDB.dbVersion = SkillsItemsGuideDB.dbVersion or DB_VERSION
  SkillsItemsGuideCharDB = SkillsItemsGuideCharDB or {}
  ns.db, ns.char = SkillsItemsGuideDB, SkillsItemsGuideCharDB
end

-- 背包物品 Alt+左鍵（不含 Shift／Ctrl）→ 開完整視窗並進入材料反查。
-- 只 hook Mixin：探測顯示 HandleModifiedItemClick 與 Mixin 每次點擊都會觸發，兩個都掛會開兩次。
function ns.hookBagClick()
  if not (hooksecurefunc and ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick) then return end
  hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", function(self, button)
    if button ~= "LeftButton" then return end
    if not (IsAltKeyDown and IsAltKeyDown()) then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if IsControlKeyDown and IsControlKeyDown() then return end
    local info = C_Container and C_Container.GetContainerItemInfo and self.GetBagID
      and C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID())
    if info and info.itemID and ns.Window then ns.Window.open({ material = info.itemID }) end
  end)
end

-- /sigcheck：客戶端回報的已學配方（法術 id）有多少對得上打包資料
function ns.checkKnown()
  local bySpell = {}
  for _, rec in pairs(ns.Data.recipes or {}) do if rec.spell then bySpell[rec.spell] = true end end
  local total, matched, unmatched = 0, 0, {}
  for k in pairs((SkillsItemsGuideCharDB or {}).known or {}) do
    local id = tonumber(k)
    total = total + 1
    if id and bySpell[id] then matched = matched + 1 else unmatched[#unmatched + 1] = id end
  end
  table.sort(unmatched)
  return { total = total, matched = matched, unmatched = unmatched }
end

function ns.trainerDebugText()
  local d = (SkillsItemsGuideDB or {}).trainerDebug
  if not d then return "trainer: no trainer visited yet" end
  return string.format("trainer: %s event=%s count=%s ok=%s prof=%s matched=%s saved=%s err=%s",
    tostring(d.date), tostring(d.event), tostring(d.count), tostring(d.ok), tostring(d.isProf),
    tostring(d.matched), tostring(d.saved), tostring(d.err))
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, ev, name)
  if ev == "ADDON_LOADED" and name == ADDON then
    initDB()
    if ns.ProbeUI then
      -- 點擊紀錄只在打過 /sigprobe 後才掛（正式使用時不寫存檔）
      ns.registerSlash("SIGPROBE", "/sigprobe", function() ns.ProbeUI.installHooks(); ns.ProbeUI.show() end)
    end
    if ns.Index then ns.Index.build() end -- 反查索引在載入時建一次
    ns.hookBagClick()
    ns.registerSlash("SIGCHECK", "/sigcheck", function()
      local r = ns.checkKnown()
      print(string.format(L.CHECK_FMT, r.total, r.matched))
      if #r.unmatched > 0 then print(table.concat(r.unmatched, ", ")) end
      print(ns.trainerDebugText())
    end)
    for _, fn in ipairs(ns.onLoad or {}) do fn() end
  end
end)
