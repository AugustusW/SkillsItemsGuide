local FILES = { "Locale.lua", "Probe.lua", "ProbeUI.lua", "Core.lua" }

-- 語系：標點跟著語系走
H.reset({ locale = "zhTW" })
local ns = H.load(FILES)
H.eq(ns.L.paren("裁縫", 23), "裁縫（23）", "zhTW 括號是全形")
H.eq(ns.L.join({ "a", "b" }), "a、b", "zhTW 分隔是頓號")
H.eq(ns.L.label("裁縫", "亞麻布卷"), "裁縫：亞麻布卷", "zhTW 冒號是全形")

H.reset({ locale = "enUS" })
ns = H.load(FILES)
H.eq(ns.L.paren("X", 23), "X (23)", "enUS 括號前有空白")
H.eq(ns.L.join({ "a", "b" }), "a, b", "enUS 分隔是逗號空白")
H.eq(ns.L.label("X", "Y"), "X: Y", "enUS 冒號後有空白")

H.reset({ locale = "deDE" })
ns = H.load(FILES)
H.eq(ns.L.paren("X", 1), "X (1)", "其他語系退回英文")

-- 探測：不存在的 API 回 ok=false，不報錯
H.reset({ extra = { IsSpellKnown = nil } })
ns = H.load(FILES)
local okRun, results = pcall(ns.Probe.run)
H.check(okRun, "Probe.run 在缺 API 時不報錯：" .. tostring(results))
local byName = {}
for _, r in ipairs(okRun and results or {}) do byName[r.name] = r end
H.check(byName.IsSpellKnown ~= nil and byName.IsSpellKnown.ok == false, "IsSpellKnown 缺少時記為 ok=false")
H.check(byName["C_Spell.GetSpellTexture"] ~= nil and byName["C_Spell.GetSpellTexture"].ok == false, "巢狀路徑缺少時記為 ok=false")
H.check(byName.CreateFrame ~= nil and byName.CreateFrame.ok == true, "存在的 API 記為 ok=true")

-- 探測 manifest：記錄 template 能不能建、widget 有哪些方法
table.insert(ns.Probe.TEMPLATES, "NoSuchTemplateForTest")
local m = ns.Probe.manifest()
table.remove(ns.Probe.TEMPLATES)
H.check(m.templates.BasicFrameTemplateWithInset == true, "存在的 template 記為 true")
H.check(m.templates.NoSuchTemplateForTest == false, "不存在的 template 記為 false（pcall 包住）")
H.check(type(m.methods.Frame) == "table", "記錄 Frame 的方法表")

-- 指令：被佔用就不註冊
H.reset({ slashTaken = { ["/sigprobe"] = true } })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.check(SlashCmdList.SIGPROBE == nil, "/sigprobe 被佔用時不註冊")
H.reset()
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.check(type(SlashCmdList.SIGPROBE) == "function" and SLASH_SIGPROBE1 == "/sigprobe", "/sigprobe 未被佔用時註冊")
H.check(type(SkillsItemsGuideDB) == "table" and SkillsItemsGuideDB.dbVersion == 1, "首次載入建立 SavedVariables 並標 dbVersion=1")

-- 既有 SavedVariables 不被清空（訓練師快取不可重建）
H.reset()
SkillsItemsGuideDB = { trainer = { class = { ["8"] = { spells = { ["116"] = { lv = 4 } } } } } }
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.check(SkillsItemsGuideDB.trainer.class["8"].spells["116"].lv == 4, "已有的訓練師快取保留")
H.eq(SkillsItemsGuideDB.dbVersion, 1, "缺 dbVersion 時補 1")

-- 探測視窗：開啟時把結果寫進 SavedVariables，文字含版本與每一項結果
H.reset()
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
local okShow, err = pcall(SlashCmdList.SIGPROBE, "")
H.check(okShow, "開探測視窗不報錯：" .. tostring(err))
local p = SkillsItemsGuideDB.probe
H.check(type(p) == "table" and type(p.results) == "table" and #p.results == #ns.Probe.APIS, "探測結果寫入 SavedVariables")
H.check(type(SkillsItemsGuideDB.manifest) == "table", "manifest 寫入 SavedVariables")
local text = ns.ProbeUI.text()
H.check(text:find("0.1.0", 1, true) and text:find("X-Build: test", 1, true), "抬頭含 Version 與 X-Build")
H.check(text:find("IsSpellKnown: missing", 1, true) ~= nil, "缺少的 API 列為 missing")

-- 點擊紀錄：記下修飾鍵、拆堆疊、商人、金錢變化
ns.ProbeUI.recordClick({ shift = true, alt = true, merchant = true, moneyBefore = 100, moneyAfter = 112, split = false, chat = "" })
local c = SkillsItemsGuideDB.probe.clicks
H.check(#c == 1 and c[1].sold == true, "金錢增加記為 sold=true")
H.check(ns.ProbeUI.text():find("sold=true", 1, true) ~= nil, "點擊紀錄出現在探測文字")

-- 探測視窗關閉後必須釋放鍵盤焦點（遊戲內實測：關掉後所有快捷鍵失效）
H.reset()
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
SlashCmdList.SIGPROBE("")
H.check(H.focus == nil, "開啟探測視窗時不自動搶焦點")
SkillsItemsGuideProbeFrame:Hide()
H.check(H.focus == nil, "關閉探測視窗後沒有元件持有鍵盤焦點")
H.focus = "something"
local edit
for _, f in ipairs(H.frames) do if f._kind == "EditBox" then edit = f end end
edit:SetFocus()
SkillsItemsGuideProbeFrame:Show()
SkillsItemsGuideProbeFrame:Hide()
H.check(H.focus == nil, "文字框有焦點時關閉視窗也會釋放")

-- 審查 Important #3：第二次 /sigprobe 不能留下搶焦點的文字框（Probe.manifest 會建 EditBox）
H.reset()
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
SlashCmdList.SIGPROBE("")
SlashCmdList.SIGPROBE("")
H.check(H.focus == nil, "連續兩次 /sigprobe 後沒有元件持有焦點")

-- 審查 #9：正式版平常不記錄點擊（每次 Alt+左鍵都寫存檔會無上限長大）；打 /sigprobe 後才開始記，且最多 20 筆
local hooks = {}
H.reset({ extra = { hooksecurefunc = function(a, b) hooks[#hooks + 1] = type(a) == "string" and a or b end,
  HandleModifiedItemClick = function() end } })
ns = H.load(FILES)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
local probeHooks = 0
for _, n in ipairs(hooks) do if n == "HandleModifiedItemClick" then probeHooks = probeHooks + 1 end end
H.eq(probeHooks, 0, "載入時不掛探測用的點擊紀錄")
SlashCmdList.SIGPROBE("")
SlashCmdList.SIGPROBE("")
probeHooks = 0
for _, n in ipairs(hooks) do if n == "HandleModifiedItemClick" then probeHooks = probeHooks + 1 end end
H.eq(probeHooks, 1, "打 /sigprobe 後才掛，而且只掛一次")
for i = 1, 30 do ns.ProbeUI.recordClick({ alt = true, moneyBefore = 1, moneyAfter = 1 }) end
H.eq(#SkillsItemsGuideDB.probe.clicks, 20, "點擊紀錄最多 20 筆")
