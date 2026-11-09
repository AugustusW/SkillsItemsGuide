-- 介面文字與標點：依客戶端語系（GetLocale）。zhTW 用中文與全形標點，其他語系一律英文。
local _, ns = ...

local LOCALES = {}
LOCALES.enUS = {
  OPEN = " (", CLOSE = ")", SEP = ", ", COLON = ": ",
  WITH_OLD_FMT = "%d, %d older", OLD_ONLY_FMT = "%d older",
  PROBE_TITLE = "SkillsItemsGuide probe",
  PROBE_HINT = "Click the text, Ctrl+A then Ctrl+C to copy, paste it back. Esc closes. Then follow the click test steps below.",
  PROBE_CLICK_STEPS = "Click test: use a stack of grey junk. Alt+left-click it in your bag (1) with the chat box closed, (2) with the chat box open, (3) with a vendor open. Then type /sigprobe again.",
  SLASH_TAKEN = "SkillsItemsGuide: %s is used by another addon, not registered.",
  TIMES = "x", SKILL = "skill", MATERIALS = "Materials", COOLDOWN = "Cooldown",
  COOLDOWN_FMT = "%s %d times (%s each)", MORE = "...%d more", ALTERNATIVES = "%d other ways to make this",
  ITEM_PLACEHOLDER = "Item #%d", RECIPE_PLACEHOLDER = "Recipe #%d",
  SHIFT_EMPTY = "None of your professions use this", SHIFT_MORE = "...%d more",
  OPEN_HINT = "Alt+left-click: open full window",
  COMPARTMENT_HINT = "Click to open or close the full window. Also /sig, or Alt+left-click an item in your bags.",
  USED_BY_FMT = "used by %d recipes", ALL_PROFESSIONS = "All professions", NAMES_LOADING = "Names loading...",
  SEARCH_EMPTY = "No results", PROF_EMPTY = "No recipe data", ADDON_TITLE = "SkillsItemsGuide",
  TAB_PROF = "Professions", TAB_SKILL = "Class skills", CLEAR = "Clear", QUANTITY = "Qty",
  LIST_HINT = "Hover an icon for the breakdown, click + to expand", NOT_OPENED_FMT = "Open the %s window once to mark learned recipes",
  DATA_VERSION = "Data %s", FOOTER_FMT = "v%s · %s · %s  |  Data %s", OVERFLOW_FMT = "...%d more, use search or pick a profession",
  CLASS_LABEL = "Class", SEARCH_SKILL = "Search skills", SHOW_LEARNED = "Learned", SHOW_AVAILABLE = "Can learn",
  SHOW_TOOLOW = "Level too low", LV_FMT = "Level %d", LV_CURRENT = " (current)", LV_NEXT = " (next)",
  YOU_FMT = "You: %s level %d", BROWSE_FMT = "Browsing: %s (learning state not checked)",
  NOT_TRAINER = "not from trainer", TRAINER_HINT = "Open your class trainer window once to show costs and verify levels",
  SOURCE_VERIFIED = "Verified (%s, %s)", SOURCE_CLIENT = "Client data (%s beta)", NO_SKILLS = "No skill data",
  CHECK_FMT = "SkillsItemsGuide: client reports %d learned recipes, %d match the bundled data",
}
LOCALES.zhTW = {
  OPEN = "（", CLOSE = "）", SEP = "、", COLON = "：",
  WITH_OLD_FMT = "%d，舊資料片 %d", OLD_ONLY_FMT = "舊資料片 %d",
  PROBE_TITLE = "SkillsItemsGuide 探測",
  PROBE_HINT = "點一下文字，按 Ctrl+A 再按 Ctrl+C 複製，貼回 Telegram。按 Esc 關閉。接著照下面的點擊測試做。",
  PROBE_CLICK_STEPS = "點擊測試：請用一疊灰色垃圾，在背包對它 Alt+左鍵：(1) 聊天框關著、(2) 聊天輸入框開著、(3) 商人視窗開著，各一次。做完再打一次 /sigprobe。",
  SLASH_TAKEN = "SkillsItemsGuide：%s 已被其他插件使用，不註冊。",
  TIMES = "×", SKILL = "技能", MATERIALS = "原料", COOLDOWN = "冷卻",
  COOLDOWN_FMT = "%s 共 %d 次（每次 %s）", MORE = "…還有 %d 項", ALTERNATIVES = "另有 %d 種做法",
  ITEM_PLACEHOLDER = "物品 #%d", RECIPE_PLACEHOLDER = "配方 #%d",
  SHIFT_EMPTY = "沒有學會的專業用到它", SHIFT_MORE = "…還有 %d 條",
  OPEN_HINT = "Alt+左鍵：開啟完整視窗",
  COMPARTMENT_HINT = "點擊開關完整視窗。也可以輸入 /sig，或在背包物品上 Alt+左鍵。",
  USED_BY_FMT = "被 %d 條配方使用", ALL_PROFESSIONS = "全部專業", NAMES_LOADING = "名稱載入中…",
  SEARCH_EMPTY = "沒有符合的結果", PROF_EMPTY = "這個專業沒有配方資料", ADDON_TITLE = "技能物品指南",
  TAB_PROF = "專業", TAB_SKILL = "職業技能", CLEAR = "清除", QUANTITY = "數量",
  LIST_HINT = "滑鼠移到圖示看拆解，點 + 展開", NOT_OPENED_FMT = "開一次%s視窗即可標示已學",
  DATA_VERSION = "資料版本 %s", FOOTER_FMT = "v%s · %s · 問題回報 %s  |  資料版本 %s", OVERFLOW_FMT = "…還有 %d 條，請用搜尋或選專業縮小範圍",
  CLASS_LABEL = "職業", SEARCH_SKILL = "搜尋技能", SHOW_LEARNED = "已學會", SHOW_AVAILABLE = "可以學但還沒學",
  SHOW_TOOLOW = "等級還不到", LV_FMT = "%d 級", LV_CURRENT = "（目前）", LV_NEXT = "（下一級）",
  YOU_FMT = "你：%s %d 級", BROWSE_FMT = "瀏覽：%s（不判斷學習狀態）",
  NOT_TRAINER = "非訓練師", TRAINER_HINT = "到職業訓練師打開一次視窗，就能顯示學費並校正等級",
  SOURCE_VERIFIED = "已校正（%s，%s）", SOURCE_CLIENT = "客戶端資料（%s beta）", NO_SKILLS = "沒有技能資料",
  CHECK_FMT = "技能物品指南：客戶端回報 %d 個已學配方，其中 %d 個對得上資料",
}
-- 職業（ChrClasses id → 名稱、RAID_CLASS_COLORS 的鍵）
local CLASS_TOKEN = { [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST", [7] = "SHAMAN",
  [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID" }
local CLASS = {
  enUS = { [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue", [5] = "Priest", [7] = "Shaman", [8] = "Mage",
    [9] = "Warlock", [11] = "Druid" },
  zhTW = { [1] = "戰士", [2] = "聖騎士", [3] = "獵人", [4] = "盜賊", [5] = "牧師", [7] = "薩滿", [8] = "法師",
    [9] = "術士", [11] = "德魯伊" },
}
ns.CLASS_TOKEN = CLASS_TOKEN

-- 專業名稱（12 個固定 skillLine；探測沒有可用的 id→名稱 API）
local PROF = {
  enUS = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [182] = "Herbalism",
    [185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting",
    [356] = "Fishing", [393] = "Skinning", [755] = "Jewelcrafting", [773] = "Inscription" },
  zhTW = { [129] = "急救", [164] = "鍛造", [165] = "製皮", [171] = "鍊金術", [182] = "草藥學", [185] = "烹飪",
    [186] = "採礦", [197] = "裁縫", [202] = "工程學", [333] = "附魔", [356] = "釣魚", [393] = "剝皮", [755] = "珠寶設計", [773] = "銘文學" },
}
ns.LOCALES = LOCALES

local L = setmetatable({}, { __index = function(_, k)
  local t = LOCALES[GetLocale()] or LOCALES.enUS
  local v = t[k]
  if v == nil then v = LOCALES.enUS[k] end
  return v
end })

function L.paren(name, n) return name .. L.OPEN .. tostring(n) .. L.CLOSE end
-- 正式版計數：「12，舊資料片 40」「舊資料片 40」（括號由 L.paren 加）
function L.withOld(n, old) return string.format(L.WITH_OLD_FMT, n, old) end
function L.oldOnly(old) return string.format(L.OLD_ONLY_FMT, old) end
function L.join(list) return table.concat(list, L.SEP) end
function L.label(a, b) return a .. L.COLON .. b end
function L.class(id)
  local t = CLASS[GetLocale()] or CLASS.enUS
  return t[id] or CLASS.enUS[id] or tostring(id)
end
function L.prof(id)
  local t = PROF[GetLocale()] or PROF.enUS
  return t[id] or PROF.enUS[id] or tostring(id)
end

ns.L = L
