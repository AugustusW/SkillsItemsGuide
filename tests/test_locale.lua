-- 語系完整性：zhTW 缺 key 時會靜默退回英文，所以兩份 key 集合必須一致；英文字串不得含 CJK
H.reset({ locale = "enUS" })
local ns = H.load({ "Locale.lua" })
local en, zh = ns.LOCALES.enUS, ns.LOCALES.zhTW
H.check(type(en) == "table" and type(zh) == "table", "ns.LOCALES 有 enUS 與 zhTW")

local function keys(t) local r = {} for k in pairs(t) do r[#r + 1] = k end table.sort(r) return r end

for _, k in ipairs(keys(en)) do H.check(zh[k] ~= nil, "zhTW 缺 key：" .. k) end
for _, k in ipairs(keys(zh)) do H.check(en[k] ~= nil, "enUS 缺 key：" .. k) end

-- 同一個 key 兩邊型別一致；表格（REP_RANKS）長度一致，格式字串的 % 佔位符數量一致
local function placeholders(s)
  local r = {}
  for spec in s:gsub("%%%%", ""):gmatch("%%[%d%.%-]*%a") do r[#r + 1] = spec end
  return table.concat(r, ",")
end
for _, k in ipairs(keys(en)) do
  local a, b = en[k], zh[k]
  if b ~= nil then
    H.eq(type(b), type(a), "型別一致：" .. k)
    if type(a) == "table" then
      H.eq(#b, #a, "表格長度一致：" .. k)
    elseif type(a) == "string" and type(b) == "string" then
      H.eq(placeholders(b), placeholders(a), "格式佔位符順序一致：" .. k)
    end
  end
end

-- 來源功能新增的字串兩邊都要有
local NEW = { "SRC_TITLE", "SRC_AUTO", "SRC_TRAINER", "SRC_TRAINER_COST_FMT", "SRC_TRAINER_GUESS", "SRC_TRAINER_GUESS_HINT", "SRC_TRAINER_GUESS_HINT_FMT",
  "SRC_BOOK_FMT", "SRC_SIDE_A", "SRC_SIDE_H", "SRC_QUEST_FMT", "SRC_QUEST_AREA_FMT", "SRC_QUEST_AREA_ONLY_FMT",
  "SRC_MORE_FMT", "SRC_REQ_SKILL_FMT", "SRC_REQ_LEVEL_FMT", "SRC_BIND_1", "SRC_BIND_2", "SRC_REP_FMT",
  "SRC_RANGE_TITLE", "SRC_TAG_AUTO", "SRC_TAG_BOOK", "SRC_TAG_TRAINER", "REP_RANKS", "TRAINER_HINT" }
for _, k in ipairs(NEW) do
  H.check(en[k] ~= nil, "enUS 有來源字串：" .. k)
  H.check(zh[k] ~= nil, "zhTW 有來源字串：" .. k)
end
H.eq(#en.REP_RANKS, 8, "聲望等級 8 個")

-- 英文字串不含 CJK（UTF-8 CJK 與全形標點的首位元組 >= 0xE3）
local function hasCJK(s) for i = 1, #s do if s:byte(i) >= 0xE3 then return true end end return false end
for _, k in ipairs(keys(en)) do
  local v = en[k]
  if type(v) == "string" then
    H.check(not hasCJK(v), "enUS 不含中文：" .. k)
  elseif type(v) == "table" then
    for i, s in ipairs(v) do H.check(not hasCJK(s), "enUS 不含中文：" .. k .. "[" .. i .. "]") end
  end
end
-- 反向對照：zhTW 的來源標籤確實是中文（確認 hasCJK 判得出來）
H.check(hasCJK(zh.SRC_TAG_AUTO), "hasCJK 能判出中文")
