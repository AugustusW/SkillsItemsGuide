-- 正式版索引測試用的最小資料：同一材料槽兩種品質、當前與舊資料片、成品是非 canonical 品質
local _, ns = ...
ns.Data = ns.Data or {}
local D = ns.Data
D.meta = { generated = "fixture", profVersion = "static-12.1.5_70077-tw" }
D.professions = { [197] = { type = "PRIMARY" }, [171] = { type = "PRIMARY" } }
D.items = { [236951] = { il = 80, q = 3 }, [237018] = { il = 80, q = 2 }, [237017] = { il = 80, q = 2 },
  [2589] = { il = 5, q = 1 }, [900001] = { il = 80, q = 3 } }
D.tiers = {
  [2918] = { p = 197, name = "至暗之夜裁縫", cur = true },
  [2540] = { p = 197, name = "艾澤拉斯裁縫", cur = false },
  [2900] = { p = 171, name = "至暗之夜鍊金術", cur = true },
}
D.slotGroups = { [237018] = { 237018, 237017 } }
D.recipes = {
  [52148] = { p = 197, t = 2918, item = 900001, q = 1, r = { { 236951, 4 }, { 237018, 5 } } },  -- 當前：用奧紋布
  [2963]  = { p = 197, t = 2540, item = 2996, q = 1, r = { { 237018, 2 } } },                     -- 舊：也用奧紋布（測試用）
  [2964]  = { p = 197, t = 2540, item = 2997, q = 1, r = { { 237018, 3 } } },                     -- 舊
  [60001] = { p = 171, t = 2900, item = 237017, q = 1, r = { { 2589, 1 } } },                     -- 產出 2 星奧紋布
}
