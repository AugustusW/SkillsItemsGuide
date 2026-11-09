-- 依 toc 順序載入全部檔案，模擬登入流程；只有 manifest 白名單的全域存在
local files = H.tocFiles("SkillsItemsGuide_Forever.toc")
H.reset()
local ok, ns = pcall(H.load, files)
H.check(ok, "依 toc 載入全部檔案不報錯：" .. tostring(not ok and ns or ""))
local ok2, err = pcall(function()
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  H.fire("TRADE_SKILL_SHOW")
  H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
end)
H.check(ok2, "登入流程與事件不報錯：" .. tostring(err))
H.check(ok and #ns.Index.usedBy(2589) == 12, "載入後反查索引已建立")

-- 正式版（_Mainline TOC、正式版 API 白名單、WOW_PROJECT_ID=1）
H.reset({ manifest = "api_manifest_retail.lua", projectId = 1 })
local rfiles = H.tocFiles("SkillsItemsGuide_Mainline.toc")
local okR, nsR = pcall(H.load, rfiles)
H.check(okR, "正式版依 toc 載入不報錯：" .. tostring(not okR and nsR or ""))
local okR2, errR = pcall(function()
  H.fire("ADDON_LOADED", "SkillsItemsGuide")
  H.fire("PLAYER_LOGIN")
  H.fire("TRADE_SKILL_SHOW")
end)
H.check(okR2, "正式版登入流程不報錯：" .. tostring(errR))
H.check(okR and nsR.Flavor.isRetail(), "正式版 Flavor 判斷為 retail")
H.check(okR and nsR.SkillTab == nil, "正式版不載入職業技能分頁")
local trainerReg = false
for _, f in ipairs(H.frames) do if f._events.TRAINER_UPDATE then trainerReg = true end end
H.check(not trainerReg, "正式版不註冊訓練師事件")
for _, f in ipairs(rfiles) do H.check(not f:find("ClassSkills") and not f:find("Cache") and not f:find("SkillTab"),
  "正式版 TOC 不列職業技能相關檔：" .. f) end
if okR then
  nsR.Window.open({})
  local tab = nsR.Window._ui and nsR.Window._ui().tabSkill
  H.check(tab == nil or not tab:IsShown(), "正式版完整視窗不顯示職業技能分頁按鈕")
end
H.eq(nsR and nsR.L and nsR.L.prof(773), "銘文學", "正式版專業名稱：銘文學")
H.eq(nsR and nsR.L and nsR.L.prof(755), "珠寶設計", "正式版專業名稱：珠寶設計")
