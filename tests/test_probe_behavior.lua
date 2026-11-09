-- 正式版探測要記錄行為，不只存在與否（plan Task 2）
local files = { "Locale.lua", "Flavor.lua", "Probe.lua" }
H.reset({ locale = "zhTW", extra = {
  C_TradeSkillUI = {
    GetAllRecipeIDs = function() return { 103, 101, 102 } end,
    GetRecipeInfo = function(id) return { recipeID = id, learned = id ~= 103 } end,
  },
  IsPlayerSpell = function(id) return id == 101 end,
  IsSpellKnown = function() return false end,
} })
local ns = H.load(files)
H.check(type(ns.Probe.behavior) == "function", "Probe.behavior 存在")
local b = ns.Probe.behavior and ns.Probe.behavior() or {}
H.eq(b.recipeCount, 3, "記錄 GetAllRecipeIDs 筆數")
H.eq(b.learnedCount, 2, "記錄已學筆數")
-- 實測（正式版 492 筆）：前 3 筆剛好都未學，看不出 recipeID 是不是 spellID → 取樣要優先拿已學的
H.eq(b.samples and b.samples[1].learned, true, "取樣第一筆是已學的")
H.eq(b.samples and b.samples[1].isPlayerSpell, true, "記錄已學配方的 recipeID 是否被 IsPlayerSpell 認得（是否等於 spellID）")
local hasUnlearned = false
for _, x in ipairs(b.samples or {}) do if x.learned == false then hasUnlearned = true end end
H.check(hasUnlearned, "也取一筆未學的當對照")
local names = {}
for _, n in ipairs(ns.Probe.APIS) do names[n] = true end
H.check(names["C_TradeSkillUI.GetChildProfessionInfo"] and names["GameTooltip.SetItemByID"] and names["WOW_PROJECT_ID"],
  "APIS 包含正式版要確認的項目")

-- 沒有 C_TradeSkillUI（或視窗沒開）時不報錯
H.reset({ locale = "zhTW", extra = {} })
ns = H.load(files)
local ok, r = pcall(ns.Probe.behavior)
H.check(ok and r.recipeCount == nil, "沒有 C_TradeSkillUI 時不報錯、不記筆數")
