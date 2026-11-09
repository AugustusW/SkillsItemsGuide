-- 遊戲版本判斷（唯一讀 WOW_PROJECT_ID 的地方）。實測 2026-11-08：永恆 18、正式版 1。
local _, ns = ...

local Flavor = {}
ns.Flavor = Flavor

function Flavor.isRetail() return WOW_PROJECT_ID == 1 end
function Flavor.isForever() return not Flavor.isRetail() end
