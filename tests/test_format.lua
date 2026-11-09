local FILES = { "Locale.lua", "Flavor.lua", "Data/Forever/Professions.lua", "Data/Forever/ClassSkills.lua", "Data/Forever/Cache.lua", "Index.lua", "Breakdown.lua", "Format.lua" }
local PROF_ZH = { [202] = "工程學", [164] = "鍛造", [129] = "急救", [197] = "裁縫" }
local PROF_EN = { [202] = "Engineering", [164] = "Blacksmithing", [129] = "First Aid", [197] = "Tailoring" }
local ITEM = { [2589] = "亞麻布", [2996] = "亞麻布卷", [1251] = "亞麻繃帶", [2581] = "厚亞麻繃帶", [5762] = "紅色亞麻包",
  [2321] = "細線", [2604] = "紅色染料" }
local function names(profs, uncached)
  return {
    item = function(id) if uncached and uncached[id] then return nil end return ITEM[id] or ("item" .. id) end,
    prof = function(id) return profs[id] or ("prof" .. id) end,
    recipeName = function(rid) return nil end,
  }
end

H.reset({ locale = "zhTW" })
local ns = H.load(FILES)
ns.Index.build()
H.eq(ns.Format.countsLine(2589, names(PROF_ZH)), "工程學（6）、鍛造（3）、急救（2）、裁縫（1）", "zhTW 平常一行")
H.eq(ns.Format.countsLine(999999, names(PROF_ZH)), nil, "沒有用途回 nil")

H.reset({ locale = "enUS" })
ns = H.load(FILES)
ns.Index.build()
H.eq(ns.Format.countsLine(2589, names(PROF_EN)), "Engineering (6), Blacksmithing (3), First Aid (2), Tailoring (1)", "enUS 平常一行")

-- Shift：只列有學的專業，已學／未學
H.reset({ locale = "zhTW" })
ns = H.load(FILES)
ns.Index.build()
local char = { professions = { ["197"] = true, ["129"] = true }, known = { ["2963"] = true }, opened = { ["197"] = true, ["129"] = true } }
local sl = ns.Format.shiftLines(2589, char, names(PROF_ZH))
local found
for _, l in ipairs(sl.lines) do if l.text == "裁縫：亞麻布卷 亞麻布（2）" then found = l end end
H.check(found and found.learned == true, "裁縫：亞麻布卷 亞麻布（2），已學")
H.eq(#sl.lines, 3, "裁縫 1 條＋急救 2 條")
for _, l in ipairs(sl.lines) do H.check(not l.text:find("工程學", 1, true), "沒學的專業不列") end
H.eq(sl.more, 0, "沒超過 8 條")

local none = ns.Format.shiftLines(2589, { professions = {} }, names(PROF_ZH))
H.eq(#none.lines, 0, "沒學任何相關專業時沒有列")
H.check(type(none.empty) == "string" and #none.empty > 0, "沒學任何相關專業時有空狀態文字")

local notOpened = ns.Format.shiftLines(2589, { professions = { ["197"] = true }, known = { ["2963"] = true } }, names(PROF_ZH))
H.eq(notOpened.lines[1].learned, nil, "沒開過專業視窗時不判斷（未知）")

-- 超過 8 條
ns.Index.usedBy = function() local t = {} for i = 1, 11 do t[i] = 2359 end return t end
local many = ns.Format.shiftLines(2589, char, names(PROF_ZH))
H.eq(#many.lines, 8, "最多 8 條")
H.eq(many.more, 3, "其餘 3 條")
H.reset({ locale = "zhTW" })
ns = H.load(FILES)
ns.Index.build()

-- 名稱未快取
local un = ns.Format.shiftLines(2589, char, names(PROF_ZH, { [2996] = true }))
local ph
for _, l in ipairs(un.lines) do if l.text:find("物品 #2996", 1, true) then ph = l end end
H.check(ph ~= nil, "名稱未快取顯示「物品 #id」")

-- 樹狀 tooltip：原料與冷卻在樹之前、樹最多 12 列
local res = ns.Breakdown.build(4019, 3)
local tt = ns.Format.treeTooltip(res, names(PROF_ZH), 12)
local texts = {}
for i, l in ipairs(tt.lines) do texts[i] = l.text end
local joined = table.concat(texts, "\n")
local iMat = joined:find("原料：亞麻布（24）、細線（3）、紅色染料（3）", 1, true)
local iTree = joined:find("亞麻布卷（12）", 1, true)
H.check(iMat and iTree and iMat < iTree, "原料行在樹之前")
H.check(joined:find("裁縫（技能 50）", 1, true) ~= nil, "標題下一行是專業與技能點數")

local big = { root = { recipe = 1, item = 5762, n = 1, prof = 197, children = {} }, totals = {}, cooldowns = {}, alternatives = 2 }
for i = 1, 20 do big.root.children[i] = { item = 2589, n = i, children = {} } end
local bt = ns.Format.treeTooltip(big, names(PROF_ZH), 12)
local treeRows, moreLine, altLine = 0, nil, nil
for _, l in ipairs(bt.lines) do
  if l.tree then treeRows = treeRows + 1 end
  if l.text:find("還有 8 項", 1, true) then moreLine = l end
  if l.text:find("另有 2 種做法", 1, true) then altLine = l end
end
H.eq(treeRows, 12, "樹最多 12 列")
H.check(moreLine ~= nil, "超過時顯示「…還有 8 項」")
H.check(altLine ~= nil, "多做法提示")

local cdRes = ns.Breakdown.build(12349, 1)
local ct = ns.Format.treeTooltip(cdRes, names(PROF_ZH), 12)
local cdLine
for _, l in ipairs(ct.lines) do if l.cooldown then cdLine = l end end
H.check(cdLine and cdLine.text:find("共 4 次", 1, true), "冷卻行寫總次數")

-- 審查 #5：每個專業分開記「開過視窗」；沒開過的專業在 Shift 清單標出提示
local partial = { professions = { ["197"] = true, ["129"] = true }, known = { ["2963"] = true }, opened = { ["197"] = true } }
local sp = ns.Format.shiftLines(2589, partial, names(PROF_ZH))
local tailor, firstAid
for _, l in ipairs(sp.lines) do
  if l.text:find("裁縫", 1, true) then tailor = l end
  if l.text:find("急救", 1, true) then firstAid = l end
end
H.eq(tailor.learned, true, "開過的裁縫照常判斷已學")
H.eq(firstAid.learned, nil, "沒開過的急救不判斷（未知）")
H.check(sp.notOpened and sp.notOpened:find("急救", 1, true), "提示哪些專業還沒開過視窗")

-- 使用者實測：清單與樹狀拆解的數量用「細線（4）」，不要用 ×
local tt2 = ns.Format.treeTooltip(ns.Breakdown.build(4019, 3), names(PROF_ZH), 12)
local all = {}
for _, l in ipairs(tt2.lines) do all[#all + 1] = l.text end
local jj = table.concat(all, "\n")
H.check(jj:find("×", 1, true) == nil, "樹狀拆解不出現 ×")
H.check(jj:find("紅色亞麻包（3）", 1, true) ~= nil, "標題數量用括號")
H.eq(ns.Format.firstLayer(4019, names(PROF_ZH)), "細線（1）、紅色染料（1）、亞麻布卷（4）", "清單第一層材料用括號")
