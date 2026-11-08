local FILES = { "Locale.lua", "Skills.lua" }
H.reset()
local ns = H.load(FILES)
ns.Data = {
  meta = { classBuild = "1.60.1.70532" },
  classSkills = { [8] = {
    { spell = 133, lv = 1 }, { spell = 116, lv = 4 }, { spell = 2948, lv = 18 }, { spell = 8444, lv = 18, sup = 2948 },
    { spell = 10, lv = 20 }, { spell = 1953, lv = 20 }, { spell = 8401, lv = 22 },
  }, [1] = { { spell = 78, lv = 1 }, { spell = 100, lv = 4 } } },
  -- 訓練師清單是完整的（含還不能學的），所以每個技能都有一筆；116 沒有學費資料
  cache = { class = { [8] = { [10] = { lv = 20, cost = 2000 }, [133] = { lv = 1, cost = 0 }, [116] = { lv = 4 },
    [2948] = { lv = 18 }, [8444] = { lv = 18 }, [1953] = { lv = 20 }, [8401] = { lv = 22 } } }, recipeSkill = {},
            build = "1.60.1.70399", date = "2026-11-08" },
}
local known = { [133] = true, [8444] = true }
local function isKnown(s) return known[s] == true end
local ALL = { learned = true, available = true, tooLow = true }

local res = ns.Skills.list(8, { own = true, level = 18, isKnown = isKnown, show = ALL })
local byLv = {}
for _, g in ipairs(res.groups) do byLv[g.lv] = g end
H.eq(byLv[18].tag, "current", "18 級組標目前")
H.eq(byLv[20].tag, "next", "20 級組標下一級")
H.eq(res.scrollTo, 18, "開啟時捲到目前等級")
local function status(lv, spell) for _, r in ipairs(byLv[lv].rows) do if r.spell == spell then return r end end end
H.eq(status(1, 133).status, "learned", "已學")
H.eq(status(4, 116).status, "available", "等級夠但沒學＝可學")
H.eq(status(18, 2948).status, "learned", "被高 rank 取代的低 rank 算已學")
H.eq(status(20, 10).status, "tooLow", "等級不到")
H.eq(status(20, 10).cost, 2000, "學費來自快取")
H.eq(status(1, 133).cost, 0, "學費 0 保留為 0")
H.eq(status(4, 116).cost, nil, "沒有快取時學費 nil（畫面顯示「—」）")
H.eq(res.source.kind, "verified", "有快取的職業標已校正")
H.eq(res.source.build, "1.60.1.70399", "來源 build")

local only = ns.Skills.list(8, { own = true, level = 18, isKnown = isKnown, show = { available = true } })
local n = 0
for _, g in ipairs(only.groups) do for _, r in ipairs(g.rows) do n = n + 1; H.eq(r.status, "available", "只看可學") end end
H.eq(n, 1, "只看可學時只有 1 筆")

local none = ns.Skills.list(8, { own = true, level = 18, isKnown = isKnown, show = {} })
local total = 0
for _, g in ipairs(none.groups) do total = total + #g.rows end
H.eq(total, 7, "全部不勾＝全部顯示")

local other = ns.Skills.list(1, { own = false, level = 18, isKnown = isKnown, show = { available = true } })
H.eq(other.scrollTo, nil, "其他職業不捲動")
H.eq(other.source.kind, "client", "沒有快取的職業標客戶端資料")
H.eq(other.source.build, "1.60.1.70532", "客戶端資料 build")
local cnt = 0
for _, g in ipairs(other.groups) do H.eq(g.tag, nil, "其他職業沒有目前／下一級"); for _, r in ipairs(g.rows) do cnt = cnt + 1; H.eq(r.status, nil, "其他職業不標狀態") end end
H.eq(cnt, 2, "其他職業忽略篩選、全部顯示")

local lvl19 = ns.Skills.list(8, { own = true, level = 19, isKnown = isKnown, show = ALL })
local tags = {}
for _, g in ipairs(lvl19.groups) do if g.tag then tags[g.tag] = g.lv end end
H.check(tags.current == 18 and tags.next == 20, "19 級時目前＝18 級組、下一級＝20 級組")
H.eq(#ns.Skills.list(99, { own = false, show = ALL }).groups, 0, "沒有資料的職業回空清單")

-- 審查 #4：遊戲內直接用存檔裡的訓練師快取（不必等回收重打包）
H.reset()
ns = H.load(FILES)
ns.Data = { meta = { classBuild = "1.60.1.70532" }, classSkills = { [8] = { { spell = 10, lv = 20 }, { spell = 116, lv = 4 } } },
  cache = { class = {}, recipeSkill = {} } }
SkillsItemsGuideDB = { trainer = { class = { ["8"] = { build = "1.60.1.70862", date = "2026-11-08",
  spells = { ["10"] = { lv = 22, cost = 1800 }, ["寒冰箭|等級 1"] = { lv = 4, cost = 10 } } } } } }
local live = ns.Skills.list(8, { own = false, show = {} })
local row10
for _, g in ipairs(live.groups) do for _, r in ipairs(g.rows) do if r.spell == 10 then row10 = r end end end
H.eq(row10.cost, 1800, "存檔快取的學費")
H.eq(row10.lv, 22, "存檔快取的等級優先")
H.eq(live.source.kind, "verified", "有存檔快取標已校正")
H.eq(live.source.build, "1.60.1.70862", "來源 build 取存檔")

-- 實測（戰士 17 級）：訓練師清單校正過的職業，不在清單裡的技能標「非訓練師」，不算可學
H.reset()
ns = H.load(FILES)
ns.Data = { meta = { classBuild = "1.60.1.70532" }, cache = { class = {}, recipeSkill = {} },
  classSkills = { [1] = { { spell = 20647, lv = 1 }, { spell = 78, lv = 1 }, { spell = 100, lv = 4 }, { spell = 71, lv = 10 }, { spell = 845, lv = 20 } } } }
SkillsItemsGuideDB = { trainer = { class = { ["1"] = { build = "b", date = "d",
  spells = { ["78"] = { lv = 1, cost = 10 }, ["100"] = { lv = 4, cost = 100 }, ["845"] = { lv = 20, cost = 2000 } } } } } }
local kn = { [78] = true }
local w = ns.Skills.list(1, { own = true, level = 17, isKnown = function(s) return kn[s] == true end,
  show = { available = true } })
local got = {}
for _, g in ipairs(w.groups) do for _, r in ipairs(g.rows) do got[#got + 1] = r.spell .. ":" .. tostring(r.status) end end
H.eq(table.concat(got, ","), "100:available", "只看可學：不含非訓練師的 20647 與任務技能 71")
local all = ns.Skills.list(1, { own = true, level = 17, isKnown = function(s) return kn[s] == true end, show = {} })
local st = {}
for _, g in ipairs(all.groups) do for _, r in ipairs(g.rows) do st[r.spell] = r.status end end
H.eq(st[20647], "other", "不在訓練師清單的標 other（非訓練師）")
-- 目前／下一級只標在真正的等級組，不跟著篩選結果跑
local tags = {}
for _, g in ipairs(w.groups) do if g.tag then tags[#tags + 1] = g.lv .. g.tag end end
H.eq(table.concat(tags, ","), "", "篩選後剩下的 4 級組不標目前（真正的目前是 10 級組）")
local tagsAll = {}
for _, g in ipairs(all.groups) do if g.tag then tagsAll[g.tag] = g.lv end end
H.check(tagsAll.current == 10 and tagsAll.next == 20, "不篩選時目前＝10 級組、下一級＝20 級組")
H.eq(w.scrollTo, 4, "篩選後捲到第一個符合的組附近")
H.eq(all.source.kind, "verified", "有訓練師清單")
local cl = ns.Skills.list(1, { own = true, level = 17, isKnown = function() return false end, show = {} })
SkillsItemsGuideDB = {}
local noCache = ns.Skills.list(1, { own = true, level = 17, isKnown = function() return false end, show = {} })
H.eq(noCache.source.kind, "client", "沒去過訓練師時是客戶端資料")
H.check(noCache.source.hint ~= nil, "沒去過訓練師時有指引")

-- 實測存檔：已學的技能在訓練師清單裡需求等級是 0（不是真的 0 級），要退回客戶端資料的等級
H.reset()
ns = H.load(FILES)
ns.Data = { meta = {}, cache = { class = {}, recipeSkill = {} }, classSkills = { [1] = { { spell = 100, lv = 4 }, { spell = 845, lv = 20 } } } }
SkillsItemsGuideDB = { trainer = { class = { ["1"] = { spells = { ["100"] = { lv = 0, cost = 100 }, ["845"] = { lv = 20, cost = 2000 } } } } } }
local z = ns.Skills.list(1, { own = true, level = 17, isKnown = function(s) return s == 100 end, show = {} })
H.eq(z.groups[1].lv, 4, "需求等級 0 視為未知，用客戶端資料的 4 級")
H.eq(z.groups[1].rows[1].cost, 100, "學費仍用訓練師快取")

-- 遊戲內存檔的訓練師清單有、打包資料沒有的技能（例：招架）也要列出
H.reset()
ns = H.load(FILES)
ns.Data = { meta = {}, cache = { class = {}, recipeSkill = {} }, classSkills = { [1] = { { spell = 100, lv = 4 } } } }
SkillsItemsGuideDB = { trainer = { class = { ["1"] = { spells = { ["100"] = { lv = 4 }, ["3127"] = { lv = 6, cost = 50 }, ["寒冰箭|等級 1"] = { lv = 8 } } } } } }
local extra = ns.Skills.list(1, { own = true, level = 17, isKnown = function() return false end, show = {} })
local ids = {}
for _, g in ipairs(extra.groups) do for _, r in ipairs(g.rows) do ids[#ids + 1] = r.spell end end
H.eq(table.concat(ids, ","), "100,3127", "補上訓練師清單才有的技能（非數字鍵略過）")
