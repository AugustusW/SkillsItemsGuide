-- 正式版：已學掃描節流、樹狀 tooltip 不顯示「技能 ?」、品質合併的拆解、視窗標資料片
local FILES = { "Locale.lua", "Flavor.lua", "tests/fixtures/retail_min.lua", "Index.lua", "Breakdown.lua", "Format.lua",
  "Names.lua", "Core.lua", "Scan.lua" }
local scans, timers = 0, {}
local function boot(projectId)
  scans, timers = 0, {}
  H.reset({ manifest = projectId == 1 and "api_manifest_retail.lua" or nil, projectId = projectId, extra = {
    C_TradeSkillUI = {
      GetAllRecipeIDs = function() scans = scans + 1 return { 1227926 } end,
      GetRecipeInfo = function() return { learned = true } end,
    },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    GetProfessions = function() return nil end,
  } })
  local ns = H.load(FILES)
  ns.Data.recipes[52148].spell = 1227926
  SkillsItemsGuideCharDB = {}
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  return ns
end
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

-- 1. 正式版：專業視窗事件一次來很多個，合併成一次掃描
local ns = boot(1)
for _ = 1, 10 do H.fire("TRADE_SKILL_LIST_UPDATE") end
H.eq(scans, 0, "事件當下不立刻掃描")
runTimers()
H.eq(scans, 1, "10 個事件合併成 1 次掃描")
H.check(SkillsItemsGuideCharDB.known and SkillsItemsGuideCharDB.known["1227926"], "掃描後記下已學")
H.check(SkillsItemsGuideCharDB.opened and SkillsItemsGuideCharDB.opened["197"], "以專業記錄開過視窗")

-- 2. 樹狀 tooltip：正式版配方沒有技能點數，不顯示「技能 ?」
ns.Index.build()
local tt = ns.Format.treeTooltip(ns.Breakdown.build(52148, 1, {}), { item = function(id) return "名" .. id end,
  prof = function() return "裁縫" end, recipe = function() return nil end }, 12)
local hasQ = false
for _, l in ipairs(tt.lines) do if l.text:find("?", 1, true) then hasQ = true end end
H.check(not hasQ, "正式版樹狀 tooltip 沒有「技能 ?」")

-- 3. 拆解：材料是 1 星奧紋布，做法產出的是 2 星（非 canonical），也要接得上
local res = ns.Breakdown.build(52148, 1, {})
local child
for _, c in ipairs(res.root.children) do if c.item == 237018 and c.recipe then child = c end end
H.check(child and child.recipe == 60001, "1 星材料的做法找到產出 2 星的配方")

-- 4. 永恆維持原行為：事件當下就掃描
ns = boot(nil)
H.fire("TRADE_SKILL_LIST_UPDATE")
H.eq(scans, 1, "永恆事件當下就掃描（行為不變）")

-- 5. 完整視窗：舊資料片的配方標資料片名稱，當前的不標
local files = H.tocFiles("SkillsItemsGuide_Mainline.toc")
for i, f in ipairs(files) do if f == "Data/Retail/Professions.lua" then files[i] = "tests/fixtures/retail_min.lua" end end
H.reset({ manifest = "api_manifest_retail.lua", projectId = 1, extra = {
  C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
    GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
  C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function() return 1 end },
  GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end,
    Hide = function() end, IsShown = function() return false end },
  hooksecurefunc = function() end,
} })
ns = H.load(files)
H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
ns.Window.open({ prof = 197 })
local titles = {}
for _, r in ipairs(ns.Window._rows) do if r.rid then titles[r.rid] = r.name:GetText() end end
H.check(titles[2963] and titles[2963]:find("（艾澤拉斯裁縫）", 1, true) ~= nil, "舊資料片配方標資料片名稱：" .. tostring(titles[2963]))
H.check(titles[52148] and titles[52148]:find("至暗之夜", 1, true) == nil, "當前資料片不標：" .. tostring(titles[52148]))
