-- 使用者 2026-11-09：小地圖旁官方「插件收納」按鈕（Addon Compartment）放一個入口；永恆與正式版同位置
local function tocField(name, key)
  for line in io.lines(H.dir .. "/" .. name) do
    local v = line:gsub("\r", ""):match("^## " .. key .. ": *(.-)%s*$")
    if v then return v end
  end
end

for _, toc in ipairs({ "SkillsItemsGuide_Forever.toc", "SkillsItemsGuide_Mainline.toc" }) do
  H.eq(tocField(toc, "AddonCompartmentFunc"), "SkillsItemsGuide_OnAddonCompartmentClick", toc .. " 指定收納按鈕點擊函式")
  H.eq(tocField(toc, "AddonCompartmentFuncOnEnter"), "SkillsItemsGuide_OnAddonCompartmentEnter", toc .. " 指定滑過函式")
  H.eq(tocField(toc, "AddonCompartmentFuncOnLeave"), "SkillsItemsGuide_OnAddonCompartmentLeave", toc .. " 指定離開函式")
end

local tip
local function boot(toc)
  tip = { lines = {} }
  tip.SetOwner = function(self, o) self.owner = o end
  tip.ClearLines = function(self) self.lines = {} end
  tip.AddLine = function(self, t) self.lines[#self.lines + 1] = t end
  tip.Show = function(self) self.shown = true end
  tip.Hide = function(self) self.shown = false end
  tip.IsShown = function(self) return self.shown end
  H.reset({ locale = "zhTW", manifest = toc:find("Mainline") and "api_manifest_retail.lua" or nil,
    projectId = toc:find("Mainline") and 1 or nil, extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
    GameTooltip = tip, hooksecurefunc = function() end, C_Timer = { After = function() end },
  } })
  local files = H.tocFiles(toc)
  for i, f in ipairs(files) do if f == "Data/Retail/Professions.lua" then files[i] = "tests/fixtures/retail_min.lua" end end
  local ns = H.load(files)
  H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
  return ns
end

for _, toc in ipairs({ "SkillsItemsGuide_Forever.toc", "SkillsItemsGuide_Mainline.toc" }) do
  boot(toc)
  H.check(type(SkillsItemsGuide_OnAddonCompartmentClick) == "function", toc .. "：點擊函式是全域")
  SkillsItemsGuide_OnAddonCompartmentClick("SkillsItemsGuide", "LeftButton")
  local f = SkillsItemsGuideFrame
  H.check(f and f:IsShown(), toc .. "：點一下開完整視窗")
  SkillsItemsGuide_OnAddonCompartmentClick("SkillsItemsGuide", "LeftButton")
  H.check(f and not f:IsShown(), toc .. "：再點一下關掉")

  local btn = {}
  SkillsItemsGuide_OnAddonCompartmentEnter("SkillsItemsGuide", btn)
  H.eq(tip.owner, btn, toc .. "：滑過時 tooltip 掛在收納清單的那一列")
  H.eq(tip.lines[1], "技能物品指南", toc .. "：tooltip 第一行是插件名稱")
  H.check(tip.shown and #tip.lines >= 2, toc .. "：tooltip 有操作說明")
  SkillsItemsGuide_OnAddonCompartmentLeave("SkillsItemsGuide", btn)
  H.check(not tip.shown, toc .. "：離開時收起 tooltip")
end
