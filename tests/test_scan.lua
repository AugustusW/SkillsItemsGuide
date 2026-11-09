local FILES = { "Locale.lua", "Flavor.lua", "Data/Forever/Professions.lua", "Data/Forever/ClassSkills.lua", "Core.lua", "Scan.lua" }

-- 假的訓練師：3 個服務，各有篩選狀態
local function trainerAPI(kind, filters)
  local services = {
    { name = "寒冰箭", rank = "等級 2", lv = 8, cost = 200, state = "available", id = 205 },
    { name = "暴風雪", rank = "等級 1", lv = 20, cost = 2000, state = "unavailable", id = 10 },
    { name = "火球術", rank = "等級 1", lv = 1, cost = 0, state = "used", id = 133 },
  }
  local function visible()
    local v = {}
    for _, s in ipairs(services) do if filters[s.state] then v[#v + 1] = s end end
    return v
  end
  return {
    GetNumTrainerServices = function() return #visible() end,
    GetTrainerServiceInfo = function(i) local s = visible()[i]; return s.name, s.rank, s.state end,
    GetTrainerServiceLevelReq = function(i) return visible()[i].lv end,
    GetTrainerServiceCost = function(i) return visible()[i].cost end,
    GetTrainerServiceSkillReq = function(i) return nil end,
    GetTrainerServiceTypeFilter = function(t) return filters[t] end,
    SetTrainerServiceTypeFilter = function(t, on) assert(on == true or on == false, "要傳 boolean"); filters[t] = on end,
    IsTradeskillTrainer = function() return kind == "prof" end,
    UnitClass = function() return "法師", "MAGE", 8 end,
    C_TooltipInfo = { GetTrainerService = function(i) return { id = visible()[i].id } end },
  }
end

local filters = { available = true, unavailable = false, used = false }
H.reset({ extra = trainerAPI("class", filters) })
dofile(H.dir .. "/tests/fixtures/sv_sample.lua")
local before = SkillsItemsGuideDB.trainer.class["8"].spells["116"].lv
local ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
local e = SkillsItemsGuideDB.trainer.class["8"]
H.check(e and e.spells["205"] and e.spells["10"] and e.spells["133"], "讀到所有篩選狀態的服務（含還不能學的）")
H.eq(e.spells["10"].lv, 20, "需求等級")
H.eq(e.spells["10"].cost, 2000, "學費")
H.eq(e.spells["133"].cost, 0, "學費 0 保留為 0")
H.eq(e.spells["205"].name, "寒冰箭", "存名稱")
H.eq(e.spells["205"].rank, "等級 2", "存 rank")
H.eq(e.build, "1.60.1.70399", "存 build")
H.check(filters.available == true and filters.unavailable == false and filters.used == false, "讀完後還原使用者原本的篩選")
H.eq(SkillsItemsGuideDB.trainer.class["8"].spells["116"].lv, before, "既有快取同職業其他技能保留")

-- 沒有法術 id 時用「名稱|rank」當鍵，不丟資料
H.reset({ extra = (function() local a = trainerAPI("class", { available = true, unavailable = true, used = true }); a.C_TooltipInfo = nil
  a.C_Spell = { GetSpellName = function(id) return ({ [205] = "寒冰箭", [10] = "暴風雪", [133] = "火球術" })[id] end }
  return a end)() })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
H.check(SkillsItemsGuideDB.trainer.class["8"].spells["寒冰箭|等級 2"] ~= nil, "沒有 id 時以名稱|rank 為鍵")

-- 專業訓練師：存到 prof[專業 id]
local api = trainerAPI("prof", { available = true, unavailable = true, used = true })
api.GetTrainerServiceSkillLine = function() return "裁縫" end
api.GetProfessions = function() return 1, nil end
api.GetProfessionInfo = function(i) return "裁縫", nil, 50, 75, 10, 0, 197 end
H.reset({ extra = api })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
H.check(SkillsItemsGuideDB.trainer.prof and SkillsItemsGuideDB.trainer.prof["197"] ~= nil, "專業訓練師存到 prof[197]")

-- 專業與已學配方：登入時記下學了哪些專業；開專業視窗時記下已學配方（客戶端 recipeID＝法術 id）
local recipes = { [2963] = { learned = true }, [2964] = { learned = false }, [3915] = { learned = true } }
H.reset({ extra = {
  GetProfessions = function() return 3, nil, nil end,
  GetProfessionInfo = function(i) return "裁縫", nil, 50, 75, 10, 0, 197 end,
  C_TradeSkillUI = {
    GetAllRecipeIDs = function() local t = {} for id in pairs(recipes) do t[#t + 1] = id end return t end,
    GetRecipeInfo = function(id) return recipes[id] end,
  },
} })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("PLAYER_LOGIN")
H.check(SkillsItemsGuideCharDB.professions["197"] == true, "登入時記下學了裁縫")
H.check(next(SkillsItemsGuideCharDB.opened or {}) == nil, "還沒開專業視窗")
H.fire("TRADE_SKILL_LIST_UPDATE")
H.check(SkillsItemsGuideCharDB.known["2963"] and SkillsItemsGuideCharDB.known["3915"], "已學配方寫入 known")
H.check(SkillsItemsGuideCharDB.known["2964"] == nil, "未學的不寫")
H.check(SkillsItemsGuideCharDB.opened["197"] == true, "依配方所屬專業標記開過裁縫視窗")
H.check(SkillsItemsGuideCharDB.opened["129"] == nil, "沒開過的急救不標記")

-- 審查 #12：讀取中途出錯也要還原篩選；不是職業訓練師（武器大師、寵物、騎術）不寫入 class
local f2 = { available = true, unavailable = false, used = false }
local api2 = trainerAPI("class", f2)
api2.GetTrainerServiceCost = function() error("boom") end
H.reset({ extra = api2 })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
pcall(H.fire, "TRAINER_SHOW")
H.check(f2.available == true and f2.unavailable == false and f2.used == false, "中途出錯仍還原篩選")

local f3 = { available = true, unavailable = true, used = true }
local api3 = trainerAPI("class", f3)
local origInfo = api3.GetTrainerServiceInfo
api3.GetTrainerServiceInfo = function(i) local _, rank, state = origInfo(i); return "雙手劍", rank, state end
api3.C_TooltipInfo = { GetTrainerService = function(i) return { id = 900000 + i } end }
H.reset({ extra = api3 })
ns = H.load(FILES)
ns.Data.classSkills = { [8] = { { spell = 133, lv = 1 }, { spell = 116, lv = 4 } } }
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
H.check(not (SkillsItemsGuideDB.trainer and SkillsItemsGuideDB.trainer.class and SkillsItemsGuideDB.trainer.class["8"]),
  "服務都不是本職業技能時（武器大師等）不寫入")

-- 實測：開訓練師後存檔沒有資料。TRAINER_SHOW 當下清單可能還是空的，要在 TRAINER_UPDATE 再讀；每次讀取記錄診斷
local services = 0
local f4 = { available = true, unavailable = true, used = true }
local api4 = trainerAPI("class", f4)
local origNum = api4.GetNumTrainerServices
api4.GetNumTrainerServices = function() return services == 0 and 0 or origNum() end
H.reset({ extra = api4 })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
H.check(not (SkillsItemsGuideDB.trainer and SkillsItemsGuideDB.trainer.class), "開啟當下清單是空的：先不寫")
H.eq(SkillsItemsGuideDB.trainerDebug.count, 0, "診斷記下讀到 0 筆")
services = 3
H.fire("TRAINER_UPDATE")
H.check(SkillsItemsGuideDB.trainer and SkillsItemsGuideDB.trainer.class["8"] ~= nil, "TRAINER_UPDATE 時讀到資料並寫入")
H.eq(SkillsItemsGuideDB.trainerDebug.count, 3, "診斷記下讀到 3 筆")
H.eq(SkillsItemsGuideDB.trainerDebug.saved, true, "診斷記下已寫入")

-- 改篩選會觸發 TRAINER_UPDATE：不能因此無限重讀；同一次造訪寫入成功後不再重讀
local calls = 0
local f5 = { available = true, unavailable = true, used = true }
local api5 = trainerAPI("class", f5)
local origSet = api5.SetTrainerServiceTypeFilter
api5.SetTrainerServiceTypeFilter = function(t, on) calls = calls + 1; origSet(t, on); H.fire("TRAINER_UPDATE") end
H.reset({ extra = api5 })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
H.fire("TRAINER_UPDATE")
H.check(calls <= 6, "改篩選觸發的 TRAINER_UPDATE 不會造成重複讀取（篩選設定 " .. calls .. " 次）")
H.fire("TRAINER_CLOSED")
calls = 0
H.fire("TRAINER_SHOW")
H.check(calls > 0, "下次打開訓練師會再讀")

-- /sigcheck 也印出最近一次訓練師讀取的診斷
H.check(ns.trainerDebugText():find("count=", 1, true) ~= nil, "訓練師診斷文字")
SkillsItemsGuideDB.trainerDebug = nil
H.check(ns.trainerDebugText():find("no trainer", 1, true) ~= nil, "沒有讀過訓練師時的文字")

-- 使用者要求：登入時提示還沒開過視窗的專業（全部開過就不提示）
local printed = {}
H.reset({ locale = "zhTW", extra = {
  GetProfessions = function() return 1, 2 end,
  GetProfessionInfo = function(i) if i == 1 then return "裁縫", nil, 1, 75, 1, 0, 197 end return "急救", nil, 1, 75, 1, 0, 129 end,
} })
ns = H.load(FILES)
print = function(s) printed[#printed + 1] = s end
SkillsItemsGuideCharDB = { opened = { ["197"] = true } }
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("PLAYER_LOGIN")
local joined = table.concat(printed, "\n")
H.check(joined:find("急救", 1, true) ~= nil and joined:find("裁縫", 1, true) == nil, "提示只列沒開過的專業（急救）")
printed = {}
SkillsItemsGuideCharDB.opened["129"] = true
H.fire("PLAYER_LOGIN")
H.eq(#printed, 0, "全部開過就不提示")

-- 審查 Important：讀到資料但不寫入（武器大師等）也要結束這次造訪，否則非同步 TRAINER_UPDATE 會一直重讀
local calls6 = 0
local f6 = { available = true, unavailable = true, used = true }
local api6 = trainerAPI("class", f6)
local origInfo6 = api6.GetTrainerServiceInfo
api6.GetTrainerServiceInfo = function(i) local _, rank, state = origInfo6(i); return "雙手劍", rank, state end
api6.C_TooltipInfo = { GetTrainerService = function(i) return { id = 900000 + i } end }
local origSet6 = api6.SetTrainerServiceTypeFilter
api6.SetTrainerServiceTypeFilter = function(t, on) calls6 = calls6 + 1; origSet6(t, on) end
H.reset({ extra = api6 })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRAINER_SHOW")
local afterFirst = calls6
H.fire("TRAINER_UPDATE"); H.fire("TRAINER_UPDATE")
H.eq(calls6, afterFirst, "非本職業訓練師讀過一次後，之後的 TRAINER_UPDATE 不再重讀")

-- 審查 Important：只學採集專業（沒有任何已學配方）也要能標記開過視窗
H.reset({ extra = {
  C_TradeSkillUI = { GetAllRecipeIDs = function() return { 2963 } end, GetRecipeInfo = function() return { learned = false } end },
} })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("TRADE_SKILL_SHOW")
H.check(SkillsItemsGuideCharDB.opened["197"] == true, "沒有已學配方時，依視窗列出的配方標記開過")
