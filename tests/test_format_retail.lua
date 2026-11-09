-- 正式版 tooltip：當前資料片數字＋舊資料片數量；Shift 清單當前在前、舊的標資料片
local FILES = { "Locale.lua", "Flavor.lua", "tests/fixtures/retail_min.lua", "Index.lua", "Breakdown.lua", "Format.lua" }
local ITEM = { [236951] = "狂野魔法微粒", [237018] = "奧紋布", [237017] = "奧紋布", [900001] = "奧紋布卷",
  [2996] = "舊布卷", [2997] = "舊布卷二", [237017.5] = nil }
local PROF = { zhTW = { [197] = "裁縫", [171] = "鍊金術" }, enUS = { [197] = "Tailoring", [171] = "Alchemy" } }
local cur = "zhTW"
local function names()
  return { item = function(id) return ITEM[id] end, prof = function(id) return PROF[cur][id] end,
    recipe = function() return nil end }
end
local function boot(locale)
  cur = locale
  H.reset({ manifest = "api_manifest_retail.lua", projectId = 1, locale = locale })
  local ns = H.load(FILES)
  ns.Index.build()
  return ns
end

local ns = boot("zhTW")
H.eq(ns.Format.countsLine(237018, names()), "裁縫（1，舊資料片 2）", "當前與舊都有")
H.eq(ns.Format.countsLine(237017, names()), "裁縫（1，舊資料片 2）", "2 星與 1 星相同")

-- 只有舊資料片：拿掉當前那條
ns.Data.recipes[52148] = nil
ns.Index.build()
H.eq(ns.Format.countsLine(237018, names()), "裁縫（舊資料片 2）", "只有舊資料片時不顯示 0")

-- 只有當前：維持原格式
ns = boot("zhTW")
H.eq(ns.Format.countsLine(236951, names()), "裁縫（1）", "只有當前資料片時格式不變")

-- 排序依總數：裁縫 n=1 old=2（3）排在只有 1 條的專業前面
ns.Data.recipes[70001] = { p = 171, t = 2900, item = 2589, q = 1, r = { { 237018, 1 } } }
ns.Index.build()
H.eq(ns.Format.countsLine(237018, names()), "裁縫（1，舊資料片 2）、鍊金術（1）", "依總數排序")

-- 英文
ns = boot("enUS")
H.eq(ns.Format.countsLine(237018, names()), "Tailoring (1, 2 older)", "enUS 當前與舊")
ns.Data.recipes[52148] = nil; ns.Index.build()
H.eq(ns.Format.countsLine(237018, names()), "Tailoring (2 older)", "enUS 只有舊")

-- Shift：用 2 星查，數量不是 0；當前在前；舊的標資料片名稱
ns = boot("zhTW")
local char = { professions = { ["197"] = true }, opened = { ["197"] = true }, known = {} }
local sl = ns.Format.shiftLines(237017, char, names())
H.check(sl.lines[1] and sl.lines[1].recipe == 52148, "當前資料片的配方排第一")
H.check(sl.lines[1] and sl.lines[1].text:find("奧紋布（5）", 1, true) ~= nil, "用 2 星查，數量顯示 5 不是 0：" .. tostring(sl.lines[1] and sl.lines[1].text))
local oldLine
for _, l in ipairs(sl.lines) do if l.recipe == 2963 then oldLine = l end end
H.check(oldLine and oldLine.text:find("（艾澤拉斯裁縫）", 1, true) ~= nil, "舊資料片的行尾標資料片名稱：" .. tostring(oldLine and oldLine.text))
H.check(sl.lines[1].text:find("至暗之夜", 1, true) == nil, "當前資料片不標")
