local _, addon = ...

local function CharKey(realm, faction, name)
  return (realm or "") .. ":" .. (faction or "Neutral") .. ":" .. (name or "")
end

local function MyKey()
  return CharKey(GetRealmName(), UnitFactionGroup("player"), UnitName("player"))
end

local function EnsureDB()
  HelloWorldBuffsDB = HelloWorldBuffsDB or {}
  HelloWorldBuffsDB.characters = HelloWorldBuffsDB.characters or {}
  local key = MyKey()
  local c = HelloWorldBuffsDB.characters[key]
  if not c then
    c = { buffs = {} }
    HelloWorldBuffsDB.characters[key] = c
  end
  c.name    = UnitName("player")
  c.realm   = GetRealmName()
  c.faction = UnitFactionGroup("player") or "Neutral"
  local _, classToken = UnitClass("player")
  if classToken and classToken ~= "" then c.class = classToken end
  local lvl = UnitLevel("player")
  if lvl and lvl > 0 then c.level = lvl end
  return c
end

-- Snapshot every world buff currently on the player. We store the absolute
-- server timestamp (now + remaining) rather than the remaining duration, so
-- the time-left figure stays correct across reloads and across alts viewing
-- another character's row.
-- The chronoboon stores each world buff as a hidden aura that isn't returned
-- by UnitBuff. The game's own tooltip on the meta-aura is the only reliable
-- way to read what's inside, so we render it into a scanning tooltip and
-- parse the lines. Stored remaining time is frozen at storage and ticks
-- back to life only once the player releases the boon, so we capture it as
-- a static `seconds` value rather than a future expiresAt timestamp.
local scanTip

local function ParseDurationText(text)
  if not text or text == "" then return 0 end
  local h, m, s = text:match("(%d+):(%d+):(%d+)")
  if h then return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) end
  local total, found = 0, false
  for n, unit in text:gmatch("(%d+)%s*([hHmMsS])") do
    found = true
    n = tonumber(n)
    unit = unit:lower()
    if unit == "h" then total = total + n * 3600
    elseif unit == "m" then total = total + n * 60
    else total = total + n end
  end
  if found then return total end
  return 0
end

-- The chronoboon tooltip packs every stored buff into one FontString with
-- embedded newlines (the game renders each as its own visual row, icon +
-- name + "(XXm)"). Looking at the whole combined blob and locating each
-- known buff name separately is the only way to avoid (a) only catching
-- the first buff per line and (b) summing time tokens across rows.
local function NormApos(s)
  -- Tooltip text may use U+2019 (’) while our table uses ASCII (').
  if not s then return s end
  return (s:gsub("\xe2\x80\x99", "'"))
end

local function ParseChronoboonContents(auraIndex)
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "HelloWorldBuffsScanTip", UIParent, "GameTooltipTemplate")
  end
  scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  scanTip:ClearLines()
  scanTip:SetUnitBuff("player", auraIndex)

  local parts = {}
  for i = 1, scanTip:NumLines() do
    local fs = _G["HelloWorldBuffsScanTipTextLeft" .. i]
    local t = fs and fs:GetText()
    if t then parts[#parts + 1] = t end
  end
  local combined = NormApos(table.concat(parts, "\n"))

  local result = {}
  for _, col in ipairs(addon.WORLD_BUFFS) do
    for _, v in ipairs(col.variants) do
      local needle = NormApos(v.name)
      local _, nameEnd = combined:find(needle, 1, true)
      if nameEnd then
        -- Only consider text up to the next newline; otherwise the next
        -- stored buff's duration would be picked up too.
        local tail = combined:sub(nameEnd + 1):match("([^\n]*)")
        local secs = tail and ParseDurationText(tail) or 0
        if secs > 0 then result[v.id] = secs end
        break  -- one variant per column max (they're mutually exclusive)
      end
    end
  end
  return result
end

local function CaptureBuffs()
  local c = EnsureDB()
  local now = GetServerTime()
  local snapshot = {}

  for i = 1, 40 do
    local _, _, _, _, duration, expirationTime, _, _, _, spellID = UnitBuff("player", i)
    if not spellID then break end
    local wb = addon:GetWorldBuff(spellID)
    if wb then
      -- expirationTime from UnitBuff is in GetTime() seconds, not server
      -- epoch, so convert to a server timestamp before storing.
      local remaining = (expirationTime or 0) - GetTime()
      snapshot[spellID] = {
        expiresAt = remaining > 0 and (now + remaining) or 0,
        duration  = duration and duration > 0 and duration or wb.duration,
      }
    elseif spellID == addon.CHRONOBOON_SPELL_ID then
      -- The meta-aura is indefinite (no duration). `active` is what the UI
      -- keys off; expiresAt stays 0 in that case.
      local remaining = (expirationTime or 0) - GetTime()
      local contents = {}
      for buffID, secs in pairs(ParseChronoboonContents(i)) do
        contents[buffID] = { seconds = secs }
      end
      snapshot.chronoboon = {
        active    = true,
        expiresAt = remaining > 0 and (now + remaining) or 0,
        duration  = duration and duration > 0 and duration or 0,
        contents  = contents,
      }
    end
  end

  -- Count of Chronoboon Displacers in bags. GetItemCount only reads the
  -- local player's inventory, so other characters' rows show whatever was
  -- snapshotted on their last login.
  c.chronoboonCount = (GetItemCount and GetItemCount(addon.CHRONOBOON_ITEM_ID) or 0)

  c.buffs = snapshot
  c.lastUpdated = now
  if addon.UI and addon.UI.Refresh then addon.UI:Refresh() end
end

-- Public accessors for UI.lua. Returning the table directly is fine — the
-- UI is read-only and we control all writes from this file.
function addon:GetCharacters()
  EnsureDB()
  return HelloWorldBuffsDB.characters
end

function addon:GetMyKey() return MyKey() end

function addon:ResetAll()
  HelloWorldBuffsDB = { characters = {} }
  EnsureDB()
  if addon.UI and addon.UI.Refresh then addon.UI:Refresh() end
end

function addon:ForgetCharacter(key)
  if HelloWorldBuffsDB and HelloWorldBuffsDB.characters then
    HelloWorldBuffsDB.characters[key] = nil
    if addon.UI and addon.UI.Refresh then addon.UI:Refresh() end
  end
end

-- Compact "1h 12m" / "8m" / "42s" formatter used by the grid cells.
function addon:FormatRemaining(secs)
  if not secs or secs <= 0 then return nil end
  if secs >= 3600 then
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    if m > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dh"):format(h)
  elseif secs >= 60 then
    return ("%dm"):format(math.ceil(secs / 60))
  else
    return ("%ds"):format(secs)
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("BAG_UPDATE")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "UNIT_AURA" then
    if arg1 == "player" then CaptureBuffs() end
  else
    CaptureBuffs()
  end
end)

SLASH_HELLOWORLDBUFFS1 = "/hwb"
SLASH_HELLOWORLDBUFFS2 = "/helloworldbuffs"
SlashCmdList["HELLOWORLDBUFFS"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "reset" then
    addon:ResetAll()
    print("|cffffd700HelloWorldBuffs:|r database reset.")
  elseif msg == "refresh" then
    CaptureBuffs()
    print("|cffffd700HelloWorldBuffs:|r snapshot refreshed.")
  elseif msg == "scan" then
    -- Diagnostic: dump every aura on the player. When we hit the chronoboon
    -- meta-aura, also dump its tooltip lines so we can verify the parser
    -- against the actual in-game text.
    print("|cffffd700HelloWorldBuffs:|r aura scan on player:")
    for i = 1, 40 do
      local name, _, _, _, duration, expirationTime, _, _, _, spellID = UnitBuff("player", i)
      if not spellID then break end
      local rem = math.max(0, (expirationTime or 0) - GetTime())
      print(("  [%d] %d %q dur=%s rem=%s"):format(
        i, spellID, name or "?",
        duration and duration > 0 and ("%ds"):format(math.floor(duration)) or "—",
        rem > 0 and ("%ds"):format(math.floor(rem)) or "—"))
      if spellID == addon.CHRONOBOON_SPELL_ID then
        if not scanTip then
          scanTip = CreateFrame("GameTooltip", "HelloWorldBuffsScanTip", UIParent, "GameTooltipTemplate")
        end
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetUnitBuff("player", i)
        print("    chronoboon tooltip:")
        for j = 1, scanTip:NumLines() do
          local fs = _G["HelloWorldBuffsScanTipTextLeft" .. j]
          local txt = fs and fs:GetText()
          if txt and txt ~= "" then
            print(("      [%d] %s"):format(j, txt))
          end
        end
      end
    end
  else
    if addon.UI and addon.UI.Toggle then addon.UI:Toggle() end
  end
end
