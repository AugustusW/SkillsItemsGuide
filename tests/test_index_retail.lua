-- 正式版索引：同一材料槽的各品質視為同一種材料（canonical），計數分當前／舊資料片
local FILES = { "Locale.lua", "Flavor.lua", "tests/fixtures/retail_min.lua", "Index.lua", "Breakdown.lua" }
H.reset({ manifest = "api_manifest_retail.lua", projectId = 1 })
local ns = H.load(FILES)
ns.Index.build()

H.eq(ns.Index.canonical(237017), 237018, "2 星奧紋布的 canonical 是 1 星")
H.eq(ns.Index.canonical(2589), 2589, "不在材料槽的物品 canonical 是自己")

local function counts(id)
  local out = {}
  for _, x in ipairs(ns.Index.profCounts(id)) do out[x.prof] = x end
  return out
end
local c1, c2 = counts(237018), counts(237017)
H.eq(c1[197] and c1[197].n, 1, "裁縫當前資料片 1 條")
H.eq(c1[197] and c1[197].old, 2, "裁縫舊資料片 2 條")
H.eq(c2[197] and c2[197].n, 1, "2 星與 1 星數字相同（當前）")
H.eq(c2[197] and c2[197].old, 2, "2 星與 1 星數字相同（舊）")
H.check(#ns.Index.usedBy(237017) == 3 and #ns.Index.usedBy(237017) == #ns.Index.usedBy(237018), "usedBy 2 星與 1 星相同")
H.check(#ns.Index.madeBy(237018) == 1 and ns.Index.madeBy(237018)[1] == 60001, "產出 2 星的配方算在 canonical 的 madeBy")

-- 排序依 n+old：只有舊的多的專業排在只有當前少的前面
local pc = ns.Index.profCounts(237018)
H.eq(pc[1].prof, 197, "排序依總數")
