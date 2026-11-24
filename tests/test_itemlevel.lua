-- 物品 tooltip 的物品等級：插在名稱的下一行（使用者 2026-11-24 選 B），只限武器與護甲
local FILES = { "Locale.lua", "Flavor.lua", "Data/Forever/Professions.lua", "Data/Forever/ClassSkills.lua", "Data/Forever/Cache.lua",
  "Data/Forever/Items.lua", "Index.lua", "Breakdown.lua", "Format.lua", "Names.lua", "Core.lua", "Tooltip.lua", "ItemLevel.lua", "DbIndex.lua" }

local postCall
local INFO = {
  [100] = { "巴隆的節杖", 26, 2 },   -- 武器
  [200] = { "布甲上衣", 15, 4 },     -- 護甲
  [300] = { "亞麻布", 5, 7 },        -- 商品：不加
  [400] = { "破舊皮帶", 12, 4 },     -- 隨機後綴綠裝：tooltip 名稱是「破舊皮帶之猴」
  [500] = { "藍色襯衫", 1, 4, "INVTYPE_BODY" }, -- 襯衫：不加
}
-- 假 tooltip：行是具名的 FontString（GameTooltipTextLeftN），跟遊戲一樣用名字找
local function newTooltip(name, lefts, rights)
  local tt = { _name = name, n = #lefts, shows = 0, added = {}, shown = true }
  local function fs(text, shown)
    local f = { t = text, shown = shown ~= false }
    function f:GetText() return self.t end
    function f:SetText(t) self.t = t end
    function f:IsShown() return self.shown end
    return f
  end
  for i, t in ipairs(lefts) do
    _G[name .. "TextLeft" .. i] = fs(t)
    _G[name .. "TextRight" .. i] = fs((rights or {})[i])
  end
  function tt:GetName() return self._name end
  function tt:NumLines() return self.n end
  function tt:Show() self.shows = self.shows + 1 end
  function tt:IsShown() return self.shown end
  -- 跟遊戲一樣：AddLine 會多出一行具名的 FontString
  function tt:AddLine(t)
    self.added[#self.added + 1] = t
    self.n = self.n + 1
    _G[name .. "TextLeft" .. self.n] = fs(t)
    _G[name .. "TextRight" .. self.n] = fs(nil, false)
  end
  return tt
end
local function left(name, i) return _G[name .. "TextLeft" .. i]:GetText() end
local function right(name, i) return _G[name .. "TextRight" .. i]:GetText() end

local function boot(locale)
  H.reset({ locale = locale or "zhTW", extra = {
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) if kind == "ITEM" then postCall = fn end end },
    Enum = { TooltipDataType = { Item = "ITEM" } },
    WOW_PROJECT_ID = 18,
    IsShiftKeyDown = function() return false end,
    C_Spell = { GetSpellName = function() return nil end },
    hooksecurefunc = function() end,
    C_Item = { GetItemNameByID = function() return nil end, RequestLoadItemDataByID = function() end, GetItemInfo = function(id)
      local r = INFO[id]
      if not r then return nil end
      return r[1], "item:" .. id, 2, r[2], 1, "t", "s", 1, r[4] or "INVTYPE_WEAPON", 1, 1, r[3]
    end },
  } })
  postCall = nil
  local ns = H.load(FILES)
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  return ns
end

local GOLD = "|cffffd100"
boot()
H.check(type(postCall) == "function", "Tooltip.lua 的 Item PostCall 有掛上（物品等級在裡面呼叫）")

-- 一般 tooltip：名稱在第 1 行，等級插進第 2 行開頭，原本第 2 行的字留在下面
local tt = newTooltip("GameTooltip", { "巴隆的節杖", "已綁定", "主手" }, { nil, nil, "錘" })
postCall(tt, { id = 100 })
H.eq(left("GameTooltip", 2), GOLD .. "物品等級 26|r\n已綁定", "第 2 行開頭是金色物品等級，原本內容換到下一行")
H.eq(left("GameTooltip", 1), "巴隆的節杖", "名稱行不動")
H.eq(left("GameTooltip", 3), "主手", "其他行不動")
H.eq(tt.shows, 1, "顯示中的 tooltip 改完重新 Show 一次，讓大小重算")
tt = newTooltip("GameTooltip", { "巴隆的節杖", "已綁定" })
tt.shown = false
postCall(tt, { id = 100 })
H.eq(tt.shows, 0, "還沒顯示的 tooltip（掃描用、尚未 SetOwner）不替它 Show")
H.eq(left("GameTooltip", 2), GOLD .. "物品等級 26|r\n已綁定", "還沒顯示的 tooltip 一樣插入")

-- 第 2 行有右欄（例如沒有綁定字樣時的「主手／錘」）：右欄前面加換行，跟左欄原本的字對齊
tt = newTooltip("GameTooltip", { "巴隆的節杖", "主手" }, { nil, "錘" })
postCall(tt, { id = 100 })
H.eq(left("GameTooltip", 2), GOLD .. "物品等級 26|r\n主手", "左欄插入等級")
H.eq(right("GameTooltip", 2), "\n錘", "右欄往下一行，跟「主手」同一行")

-- 比較框：第 1 行是「目前已裝備」，名稱在第 2 行 → 等級插在第 3 行
tt = newTooltip("ShoppingTooltip1", { "目前已裝備", "布甲上衣", "已綁定" })
postCall(tt, { id = 200 })
H.eq(left("ShoppingTooltip1", 3), GOLD .. "物品等級 15|r\n已綁定", "比較框插在名稱的下一行")
H.eq(left("ShoppingTooltip1", 2), "布甲上衣", "比較框的名稱行不動")

-- 同一個 tooltip 再跑一次（例如按 Shift 重新整理但行沒清掉）不會疊兩次
postCall(tt, { id = 200 })
H.eq(left("ShoppingTooltip1", 3), GOLD .. "物品等級 15|r\n已綁定", "不重複插入")

-- 只有名稱一行：加在最後（也就是第 2 行）；再跑一次不會再加
tt = newTooltip("GameTooltip", { "巴隆的節杖" })
postCall(tt, { id = 100 })
H.eq(tt.added[1], GOLD .. "物品等級 26|r", "只有名稱時用 AddLine 加在第 2 行")
postCall(tt, { id = 100 })
H.eq(#tt.added, 1, "只有名稱的 tooltip 再跑一次不重複加")

-- 第 2 行的右欄是隱藏的殘字（ClearLines 後沒清掉）：不動它
tt = newTooltip("GameTooltip", { "巴隆的節杖", "已綁定" }, { nil, "舊的" })
_G.GameTooltipTextRight2.shown = false
postCall(tt, { id = 100 })
H.eq(right("GameTooltip", 2), "舊的", "隱藏的右欄不加換行")

-- 隨機後綴：名稱行比基底名長，仍找得到
tt = newTooltip("GameTooltip", { "破舊皮帶之猴", "拾取後綁定" })
postCall(tt, { id = 400 })
H.eq(left("GameTooltip", 2), GOLD .. "物品等級 12|r\n拾取後綁定", "帶後綴的名稱也插在下一行")

-- 前三行都找不到名稱：不亂插
tt = newTooltip("GameTooltip", { "別的東西", "已綁定", "主手" })
postCall(tt, { id = 100 })
H.check(left("GameTooltip", 2) == "已綁定" and left("GameTooltip", 3) == "主手" and #tt.added == 0, "找不到名稱行就不改")

-- 襯衫、公會袍不顯示
tt = newTooltip("GameTooltip", { "藍色襯衫", "襯衫" })
postCall(tt, { id = 500 })
H.eq(left("GameTooltip", 2), "襯衫", "襯衫不顯示物品等級")

-- 不是武器或護甲：不加
tt = newTooltip("GameTooltip", { "亞麻布", "商品" })
postCall(tt, { id = 300 })
H.eq(left("GameTooltip", 2), "商品", "商品不顯示物品等級")

-- 遊戲還沒有物品資訊、打包資料也沒有：不加、不報錯
tt = newTooltip("GameTooltip", { "?", "x" })
local ok = pcall(postCall, tt, { id = 999 })
H.check(ok and left("GameTooltip", 2) == "x", "查不到等級時不改 tooltip")

-- 沒有名字的 tooltip（內嵌）與沒有 id：不動
local anon = newTooltip("Anon", { "巴隆的節杖", "已綁定" })
anon._name = nil
H.check(pcall(postCall, anon, { id = 100 }), "沒有名字的 tooltip 不報錯")
H.eq(left("Anon", 2), "已綁定", "沒有名字的 tooltip 不改")
H.check(pcall(postCall, newTooltip("GameTooltip", { "a" }), nil), "沒有 data 不報錯")

-- 英文客戶端
boot("enUS")
tt = newTooltip("GameTooltip", { "巴隆的節杖", "Soulbound" })
postCall(tt, { id = 100 })
H.eq(left("GameTooltip", 2), GOLD .. "Item Level 26|r\nSoulbound", "英文用 Item Level")

-- 遊戲還沒有物品資訊時用打包資料（Items.lua）：挑一件打包資料裡的武器
local ns2 = boot()
local gid, grec
for id, r in pairs(ns2.DbIndex.allItems()) do
  if r.c == 2 and r.il and r.il > 1 and r.name and r.name ~= "" and not INFO[id] then gid, grec = id, r; break end
end
H.check(gid ~= nil, "打包資料裡找得到武器")
tt = newTooltip("GameTooltip", { grec.name, "已綁定" })
postCall(tt, { id = gid })
H.eq(left("GameTooltip", 2), GOLD .. "物品等級 " .. grec.il .. "|r\n已綁定", "遊戲沒資料時用打包資料的等級與名稱")

-- 遊戲回報的等級優先於打包資料
INFO[gid] = { grec.name, grec.il + 7, 2 }
tt = newTooltip("GameTooltip", { grec.name, "已綁定" })
postCall(tt, { id = gid })
H.eq(left("GameTooltip", 2), GOLD .. "物品等級 " .. (grec.il + 7) .. "|r\n已綁定", "遊戲回報的等級優先")
INFO[gid] = nil
