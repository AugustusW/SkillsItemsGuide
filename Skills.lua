-- 職業技能清單：依等級分組、標目前／下一級、判斷已學／可學／等級不到（只對自己的職業）
local _, ns = ...

local Skills = {}
ns.Skills = Skills

-- opts = { own=bool, level=n, isKnown=fn(spellId)->bool, show={learned=,available=,tooLow=}, match=fn(spellId)->bool }
function Skills.list(classId, opts)
  opts = opts or {}
  local rows = (ns.Data.classSkills or {})[classId] or {}
  local cache = ns.Data.cache and ns.Data.cache.class and ns.Data.cache.class[classId]
  -- 遊戲內存檔的訓練師快取（開過訓練師就有，不必等回收重打包）優先於打包的快取
  local db = SkillsItemsGuideDB
  local live = db and db.trainer and db.trainer.class and db.trainer.class[tostring(classId)]
  local function entry(spell)
    local v = live and live.spells and live.spells[tostring(spell)]
    if v then return v end
    return cache and cache[spell]
  end
  local own = opts.own and opts.isKnown ~= nil

  -- 被取代關係：higherOf[低 rank] = 高 rank
  local higherOf = {}
  for _, r in ipairs(rows) do if r.sup then higherOf[r.sup] = r.spell end end
  local function learned(spell)
    local s, guard = spell, 0
    while s and guard < 50 do
      if opts.isKnown(s) then return true end
      s, guard = higherOf[s], guard + 1
    end
    return false
  end

  -- 訓練師清單才有的技能（打包資料沒有或被過濾掉，例：招架）補進來
  if live and live.spells then
    local have = {}
    for _, r in ipairs(rows) do have[r.spell] = true end
    local extra = {}
    for k, v in pairs(live.spells) do
      local id = tonumber(k)
      if id and not have[id] and v.lv and v.lv > 0 then extra[#extra + 1] = { spell = id, lv = v.lv } end
    end
    if #extra > 0 then
      local merged = {}
      for _, r in ipairs(rows) do merged[#merged + 1] = r end
      for _, r in ipairs(extra) do merged[#merged + 1] = r end
      table.sort(merged, function(x, y) if x.lv ~= y.lv then return x.lv < y.lv end return x.spell < y.spell end)
      rows = merged
    end
  end

  local show = opts.show or {}
  local anyShow = show.learned or show.available or show.tooLow
  local level = opts.level or 0
  local verified = (live ~= nil) or (cache ~= nil)
  -- 目前／下一級依「全部技能」的等級決定，不跟著篩選結果跑
  local curLv, nextLv
  for _, r in ipairs(rows) do
    local c = entry(r.spell)
    local lv = (c and c.lv and c.lv > 0 and c.lv) or r.lv -- 已學的服務需求等級回 0，不是真的 0 級
    if lv <= level then if not curLv or lv > curLv then curLv = lv end
    elseif not nextLv or lv < nextLv then nextLv = lv end
  end
  local groups, byLv = {}, {}
  for _, r in ipairs(rows) do
    local c = entry(r.spell)
    local lv = (c and c.lv and c.lv > 0 and c.lv) or r.lv -- 已學的服務需求等級回 0，不是真的 0 級
    local status
    if own then
      if learned(r.spell) then status = "learned"
      elseif verified and not c then status = "other" -- 校正過的訓練師清單裡沒有：不是訓練師教的
      elseif lv <= level then status = "available"
      else status = "tooLow" end
    end
    local keep = (not own or not anyShow or show[status]) and (not opts.match or opts.match(r.spell))
    if keep then
      local g = byLv[lv]
      if not g then g = { lv = lv, rows = {} }; byLv[lv] = g; groups[#groups + 1] = g end
      g.rows[#g.rows + 1] = { spell = r.spell, lv = lv, cost = c and c.cost, status = status }
    end
  end
  table.sort(groups, function(a, b) return a.lv < b.lv end)

  local scrollTo
  if own then
    for _, g in ipairs(groups) do
      if g.lv == curLv then g.tag = "current" elseif g.lv == nextLv then g.tag = "next" end
    end
    if byLv[curLv or -1] then scrollTo = curLv elseif groups[1] then scrollTo = groups[1].lv end
  end

  local source
  if live then
    source = { kind = "verified", build = live.build, date = live.date }
  elseif cache then
    source = { kind = "verified", build = ns.Data.cache.build, date = ns.Data.cache.date }
  else
    source = { kind = "client", build = ns.Data.meta and ns.Data.meta.classBuild, hint = ns.L and ns.L.TRAINER_HINT }
  end
  return { groups = groups, source = source, scrollTo = scrollTo }
end
