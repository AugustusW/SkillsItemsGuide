local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
local known = { [133] = true }
H.reset({ locale = "zhTW", extra = {
  UnitClass = function() return "法師", "MAGE", 8 end,
  UnitLevel = function() return 18 end,
  IsSpellKnown = function(id) return known[id] == true end,
  C_Spell = { GetSpellName = function(id) return "法術" .. id end, GetSpellTexture = function() return 1 end,
              GetSpellSubtext = function() return "等級 1" end },
  C_Item = { GetItemNameByID = function() return "x" end, RequestLoadItemDataByID = function() end },
  C_CurrencyInfo = { GetCoinTextureString = function(c) return "coin" .. c end },
  RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } },
  hooksecurefunc = function() end,
  GameTooltip = { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end, Hide = function() end },
} })
local ns = H.load(files)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("PLAYER_LOGIN")

local ok, err = pcall(ns.Window.open, { tab = "skill" })
H.check(ok, "開職業技能分頁不報錯：" .. tostring(err))
local st = ns.SkillTab.state()
H.eq(st.classId, 8, "預設自己的職業")
H.eq(st.own, true, "自己的職業")
H.eq(st.checksEnabled, true, "自己的職業可以用篩選")
H.check(st.rowCount > 40, "法師有技能列（" .. tostring(st.rowCount) .. "）")
H.eq(st.scrollTo, 18, "捲到目前等級")
H.check(st.header:find("法師", 1, true) ~= nil, "標頭含職業名")

ok, err = pcall(ns.SkillTab.selectClass, 1)
H.check(ok, "切到戰士不報錯：" .. tostring(err))
st = ns.SkillTab.state()
H.eq(st.own, false, "戰士不是自己的職業")
H.eq(st.checksEnabled, false, "其他職業篩選停用")
H.check(st.header:find("不判斷學習狀態", 1, true) ~= nil, "其他職業標頭說明不判斷狀態")
H.eq(st.scrollTo, nil, "其他職業不捲動")

ns.SkillTab.selectClass(8)
ns.SkillTab.setShow({ available = true })
st = ns.SkillTab.state()
H.check(st.rowCount > 0 and st.rowCount < 40, "只看可學時列數變少（" .. st.rowCount .. "）")

H.eq(ns.SkillTab.costText(nil), "—", "學費未知顯示 —")
H.eq(ns.SkillTab.costText(0), "coin0", "學費 0 用錢幣格式")
local c = ns.SkillTab.classColor(8)
H.check(c and math.abs(c.r - 0.25) < 0.01, "職業色取 RAID_CLASS_COLORS")

-- 實測：預設帶入職業時下拉選單是空白；勾選後換職業狀態混亂
local generated = 0
ns.SkillTab._dd = { GenerateMenu = function() generated = generated + 1 end }
ns.SkillTab.setShow({ learned = true })
ns.SkillTab.selectClass(1)
H.check(generated >= 1, "換職業後刷新下拉選單顯示")
H.eq(next(ns.SkillTab.state().show), nil, "換職業時清掉勾選")
generated = 0
ns.Window.onSkillTab()
H.check(generated >= 1, "打開分頁時刷新下拉選單顯示（預設職業）")
