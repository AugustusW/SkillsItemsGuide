-- 錯誤紀錄：全域處理器鏈接、只收自己插件的錯誤、去重、淘汰、持久化、指令
local PREV_CALLS
local handler, stackText, clock, stackCalls
local timers

local function setup(opts)
  opts = opts or {}
  PREV_CALLS = {}
  stackText, clock, stackCalls, timers = "", 100, 0, {}
  handler = function(e) PREV_CALLS[#PREV_CALLS + 1] = e end
  H.reset({
    locale = opts.locale,
    missing = opts.missing,
    extra = {
      geterrorhandler = function() return handler end,
      seterrorhandler = function(f) handler = f end,
      debugstack = function() stackCalls = stackCalls + 1; return stackText end,
      GetTime = function() return clock end,
      StaticPopupDialogs = {},
      StaticPopup_Show = function(k) H.popup = k end,
      C_Timer = { After = function(_, f) timers[#timers + 1] = f end },
    },
  })
  H.popup = nil
end

local function load(db)
  local ns = {}
  SkillsItemsGuideDB = db
  assert(loadfile(H.dir .. "/Locale.lua"))("SkillsItemsGuide", ns)
  assert(loadfile(H.dir .. "/ErrorLog.lua"))("SkillsItemsGuide", ns)
  return ns
end

local OWN = "Interface/AddOns/SkillsItemsGuide/Window.lua:173: boom"
local SELF = "[Interface/AddOns/SkillsItemsGuide/ErrorLog.lua]:40: in function 'capture'\n"
local OTHER = "Interface/AddOns/OtherAddon/Main.lua:5: nope"

-- 鏈接：原 handler 一定被呼叫（遊戲原本的行為不變）
setup(); local ns = load()
handler(OWN)
H.eq(PREV_CALLS[1], OWN, "自己的錯誤也交給原 handler")
H.eq(#ns.ErrorLog.entries(), 1, "自己的錯誤有記錄")
handler(OTHER)
H.eq(PREV_CALLS[2], OTHER, "別的插件的錯誤交給原 handler")
H.eq(#ns.ErrorLog.entries(), 1, "別的插件的錯誤不記錄")

-- 堆疊判斷：訊息沒有路徑時靠堆疊；只有 ErrorLog 自己的 frame 不算自己的錯誤
setup(); ns = load()
stackText = SELF .. "[Interface/AddOns/OtherAddon/Main.lua]:5: in function '?'\n"
handler("Usage: local outObject = Mixin(object, ...)")
H.eq(#ns.ErrorLog.entries(), 0, "堆疊只有處理函式自身＋別人：不記錄（負控制）")
clock = clock + 2
stackText = SELF .. "[Interface/AddOns/SkillsItemsGuide/Window.lua]:9: in function '?'\n"
handler("Usage: local outObject = Mixin(object, ...)")
H.eq(#ns.ErrorLog.entries(), 1, "堆疊有自己的檔案：記錄")
H.check(not ns.ErrorLog.entries()[1].stack:find("ErrorLog.lua", 1, true), "存下的堆疊不含處理函式自身")

-- 節流：別的插件連續報錯時，每秒最多取一次堆疊
setup(); ns = load()
stackText = "[Interface/AddOns/OtherAddon/Main.lua]:5: in function '?'\n"
for i = 1, 50 do handler("Usage: foo " .. i) end
H.eq(stackCalls, 1, "同一秒內只取一次堆疊")
clock = clock + 1.5
handler("Usage: bar")
H.eq(stackCalls, 2, "過了一秒可再取")
-- 訊息已是別的插件的路徑：不取堆疊、不消耗節流額度（否則自己的無路徑錯誤會被擠掉）
stackCalls = 0; clock = clock + 2
for i = 1, 5 do handler(OTHER) end
H.eq(stackCalls, 0, "別的插件的路徑不取堆疊")
stackText = "[Interface/AddOns/SkillsItemsGuide/Core.lua]:9: in function '?'\n"
handler("Usage: mine")
H.eq(#ns.ErrorLog.entries(), 1, "別人連續報錯後，自己的無路徑錯誤仍收得到")

-- 自己呼叫遊戲函式、遊戲再呼叫別的插件時出錯：不算自己的（堆疊底下有自己也一樣）
setup(); ns = load()
stackText = SELF .. "[Interface/AddOns/OtherAddon/Hook.lua]:3: in function '?'\n[Interface/AddOns/Blizzard_X/T.lua]:8: in function 'Refresh'\n[Interface/AddOns/SkillsItemsGuide/Window.lua]:501: in function 'flush'\n"
handler("Usage: Thing(x)")
H.eq(#ns.ErrorLog.entries(), 0, "堆疊最上層是別的插件：不記錄")
handler(OTHER)
H.eq(#ns.ErrorLog.entries(), 0, "訊息路徑是別的插件：不記錄")
-- 內建插件的路徑不算別人：可能是自己傳錯參數
setup(); ns = load()
stackText = SELF .. "[Interface/AddOns/Blizzard_X/T.lua]:8: in function 'Refresh'\n[Interface/AddOns/SkillsItemsGuide/Window.lua]:9: in function '?'\n"
handler("Interface/AddOns/Blizzard_X/T.lua:8: bad")
H.eq(#ns.ErrorLog.entries(), 1, "遊戲內建檔案的錯誤靠堆疊判斷")
-- 同樣的無路徑訊息，別人觸發時不能累加到既有紀錄
clock = clock + 2
stackText = "[Interface/AddOns/OtherAddon/Hook.lua]:3: in function '?'\n"
handler("Interface/AddOns/Blizzard_X/T.lua:8: bad")
H.eq(ns.ErrorLog.entries()[1].count, 1, "別人觸發的同訊息不累加")

-- 去重：同訊息累加，移到最前面，不重取堆疊
setup(); ns = load()
handler(OWN); handler("Interface/AddOns/SkillsItemsGuide/Tooltip.lua:1: b")
local before = stackCalls
handler(OWN)
local e = ns.ErrorLog.entries()
H.eq(#e, 2, "同訊息不新增")
H.eq(e[1].msg, OWN, "最近發生的排最前")
H.eq(e[1].count, 2, "次數累加")
H.eq(stackCalls, before, "重複的錯誤不取堆疊")
setup(); ns = load()
stackText = "[Interface/AddOns/SkillsItemsGuide/Window.lua]:173: in function 'first'\n"
handler(OWN); handler(OWN)
H.check(ns.ErrorLog.entries()[1].stack:find("first", 1, true) ~= nil, "重複發生時保留第一次的堆疊")

-- 淘汰：上限 20 種，移除最舊
setup(); ns = load()
for i = 1, 25 do handler("Interface/AddOns/SkillsItemsGuide/A.lua:" .. i .. ": x") end
e = ns.ErrorLog.entries()
H.eq(#e, 20, "上限 20 種")
H.check(e[1].msg:find("A.lua:25", 1, true) ~= nil, "保留最新")
H.check(e[20].msg:find("A.lua:6", 1, true) ~= nil, "移除最舊")

-- 截斷：每筆 2 KB，且不切斷中文
setup(); ns = load()
stackText = string.rep("[Interface/AddOns/SkillsItemsGuide/W.lua]:1: 中\n", 400)
handler("Interface/AddOns/SkillsItemsGuide/A.lua:1: " .. string.rep("錯", 400))
e = ns.ErrorLog.entries()[1]
H.check(#e.msg + #e.stack <= 2048, "單筆不超過 2 KB（得到 " .. (#e.msg + #e.stack) .. "）")
H.check(e.msg:sub(-3) == "錯" or e.msg:sub(-3):byte(1) >= 0xE0, "訊息截斷在完整字元上")
H.check(e.stack:sub(-1):byte(1) < 0x80 or e.stack:sub(-3):byte(1) >= 0xE0, "堆疊截斷在完整字元上")

-- 自己出錯不外溢：記錄邏輯壞掉時原 handler 仍被呼叫
setup(); ns = load()
debugstack = function() error("stack broken") end
local ok = pcall(handler, "Usage: x")
H.check(ok, "記錄邏輯出錯不外溢")
H.eq(PREV_CALLS[1], "Usage: x", "記錄邏輯出錯時仍呼叫原 handler")

-- 沒有 API 的環境不報錯
setup({ missing = { seterrorhandler = true, geterrorhandler = true } })
ok = pcall(load)
H.check(ok, "沒有全域處理器 API 時仍可載入")

-- 持久化：載入前的錯誤併入存檔，寫進 SavedVariables
setup(); ns = load({ errors = { { msg = "old", stack = "", count = 2, last = "t", env = "e" } } })
handler(OWN)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
e = SkillsItemsGuideDB.errors
H.eq(#e, 2, "存檔與載入前的錯誤合併")
H.eq(e[1].msg, OWN, "載入前的錯誤排在舊紀錄前")
handler("Interface/AddOns/SkillsItemsGuide/B.lua:1: c")
H.eq(#SkillsItemsGuideDB.errors, 3, "接上存檔後直接寫入存檔")
setup(); ns = load({ errors = { { msg = OWN, stack = "old-stack", count = 2, last = "t", env = "e" } } })
handler(OWN)
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.eq(#SkillsItemsGuideDB.errors, 1, "載入前與存檔同訊息要合併")
H.eq(SkillsItemsGuideDB.errors[1].count, 3, "合併時次數相加")
-- 壞掉的存檔不影響載入
setup(); ns = load({ errors = { "bad", { msg = 5 } } })
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.eq(#SkillsItemsGuideDB.errors, 0, "壞掉的舊資料被丟棄")
setup(); ns = load({ errors = "bad" })
ok = pcall(H.fire, "ADDON_LOADED", "SkillsItemsGuide")
H.check(ok and type(SkillsItemsGuideDB.errors) == "table", "errors 不是表時重建")
H.fire("ADDON_LOADED", "OtherAddon")

-- 回報文字
setup(); ns = load()
handler(OWN)
local report = ns.ErrorLog.report()
H.check(report:find("SkillsItemsGuide 0.1.0 | Forever 1.60.1.70399 | zhTW", 1, true) ~= nil, "開頭帶版本與語系：" .. report:sub(1, 80))
H.check(report:find("Errors: 1", 1, true) ~= nil, "錯誤總數")
H.check(report:find("#1  x1", 1, true) ~= nil, "編號與次數")
H.check(report:find(OWN, 1, true) ~= nil, "錯誤訊息")
-- 舊版本留下的紀錄要標出當時的環境
e = ns.ErrorLog.entries()[1]; e.env = "0.0.9 | Forever 1.0.0.1 | enUS"
H.check(ns.ErrorLog.report():find("[0.0.9 | Forever 1.0.0.1 | enUS]", 1, true) ~= nil, "環境不同時標示")

-- try：回傳值與 pcall 相同，失敗時記錄且不呼叫原 handler
setup(); ns = load()
local a, b, c = ns.ErrorLog.try(function(x, y) return x, y end, 1, 2)
H.check(a == true and b == 1 and c == 2, "成功時回傳 true 與結果")
a, b = ns.ErrorLog.try(function(...) return select("#", ...) end, nil, 2, nil)
H.eq(b, 3, "參數含 nil 時完整傳遞")
stackText = "[Interface/AddOns/OtherAddon/X.lua]:1: in function '?'\n"
a, b = ns.ErrorLog.try(function() error("plain failure", 0) end)
H.check(a == false and b == "plain failure", "失敗時回傳 false 與錯誤")
H.eq(ns.ErrorLog.entries()[1].msg, "plain failure", "try 的失敗一定記錄（不看路徑）")
H.eq(#PREV_CALLS, 0, "try 接住的錯誤不跳錯誤視窗")
a = ns.ErrorLog.try(function() error("Interface/AddOns/OtherAddon/Hook.lua:1: theirs", 0) end)
H.check(a == false, "try 接住別人的錯誤仍回 false")
H.eq(#ns.ErrorLog.entries(), 1, "try 接住的別人的錯誤不記錄")

-- 指令：errors 子指令被攔截，其他照舊傳給原指令；原指令不存在時不補
setup(); ns = load()
local passed = {}
SlashCmdList.SIG = function(m) passed[#passed + 1] = m end
H.fire("ADDON_LOADED", "SkillsItemsGuide")
H.fire("PLAYER_LOGIN")
SlashCmdList.SIG("")
H.eq(passed[1], "", "/sig 不帶參數照舊")
SlashCmdList.SIG("errors")
H.eq(#passed, 1, "/sig errors 不傳給原指令")
local win = _G.SkillsItemsGuideErrorLogFrame
H.check(win and win:IsShown(), "/sig errors 開視窗")
H.check(SLASH_SIGERRORS1 == "/sigerrors", "備用指令已註冊")
SlashCmdList.SIGERRORS("")
H.check(win:IsShown(), "備用指令也開視窗")
H.eq(H.focus, nil, "視窗開啟時不搶鍵盤焦點")

-- 確認才清除
handler(OWN)
SlashCmdList.SIG("errors clear")
H.eq(#ns.ErrorLog.entries(), 1, "清除指令先不動紀錄")
H.check(H.popup ~= nil, "清除要跳確認框")
H.eq(StaticPopupDialogs[H.popup].OnCancel, nil, "取消按鈕沒有清除動作")
StaticPopupDialogs[H.popup].OnAccept()
H.eq(#ns.ErrorLog.entries(), 0, "確認後清除")
H.eq(#SkillsItemsGuideDB.errors, 0, "存檔同步清空")
handler(OWN)
H.eq(#SkillsItemsGuideDB.errors, 1, "清除後仍寫入同一張存檔表")

-- 文字框唯讀：玩家輸入時還原；程式自己 SetText 時不處理
do
  local editBox
  for _, f in ipairs(H.frames) do if f._kind == "EditBox" then editBox = f end end
  local report = editBox:GetText()
  editBox:SetText("typed by player")
  editBox._scripts.OnTextChanged(editBox, true)
  H.eq(editBox:GetText(), report, "玩家輸入時還原內容")
  editBox:SetText("set by code")
  editBox._scripts.OnTextChanged(editBox, false)
  H.eq(editBox:GetText(), "set by code", "程式設定內容時不還原")
  -- 視窗開著時新錯誤要更新文字框，連續發生只更新一次
  ns.ErrorLog.show()
  for _, f in ipairs(timers) do f() end -- 先跑完前面排的更新
  local count = #timers
  handler("Interface/AddOns/SkillsItemsGuide/New.lua:1: fresh")
  handler("Interface/AddOns/SkillsItemsGuide/New.lua:2: fresh2")
  H.eq(#timers, count + 1, "連續錯誤只排一次更新")
  timers[#timers]()
  H.check(editBox:GetText():find("fresh2", 1, true) ~= nil, "視窗開著時新錯誤出現在文字框")
  win:Hide()
  count = #timers
  handler("Interface/AddOns/SkillsItemsGuide/New.lua:3: hidden")
  H.eq(#timers, count, "視窗關著時不排更新")
end

-- 空狀態不跳確認框
ns.ErrorLog.clear(); H.popup = nil
SlashCmdList.SIG("errors clear")
H.eq(H.popup, nil, "沒有紀錄時不跳確認框")

-- Locale 載入失敗時視窗仍要能開
do
  setup()
  local n = {}
  assert(loadfile(H.dir .. "/ErrorLog.lua"))("SkillsItemsGuide", n)
  local okShow = pcall(n.ErrorLog.command, "errors")
  H.check(okShow and _G.SkillsItemsGuideErrorLogFrame:IsShown(), "沒有 ns.L 時視窗仍能開")
end

-- 兩個 TOC 都要最先載入 ErrorLog，後面檔案載入失敗才收得到
for _, toc in ipairs({ "SkillsItemsGuide_Forever.toc", "SkillsItemsGuide_Mainline.toc" }) do
  H.eq(H.tocFiles(toc)[1], "ErrorLog.lua", toc .. " 第一個載入 ErrorLog.lua")
end

-- 兩份語系都有視窗文字
setup(); ns = load()
for _, k in ipairs({ "ERRORS_TITLE", "ERRORS_HINT", "ERRORS_EMPTY", "ERRORS_SELECT_ALL", "ERRORS_CLEAR", "ERRORS_CLEAR_CONFIRM", "ERRORS_CLEAR_OK", "ERRORS_CANCEL" }) do
  H.check(type(ns.L[k]) == "string", "zhTW 有 " .. k)
end
setup({ locale = "enUS" }); ns = load()
H.eq(ns.L.ERRORS_CLEAR, "Clear log", "enUS 視窗文字是英文")
for _, k in ipairs({ "ERRORS_TITLE", "ERRORS_HINT", "ERRORS_EMPTY", "ERRORS_SELECT_ALL", "ERRORS_CLEAR", "ERRORS_CLEAR_CONFIRM", "ERRORS_CLEAR_OK", "ERRORS_CANCEL" }) do
  H.check(type(ns.L[k]) == "string", "enUS 有 " .. k)
end
