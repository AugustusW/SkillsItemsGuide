-- SavedVariables 結構的唯一定義（Task 3 的 merge_cache 與 Task 6 的 Scan 測試共用）
-- 鍵一律是字串化的數字，避免轉 JSON 時型態漂移
SkillsItemsGuideDB = {
  dbVersion = 1,
  trainer = {
    class = {
      ["8"] = { build = "1.60.1.70399", date = "2026-11-08",
        spells = { ["116"] = { lv = 6, cost = 100, name = "寒冰箭", rank = "等級 1" },
                   ["133"] = { lv = 1, cost = 0, name = "火球術", rank = "等級 1" } } },
    },
    prof = {
      ["197"] = { build = "1.60.1.70399", date = "2026-11-08",
        spells = { ["2963"] = { skill = 1, cost = 10, name = "亞麻布卷" } } },
    },
  },
}
SkillsItemsGuideCharDB = { professions = { ["197"] = true }, known = { ["2963"] = true }, opened = { ["197"] = true } }
