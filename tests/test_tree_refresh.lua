-- 使用者實測（2026-11-09 正式版）：完整視窗配方圖示的 tooltip 按 Shift，拆解資訊消失
-- 原因：按 Shift 時 refresh() 呼叫 RefreshData，遊戲照 tooltip 資料（SetItemByID 的物品）重建，
-- 手動加在後面的拆解樹不在資料裡，重建後就沒了
local files = H.tocFiles("SkillsItemsGuide_Mainline.toc")
for i, f in ipairs(files) do if f == "Data/Retail/Professions.lua" then files[i] = "tests/fixtures/retail_min.lua" end end

local post = {}
local tip
local shift = false
-- 模擬遊戲的 tooltip：Set* 記下資料並跑 post-call；RefreshData 清空後照資料重建（再跑一次 post-call）
local function makeTip()
  local t = { lines = {}, shown = false }
  local function build()
    t.lines = {}
    local d = t.data
    if not d then return end
    t.lines[#t.lines + 1] = "<" .. d.kind .. " " .. d.id .. ">"
    for _, fn in ipairs(post[d.kind == "item" and "Item" or "Spell"] or {}) do fn(t, { id = d.id }) end
  end
  t.SetOwner = function(self, o) self.owner = o; self.data = nil end
  t.GetOwner = function(self) return self.owner end
  t.ClearLines = function(self) self.lines = {}; self.data = nil end
  t.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
  t.SetItemByID = function(self, id) self.data = { kind = "item", id = id }; build() end
  t.SetSpellByID = function(self, id) self.data = { kind = "spell", id = id }; build() end
  t.RefreshData = function() build() end
  t.Show = function(self) self.shown = true end
  t.Hide = function(self) self.shown = false end
  t.IsShown = function(self) return self.shown end
  return t
end

local function boot()
  post = {}
  tip = makeTip()
  H.reset({ manifest = "api_manifest_retail.lua", projectId = 1, extra = {
    C_Item = { GetItemNameByID = function(id) return "名" .. id end, RequestLoadItemDataByID = function() end,
      GetItemIconByID = function() return 1 end, GetItemInfo = function() return nil end },
    C_Spell = { GetSpellName = function() return "法術" end, GetSpellTexture = function() return 1 end },
    GameTooltip = tip,
    hooksecurefunc = function() end,
    IsShiftKeyDown = function() return shift end,
    Enum = { TooltipDataType = { Item = "Item", Spell = "Spell" } },
    TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
      post[kind] = post[kind] or {}; table.insert(post[kind], fn) end },
    C_Timer = { After = function() end },
  } })
  local ns = H.load(files)
  SkillsItemsGuideCharDB = {}
  H.fire("ADDON_LOADED", "SkillsItemsGuide"); H.fire("PLAYER_LOGIN")
  return ns
end

local function count(pat)
  local n = 0
  for _, l in ipairs(tip.lines) do if tostring(l):find(pat, 1, true) then n = n + 1 end end
  return n
end

local ns = boot()
local owner = {}
ns.Window.showTree(owner, 52148)
local before = #tip.lines
local mat = "名236951" -- 52148 的材料，拆解樹會列出來
H.check(before > 2 and count(mat) >= 1, "顯示時有物品資訊與拆解樹")
H.eq(count("<item 900001>"), 1, "物品資訊一份")

-- 按 Shift：遊戲重建 tooltip 之後拆解樹還在、不重複
shift = true
H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
H.check(count(mat) >= 1, "按 Shift 後拆解樹還在")
H.eq(count("<item 900001>"), 1, "物品資訊沒有重複")
local afterShift = count(mat)
shift = false
H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
H.eq(count(mat), afterShift, "放開 Shift 後拆解樹行數不變（不會越疊越多）")

-- 游標移到別的地方（tooltip 換了 owner）：一般物品 tooltip 不能帶上拆解樹
tip:SetOwner({}, "ANCHOR_RIGHT")
tip:SetItemByID(236951)
H.eq(count("名237018"), 0, "別的物品 tooltip 不夾帶上一個配方的拆解樹")

-- 沒有成品也沒有法術對應的配方：tooltip 沒有遊戲資料，RefreshData 會清空，要改成重畫拆解樹
ns = boot()
ns.Data.recipes[2964].item = nil
ns.Data.recipes[2964].spell = nil
local o2 = {}
ns.Window.showTree(o2, 2964)
H.check(count("名237018") >= 1, "沒有遊戲資料的配方顯示拆解樹")
shift = true
H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
shift = false
H.check(count("名237018") >= 1, "沒有遊戲資料的配方按 Shift 後拆解樹還在")

-- 游標離開後 owner 清掉：同一個圖示再被遊戲畫物品時不夾帶拆解樹
ns = boot()
local o3 = {}
ns.Window.showTree(o3, 52148)
ns.Window._hideTree()
tip:SetOwner(o3, "ANCHOR_RIGHT")
tip:SetItemByID(900001)
H.eq(count("名236951"), 0, "離開後不再補拆解樹")
