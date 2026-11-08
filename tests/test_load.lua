-- 依 toc 順序載入全部檔案，模擬登入流程；只有 manifest 白名單的全域存在
local files = {}
for line in io.lines(H.dir .. "/SkillsItemsGuide.toc") do
  line = line:gsub("\r", "")
  if line ~= "" and not line:match("^#") then files[#files + 1] = line end
end
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
