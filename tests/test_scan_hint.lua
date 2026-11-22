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
