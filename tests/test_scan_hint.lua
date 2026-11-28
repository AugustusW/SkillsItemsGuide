-- 登入提示：訓練師沒打開過的專業（2026-11-22，永恆版、有配方來源資料才提示）
local FILES = { "ErrorLog.lua", "Locale.lua", "Flavor.lua", "Data/Forever/Professions.lua", "Data/Forever/ClassSkills.lua",
  "Data/Forever/Sources.lua", "Core.lua", "Scan.lua", "Source.lua" }

local function login(opts)
  opts = opts or {}
  local printed = {}
  H.reset({ locale = opts.locale or "zhTW", manifest = opts.manifest, projectId = opts.projectId, extra = {
    GetProfessions = function() return 1, 2 end,
    GetProfessionInfo = function(i) if i == 1 then return "裁縫", nil, 1, 75, 1, 0, 197 end return "急救", nil, 1, 75, 1, 0, 129 end,
  } })
  local ns = H.load(FILES)
  if not opts.sources then
    ns.Data.meta.sourcesGenerated = nil -- 不依賴 repo 內 Sources.lua 是真資料還是佔位檔
    ns.Data.sources = {}
  else
    local D = ns.Data
    D.meta.sourcesGenerated = "2026-11-22"
    D.sources = {}
    local seen = {}
    for _, rec in pairs(D.recipes) do
      if (rec.p == 197 or rec.p == 129) and not seen[rec.p] then seen[rec.p] = true; D.sources[rec.spell] = { src = "trainer" } end
    end
    assert(seen[197] and seen[129], "測試資料要有裁縫與急救配方")
  end
  print = function(s) printed[#printed + 1] = s end
  SkillsItemsGuideCharDB = { opened = { ["197"] = true, ["129"] = true } }
  if opts.trainer then SkillsItemsGuideDB = { trainer = { prof = opts.trainer } } end
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  if opts.trainer then SkillsItemsGuideDB.trainer = { prof = opts.trainer } end
  H.fire("PLAYER_LOGIN")
  return table.concat(printed, "\n"), #printed
end

local t, n = login({ sources = true })
H.eq(n, 1, "視窗都開過、訓練師都沒開過：只有一行")
H.check(t:find("急救", 1, true) and t:find("裁縫", 1, true) and t:find("訓練師", 1, true), "列出兩個專業與訓練師提示：" .. t)

t, n = login({ sources = true, trainer = { ["197"] = { spells = {} } } })
H.check(t:find("急救", 1, true) and not t:find("裁縫", 1, true), "裁縫訓練師開過後只剩急救")

t, n = login({ sources = true, trainer = { ["197"] = { spells = {} }, ["129"] = { spells = {} } } })
H.eq(n, 0, "全部訓練師開過就不提示")

t, n = login({ sources = false })
H.eq(n, 0, "佔位資料（沒有配方來源）不提示")

t, n = login({ sources = true, locale = "enUS" })
H.check(t:find("trainer once to confirm recipe sources", 1, true) ~= nil, "英文版文字")
H.check(t:find("[\228-\233][\128-\191][\128-\191]") == nil, "英文版沒有 CJK：" .. t)

-- 正式版：不提示（Source 沒載入、Flavor 為正式版）
t, n = login({ sources = true, manifest = "api_manifest_retail.lua", projectId = 1 })
H.eq(n, 0, "正式版不提示")

-- 使用者 2026-11-28：永恆版釣魚沒學任何配方時視窗是空清單，配方反推不到專業 → 每次登入都提示沒開過
-- 改成：至少學了一個配方（IsPlayerSpell）才提示沒開過
do
  local learned = {}
  local function unopened(projectId, manifest)
    H.reset({ projectId = projectId, manifest = manifest, extra = { IsPlayerSpell = function(id) return learned[id] == true end } })
    local ns = H.load(FILES)
    SkillsItemsGuideCharDB = { professions = { ["197"] = true, ["356"] = true }, opened = {} }
    H.fire("ADDON_LOADED", "SkillsItemsGuide")
    return table.concat(ns.Scan.unopened(), ","), ns
  end
  local function firstSpell(ns, p)
    for _, rec in pairs(ns.Data.recipes) do if rec.p == p then return (rec.spells or { rec.spell })[1] end end
  end
  local s, ns = unopened()
  H.eq(s, "", "一個配方都沒學：沒有專業要提示")
  learned[firstSpell(ns, 197)] = true
  s, ns = unopened()
  H.check(s:find(ns.L.prof(197), 1, true) ~= nil, "學了裁縫配方、視窗沒開過 → 提示裁縫：" .. s)
  H.check(s:find(ns.L.prof(356), 1, true) == nil, "釣魚一個配方都沒學 → 不提示：" .. s)
  learned[firstSpell(ns, 356)] = true
  H.check(table.concat(ns.Scan.unopened(), ","):find(ns.L.prof(356), 1, true) == nil, "同一次登入、沒有專業事件：沿用快取")
  H.fire("SKILL_LINES_CHANGED")
  s = table.concat(ns.Scan.unopened(), ",")
  H.check(s:find(ns.L.prof(356), 1, true) ~= nil, "學了釣魚工具配方、專業事件後 → 又會提示：" .. s)
  H.check(s:find(ns.L.prof(197), 1, true) ~= nil, "裁縫仍在清單裡：" .. s)
  SkillsItemsGuideCharDB.opened["356"] = true
  s = table.concat(ns.Scan.unopened(), ",")
  H.check(s:find(ns.L.prof(356), 1, true) == nil, "開過之後就不提示：" .. s)
end

-- 正式版：同一條規則（視窗列出全部配方，通常開過就不會提示；沒學配方的專業一樣不提示）
do
  local learnedSpell
  H.reset({ projectId = 1, manifest = "api_manifest_retail.lua", extra = { IsPlayerSpell = function(id) return id == learnedSpell end } })
  local ns = H.load(FILES)
  for _, rec in pairs(ns.Data.recipes) do if rec.p == 197 then learnedSpell = (rec.spells or { rec.spell })[1]; break end end
  SkillsItemsGuideCharDB = { professions = { ["197"] = true, ["356"] = true }, opened = {} }
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  local s = table.concat(ns.Scan.unopened(), ",")
  H.check(s:find(ns.L.prof(197), 1, true) ~= nil and s:find(ns.L.prof(356), 1, true) == nil, "正式版：只列學了配方的裁縫：" .. s)
end
