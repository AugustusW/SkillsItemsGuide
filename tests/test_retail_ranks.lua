-- 審查 Important（2026-11-09）：
-- 1. 分級配方（同成品 1–3 級各一個法術）學了任一級都要算學會
-- 2. 開別人的專業連結（聊天連結、公會、製作訂單）不能把對方學的配方記成自己的
local FILES = { "Locale.lua", "Flavor.lua", "tests/fixtures/retail_min.lua", "Index.lua", "Breakdown.lua", "Format.lua",
  "Names.lua", "Core.lua", "Scan.lua" }
local timers = {}
local linked = false
local function boot()
  timers = {}
  H.reset({ manifest = "api_manifest_retail.lua", projectId = 1, extra = {
    C_TradeSkillUI = {
      GetAllRecipeIDs = function() return { 3002 } end,
      GetRecipeInfo = function() return { learned = true } end,
      IsTradeSkillLinked = function() return linked end,
    },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    GetProfessions = function() return nil end,
  } })
  local ns = H.load(FILES)
  ns.Data.recipes[2963].spell = 3001
  ns.Data.recipes[2963].spells = { 3001, 3002, 3003 }
  SkillsItemsGuideCharDB = {}
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  return ns
end
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
local names = { item = function(id) return "名" .. id end, prof = function() return "裁縫" end,
  recipe = function() return nil end }

-- 1. 學了 2 級（3002）：Shift 清單的 2963 標成已學
local ns = boot()
local char = { professions = { ["197"] = true }, opened = { ["197"] = true }, known = { ["3002"] = true } }
ns.Index.build()
local sl = ns.Format.shiftLines(237018, char, names, 20)
local hit
for _, l in ipairs(sl.lines) do if l.text:find("名2996", 1, true) then hit = l end end
H.check(hit ~= nil, "Shift 清單列出分級配方 2963")
H.check(hit and hit.learned == true, "學了任一級就標已學")

-- 拆解：做 237018 時，學了任一級的配方優先
H.check(ns.Index.learned(ns.Data.recipes[2963], { [3003] = true }), "數字鍵的已學集合也認得任一級")
H.check(not ns.Index.learned(ns.Data.recipes[2963], { [9999] = true }), "沒學任何一級就是沒學")
H.check(ns.Index.learned(ns.Data.recipes[52148], {}) == false, "沒有法術對應的配方不算學會")

-- 2. 開的是別人的專業連結：不記錄已學、也不算自己開過這個專業
linked = true
ns = boot()
H.fire("TRADE_SKILL_LIST_UPDATE")
runTimers()
H.check(not (SkillsItemsGuideCharDB.known or {})["3002"], "別人的專業連結不記成自己已學")

linked = false
ns = boot()
H.fire("TRADE_SKILL_LIST_UPDATE")
runTimers()
H.check((SkillsItemsGuideCharDB.known or {})["3002"], "自己的專業視窗照常記錄")
