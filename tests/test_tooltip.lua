local FILES = { "Locale.lua", "Data/Professions.lua", "Data/ClassSkills.lua", "Data/Cache.lua", "Index.lua", "Breakdown.lua",
  "Format.lua", "Names.lua", "Core.lua", "Tooltip.lua" }

local shift, alt = false, false
local postCall
local function newTooltip(owner)
  local tt = { lines = {}, owner = owner, shown = true, refreshed = 0 }
  function tt:AddLine(text, r, g, b) self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b } end
  function tt:GetOwner() return self.owner end
  function tt:IsShown() return self.shown end
  function tt:Show() end
  return tt
end
local NAMES = { [2589] = "亞麻布", [2996] = "亞麻布卷", [1251] = "亞麻繃帶", [2581] = "厚亞麻繃帶" }
local function boot(char)
  shift, alt = false, false
  H.reset({ locale = "zhTW", extra = {
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) if kind == "ITEM" then postCall = fn end end },
    Enum = { TooltipDataType = { Item = "ITEM" } },
    IsShiftKeyDown = function() return shift end,
    IsAltKeyDown = function() return alt end,
    C_Item = { GetItemNameByID = function(id) return NAMES[id] end, RequestLoadItemDataByID = function() end },
    C_Spell = { GetSpellName = function() return nil end },
    GameTooltip = newTooltip(nil),
    hooksecurefunc = function() end,
  } })
  local ns = H.load(FILES)
  SkillsItemsGuideCharDB = char
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end

local function texts(tt) local t = {} for i, l in ipairs(tt.lines) do t[i] = l.text end return table.concat(t, "\n") end

local char = { professions = { ["197"] = true, ["129"] = true }, known = { ["2963"] = true }, opened = { ["197"] = true, ["129"] = true } }
local ns = boot(char)
H.check(type(postCall) == "function", "掛上 Item 類 tooltip 的 PostCall")

local bagButton = { GetBagID = function() return 0 end }
local tt = newTooltip(bagButton)
postCall(tt, { id = 2589 })
H.check(texts(tt):find("工程學（6）、鍛造（3）、急救（2）、裁縫（1）", 1, true), "平常加一行專業（數量）")
H.check(not texts(tt):find("亞麻布卷 亞麻布（2）", 1, true), "沒按 Shift 不列配方")
H.check(texts(tt):find("Alt+左鍵", 1, true) == nil, "沒按 Shift 時不出現開啟提示")

shift = true
tt = newTooltip(bagButton)
postCall(tt, { id = 2589 })
H.check(texts(tt):find("裁縫：亞麻布卷 亞麻布（2）", 1, true), "按 Shift 列有學專業的配方")
H.check(texts(tt):find("Alt+左鍵：開啟完整視窗", 1, true), "背包物品按 Shift 時有開啟提示")

local chatLink = {}
tt = newTooltip(chatLink)
postCall(tt, { id = 2589 })
H.check(texts(tt):find("Alt+左鍵", 1, true) == nil, "不是背包物品時沒有開啟提示")

tt = newTooltip(bagButton)
postCall(tt, { id = 999999 })
H.eq(#tt.lines, 0, "沒有用途的物品不加任何行")

-- 游標停在物品上按／放 Shift：重新產生 tooltip
shift = false
local refreshed = 0
GameTooltip = newTooltip(bagButton)
GameTooltip.RefreshData = function() refreshed = refreshed + 1 end
H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
H.eq(refreshed, 1, "按下 Shift 時刷新顯示中的 tooltip")
H.fire("MODIFIER_STATE_CHANGED", "LALT", 1)
H.eq(refreshed, 1, "按 Alt 不刷新")
GameTooltip.shown = false
H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
H.eq(refreshed, 1, "tooltip 沒顯示時不刷新")

-- Alt+左鍵（不按 Shift／Ctrl）在背包物品上：開完整視窗並進入材料反查
local hooked
H.reset({ locale = "zhTW", extra = {
  ContainerFrameItemButtonMixin = { OnModifiedClick = function() end },
  hooksecurefunc = function(t, name, fn) if t == ContainerFrameItemButtonMixin and name == "OnModifiedClick" then hooked = fn end end,
  IsAltKeyDown = function() return alt end, IsShiftKeyDown = function() return shift end,
  C_Container = { GetContainerItemInfo = function(bag, slot) return { itemID = 2589 } end },
} })
ns = H.load(FILES)
local opened
ns.Window = { open = function(o) opened = o end }
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.check(type(hooked) == "function", "hook 背包按鈕的 OnModifiedClick")
local btn = { GetBagID = function() return 0 end, GetID = function() return 3 end }
alt, shift = true, false
hooked(btn, "LeftButton")
H.check(opened and opened.material == 2589, "Alt+左鍵開視窗並帶入材料")
opened = nil
alt, shift = true, true
hooked(btn, "LeftButton")
H.eq(opened, nil, "Shift+Alt 不開（那是拆堆疊）")
alt, shift = true, false
hooked(btn, "RightButton")
H.eq(opened, nil, "Alt+右鍵不開")

-- /sigcheck：已學配方對得上資料的比例
H.reset({ locale = "zhTW" })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
SkillsItemsGuideCharDB.known = { ["2963"] = true, ["18560"] = true, ["99999999"] = true }
local r = ns.checkKnown()
H.eq(r.total, 3, "已學配方 3 個")
H.eq(r.matched, 2, "其中 2 個對得上資料")
H.eq(r.unmatched[1], 99999999, "列出對不上的 id")
H.check(type(SlashCmdList.SIGCHECK) == "function", "/sigcheck 已註冊")
