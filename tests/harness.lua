-- 用假的 WoW API 跑 SkillsItemsGuide 的純邏輯與載入流程（不驗畫面）
-- 用法：luajit tests/harness.lua <addon 資料夾> <測試檔...>
-- 與 BigFontTuner 的萬用 stub 不同：假物件只回應白名單裡的方法，其他一律是 nil，
-- 呼叫不存在的方法會像遊戲一樣報「attempt to call a nil value」（記憶 2023）。
-- 白名單來源：tests/api_manifest.lua（遊戲內 /sigprobe 傾印；探測前是暫定清單）。
H = { dir = arg[1] or ".", failed = 0, passed = 0 }
local out = io.write

function H.check(c, msg)
  if c then H.passed = H.passed + 1 else H.failed = H.failed + 1; out("FAIL ", msg, "\n") end
end
function H.eq(a, b, msg)
  H.check(a == b, msg .. "（期望 " .. tostring(b) .. "，得到 " .. tostring(a) .. "）")
end

local DEFAULT_MANIFEST = dofile(H.dir .. "/tests/api_manifest.lua")
local manifest = DEFAULT_MANIFEST
H.manifest = manifest

-- 依白名單建立假 widget：只有清單內的方法存在
local function widget(kind)
  local w = { _kind = kind, _scripts = {}, _events = {}, _shown = false, _text = "" }
  local impl = {
    SetScript = function(self, ev, fn) self._scripts[ev] = fn end,
    GetScript = function(self, ev) return self._scripts[ev] end,
    HookScript = function(self, ev, fn) local old = self._scripts[ev]
      self._scripts[ev] = function(...) if old then old(...) end fn(...) end end,
    RegisterEvent = function(self, ev) self._events[ev] = true end,
    UnregisterEvent = function(self, ev) self._events[ev] = nil end,
    Show = function(self) self._shown = true end,
    Hide = function(self)
      local was = self._shown
      self._shown = false
      if was and self._scripts.OnHide then self._scripts.OnHide(self) end
      for _, child in ipairs(self._children or {}) do
        if child._scripts.OnHide then child._scripts.OnHide(child) end
      end
    end,
    SetWordWrap = function(self, v) self._wrap = v end,
    SetWidth = function(self, v) self._width = v end,
    SetHeight = function(self, v) self._height = v end,
    SetFocus = function(self) H.focus = self end,
    ClearFocus = function(self) if H.focus == self then H.focus = nil end end,
    HasFocus = function(self) return H.focus == self end,
    IsShown = function(self) return self._shown end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    GetStringWidth = function(self) return #self._text * 6 end,
    -- 粗略模擬換行：每 60 位元組一行、每行 14 高；\n 另算一行
    GetStringHeight = function(self)
      local lines = 0
      for seg in (self._text .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#seg / 60)) end
      return lines * 14
    end,
    CreateFontString = function(self) return widget("FontString") end,
    CreateTexture = function(self) return widget("Texture") end,
  }
  local allowed = manifest.methods[kind] or manifest.methods.Frame
  return setmetatable(w, { __index = function(t, k)
    if not allowed[k] then return nil end
    return impl[k] or function(self) return self end
  end })
end
H.widget = widget

H.frames = {}
function H.reset(opts)
  opts = opts or {}
  -- 正式版用 tests/api_manifest_retail.lua；不指定時回到永恆白名單
  manifest = opts.manifest and dofile(H.dir .. "/tests/" .. opts.manifest) or DEFAULT_MANIFEST
  H.manifest = manifest
  H.frames = {}
  H.focus = nil
  SkillsItemsGuideDB, SkillsItemsGuideCharDB = nil, nil
  for k in pairs(_G) do if type(k) == "string" and k:sub(1, 6) == "SLASH_" then _G[k] = nil end end
  for k in pairs(H.installed or {}) do _G[k] = nil end
  H.installed = {}
  local api = {
    CreateFrame = function(kind, name, parent, template)
      if template and not manifest.templates[template] then error("Couldn't find inherited node \"" .. template .. "\"") end
      local f = widget(kind); f._name = name; table.insert(H.frames, f)
      -- 遊戲預設：EditBox 建立時 autoFocus 為 true，建立當下（可見時）就取得鍵盤焦點
      if kind == "EditBox" then H.focus = f end
      -- 子物件掛到最上層父物件，讓 Hide 能通知（模擬遊戲：父框架隱藏時子物件也觸發 OnHide）
      local top = parent
      while top and top._parent do top = top._parent end
      if parent then f._parent = parent; top._children = top._children or {}; table.insert(top._children, f) end
      if name then _G[name] = f end
      return f
    end,
    GetLocale = function() return opts.locale or "zhTW" end,
    GetBuildInfo = function() return "1.60.1", "70399", "Nov 1 2026", 16001 end,
    UIParent = widget("Frame"),
    UISpecialFrames = {},
    SlashCmdList = {},
    hash_SlashCmdList = {},
    C_AddOns = { GetAddOnMetadata = function(_, key) return ({ Version = "0.1.0", ["X-Build"] = "test" })[key] end },
    print = function() end,
    date = os.date,
    tinsert = table.insert,
    time = os.time,
  }
  if opts.projectId then api.WOW_PROJECT_ID = opts.projectId end
  for k, v in pairs(opts.extra or {}) do api[k] = v end
  for k, v in pairs(api) do
    if (manifest.globals[k] or k == "print" or k == "date" or k == "time") and not (opts.missing or {})[k] then
      _G[k] = v; H.installed[k] = true
    end
  end
  for k in pairs(opts.slashTaken or {}) do _G.hash_SlashCmdList[k] = true end
end

-- 讀 toc 的檔案清單（多版本 TOC：SkillsItemsGuide_Forever.toc／_Mainline.toc）
function H.tocFiles(name)
  local files = {}
  for line in io.lines(H.dir .. "/" .. name) do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then files[#files + 1] = line end
  end
  return files
end

-- 依 toc 順序載入 addon 檔案，回傳共用 ns
function H.load(files)
  local ns = {}
  for _, f in ipairs(files) do assert(loadfile(H.dir .. "/" .. f))("SkillsItemsGuide", ns) end
  return ns
end

function H.fire(ev, ...)
  for _, f in ipairs(H.frames) do
    local fn = f._scripts.OnEvent
    if fn and f._events[ev] then fn(f, ev, ...) end
  end
end

for i = 2, #arg do dofile(arg[i]) end
out(string.format("%d passed, %d failed\n", H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
