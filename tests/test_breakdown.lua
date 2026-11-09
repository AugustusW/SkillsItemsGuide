local FILES = { "Locale.lua", "Flavor.lua", "Data/Forever/Professions.lua", "Data/Forever/ClassSkills.lua", "Data/Forever/Cache.lua", "Index.lua", "Breakdown.lua" }
H.reset()
local ns = H.load(FILES)
ns.Index.build()

local function totalsMap(res) local m = {} for _, t in ipairs(res.totals) do m[t.item] = t.n end return m end

-- 反查：亞麻布（2589）被哪些專業用（實際資料）
local pc = ns.Index.profCounts(2589)
local s = {}
for _, x in ipairs(pc) do s[#s + 1] = x.prof .. "=" .. x.n end
H.eq(table.concat(s, ","), "202=6,164=3,129=2,197=1", "亞麻布的專業計數依數量排序")
H.eq(#ns.Index.usedBy(2589), 12, "亞麻布被 12 條配方使用")
H.eq(ns.Index.madeBy(2996)[1], 2359, "亞麻布卷由配方 2359 製作")
H.eq(ns.Index.profCounts(999999) and #ns.Index.profCounts(999999), 0, "沒有用途的物品回空表")

-- 紅色亞麻包 ×3
local r = ns.Breakdown.build(4019, 3)
local t = totalsMap(r)
H.eq(t[2589], 24, "紅色亞麻包×3 要亞麻布 24")
H.eq(t[2321], 3, "細線 3")
H.eq(t[2604], 3, "紅色染料 3")
H.eq(r.totals[1].item, 2589, "原料依數量多到少，亞麻布排第一")
local bolt
for _, c in ipairs(r.root.children) do if c.item == 2996 then bolt = c end end
H.check(bolt and bolt.n == 12 and bolt.prof == 197 and bolt.recipe == 2359, "中間產物亞麻布卷 ×12，裁縫，配方 2359")
H.eq(r.root.n, 3, "根節點數量 3")

-- 月布長袍 ×1：冷卻往上傳
r = ns.Breakdown.build(12349, 1)
t = totalsMap(r)
H.eq(t[14047], 30, "符文布 30")
H.eq(t[14256], 8, "惡魔布 8")
H.eq(t[13926], 2, "金珍珠 2")
H.eq(t[14341], 2, "符文線 2")
H.check(#r.cooldowns == 1 and r.cooldowns[1].recipe == 10487 and r.cooldowns[1].times == 4 and r.cooldowns[1].sec == 342000,
  "冷卻：月布 共 4 次、每次 342000 秒")

-- craftedQuantity=3：要 4 個做 2 次
r = ns.Breakdown.build(1548, 4)
H.eq(totalsMap(r)[1015], 4, "產出 3 個的配方要 4 個時做 2 次（材料 2×2）")

-- 合成資料：循環、同產物多配方、附魔（沒有產物）
H.reset()
ns = H.load({ "Locale.lua", "Index.lua", "Breakdown.lua" })
ns.Data = { items = { [1] = { il = 5 }, [2] = { il = 5 }, [3] = { il = 10 } }, recipes = {
  [10] = { p = 1, item = 1, q = 1, r = { { 2, 1 } }, spell = 100 },
  [20] = { p = 1, item = 2, q = 1, r = { { 1, 1 } }, spell = 200 },   -- 1 ↔ 2 循環
  [30] = { p = 2, item = 3, q = 1, r = { { 4, 2 } }, spell = 300, il = 10 },
  [31] = { p = 2, item = 3, q = 1, r = { { 5, 1 } }, spell = 301, il = 10, s = 50 },
  [40] = { p = 3, q = 1, r = { { 4, 1 } }, spell = 400 },                -- 附魔：沒有產物
  [50] = { p = 2, item = 6, q = 1, r = { { 3, 1 } }, spell = 500 },     -- 材料 3 有兩種做法
} }
ns.Index.build()
local okC, rc = pcall(ns.Breakdown.build, 10, 1)
H.check(okC and totalsMap(rc)[2] == 1 and totalsMap(rc)[1] == nil, "兩物品互做的環：直接材料當原料、不無限遞迴")
local ra = ns.Breakdown.build(30, 1)
H.eq(ra.alternatives, 1, "同產物另有 1 種做法")
local rk = ns.Breakdown.build(50, 1, { [300] = true })
H.eq(rk.root.children[1].recipe, 30, "中間產物有兩種做法時，已學的那條優先（即使排序在後）")
local rn = ns.Breakdown.build(50, 1)
H.eq(rn.root.children[1].recipe, 31, "都沒學時取排序第一條（技能等級有值的 31）")
local okE, re = pcall(ns.Breakdown.build, 40, 2)
H.check(okE and re.root.item == nil and totalsMap(re)[4] == 2, "附魔沒有產物也能拆解")
local list = { 31, 30 }
ns.Breakdown.sortRecipes(list)
H.eq(list[1], 31, "同物品等級時技能等級有值的排前面（缺值排最後）")

-- 審查 Critical：轉化環（環長 ≥3）不能讓原料與中間產物重複、也不能帶出環上的冷卻
H.reset()
ns = H.load({ "Locale.lua", "Index.lua", "Breakdown.lua" })
ns.Data = { items = {}, recipes = {
  [1] = { p = 1, item = 101, q = 1, r = { { 102, 1 } }, spell = 1, cd = 82800 },  -- 101 ← 102
  [2] = { p = 1, item = 102, q = 1, r = { { 103, 1 } }, spell = 2, cd = 82800 },  -- 102 ← 103
  [3] = { p = 1, item = 103, q = 1, r = { { 101, 1 } }, spell = 3, cd = 82800 },  -- 103 ← 101（環）
  [9] = { p = 2, item = 900, q = 1, r = { { 101, 6 }, { 500, 1 } }, spell = 9 },  -- 用到環上的 101
} }
ns.Index.build()
local rr = ns.Breakdown.build(9, 1)
t = totalsMap(rr)
H.eq(t[101], 6, "環上的物品直接當原料（101×6）")
H.eq(t[102], nil, "不展開到環上的其他物品")
H.eq(#rr.cooldowns, 0, "不帶出環上配方的冷卻")
local self1 = ns.Breakdown.build(1, 1)
H.eq(totalsMap(self1)[102], 1, "根節點本身在環上時，直接材料當原料")
H.eq(totalsMap(self1)[101], nil, "原料不含根節點自己的產物")

-- 實際資料不變式：任何配方的原料都不是自己的產物、也不是樹裡的中間產物
H.reset()
ns = H.load(FILES)
ns.Index.build()
local bad = 0
for rid, rec in pairs(ns.Data.recipes) do
  local res = ns.Breakdown.build(rid, 1)
  local inter = {}
  local function walk(n) for _, c in ipairs(n.children) do if c.recipe then inter[c.item] = true end walk(c) end end
  walk(res.root)
  -- 例外：配方直接消耗自己的產物（例：迫擊炮：重載 需要一個哥布林迫擊砲），產物本來就是材料
  local selfUse = false
  for _, rg in ipairs(rec.r) do if rg[1] == rec.item then selfUse = true end end
  for _, tt in ipairs(res.totals) do
    if (rec.item and tt.item == rec.item and not selfUse) or inter[tt.item] then bad = bad + 1 break end
  end
end
H.eq(bad, 0, "全部配方：原料不含自己的產物或中間產物")

-- 同一產物有冷卻與無冷卻兩種做法（例：金錠可熔煉也可點鐵成金）：沒指定已學時選無冷卻的
H.reset()
ns = H.load({ "Locale.lua", "Index.lua", "Breakdown.lua" })
ns.Data = { items = {}, recipes = {
  [1] = { p = 171, item = 3577, q = 1, r = { { 3575, 1 } }, spell = 11479, cd = 3600, s = 225 },  -- 轉化
  [2] = { p = 186, item = 3577, q = 1, r = { { 776, 1 } }, spell = 3308 },                        -- 熔煉
  [3] = { p = 164, item = 7000, q = 1, r = { { 3577, 2 } }, spell = 7000 },
} }
ns.Index.build()
local rg = ns.Breakdown.build(3, 1)
H.eq(rg.root.children[1].recipe, 2, "優先選沒有冷卻的做法")
H.eq(#rg.cooldowns, 0, "沒有帶出轉化冷卻")
local rk2 = ns.Breakdown.build(3, 1, { [11479] = true })
H.eq(rk2.root.children[1].recipe, 1, "只學了有冷卻的那條時仍選已學的")

-- 審查 #4：專業技能點數也用存檔裡的訓練師快取
H.reset()
ns = H.load({ "Locale.lua", "Index.lua", "Breakdown.lua" })
ns.Data = { items = {}, recipes = { [2359] = { p = 197, item = 2996, q = 1, r = { { 2589, 2 } }, spell = 2963 } }, cache = { recipeSkill = {} } }
ns.Index.build()
H.eq(ns.Index.skillOf(2359), nil, "沒有任何來源時未知")
SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["2963"] = { skill = 1 } } } } } }
H.eq(ns.Index.skillOf(2359), 1, "存檔快取的技能點數")

-- 審查 Important：訓練師快取的技能點數 0（已學服務）視為未知
H.reset()
ns = H.load({ "Locale.lua", "Index.lua", "Breakdown.lua" })
ns.Data = { items = {}, recipes = { [2359] = { p = 197, item = 2996, q = 1, r = { { 2589, 2 } }, spell = 2963, s = 5 } }, cache = { recipeSkill = {} } }
ns.Index.build()
SkillsItemsGuideDB = { trainer = { prof = { ["197"] = { spells = { ["2963"] = { skill = 0 } } } } } }
H.eq(ns.Index.skillOf(2359), 5, "快取技能點數 0 時退回圖紙資料")
