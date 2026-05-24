local _, addon = ...

local UI = {}
addon.UI = UI

local ROW_HEIGHT        = 30
local HEADER_HEIGHT     = 46
local FILTER_BAR_HEIGHT = 22
local NAME_WIDTH        = 220
local CELL_WIDTH        = 80
local PADDING           = 8
local CLASS_ICON_SIZE   = 18
local BUFF_ICON_SIZE    = 26

-- Icon of the Chronoboon Displacer item (184937), used for the column header.
local CHRONO_ICON_PATH = "Interface\\Icons\\INV_Misc_EngGizmos_21"

local function ClassColor(classToken)
  local c = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  if not c then return 1, 1, 1 end
  return c.r, c.g, c.b
end

local function SetClassIcon(texture, classToken)
  local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
  if not coords then
    texture:Hide()
    return
  end
  texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
  texture:SetTexCoord(unpack(coords))
  texture:Show()
end

-- One column per tracked world buff, plus a final "Boon" column for the
-- chronoboon meta-aura's own countdown. The actual column ordering is
-- decided at first-show in EnsureLayout() based on player faction.
local TOTAL_COLS       = #addon.WORLD_BUFFS + 1
local BOON_COL_INDEX   = #addon.WORLD_BUFFS  -- zero-based offset for placement
local orderedBuffs                            -- populated by EnsureLayout()
-- Extra slack on the right so the rightmost column isn't hidden by the
-- scrollbar. The scroll viewport is anchored at -28 from frame's right.
local SCROLLBAR_GUTTER = 28
local GRID_WIDTH       = NAME_WIDTH + CELL_WIDTH * TOTAL_COLS

local frame = CreateFrame("Frame", "HelloWorldBuffsFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(GRID_WIDTH + PADDING * 2 + SCROLLBAR_GUTTER, 400 + FILTER_BAR_HEIGHT + 4)
frame:SetPoint("CENTER")
-- Sit on MEDIUM well above the minimap so we clear action-bar flyouts from
-- skins like DragonflightUI (which stack a handful of levels above their
-- parent bar), but a notch below the +100 slot used by sibling addons so
-- those windows render on top when they overlap. Re-applied on each show
-- because the minimap's level isn't final at file-parse time — some skins
-- bump it after addon load.
frame:SetFrameStrata("MEDIUM")
local function ApplyFrameLevel()
  local mmLevel = (Minimap and Minimap:GetFrameLevel()) or 1
  frame:SetFrameLevel(mmLevel + 90)
end
ApplyFrameLevel()
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
frame.title:SetText("HelloWorldBuffs")

-- Header bar -----------------------------------------------------------------
local header = CreateFrame("Frame", nil, frame)
header:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -28)
header:SetSize(GRID_WIDTH, HEADER_HEIGHT)

header.bg = header:CreateTexture(nil, "BACKGROUND")
header.bg:SetAllPoints()
header.bg:SetColorTexture(0, 0, 0, 0.35)

local headerLine = header:CreateTexture(nil, "OVERLAY")
headerLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -1)
headerLine:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -1)
headerLine:SetHeight(1)
headerLine:SetColorTexture(0.6, 0.6, 0.6, 0.4)

local headerName = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerName:SetPoint("LEFT", header, "LEFT", 6, 0)
headerName:SetWidth(NAME_WIDTH - 8)
headerName:SetJustifyH("LEFT")
headerName:SetText("Character")

local function AddHeaderCell(index, iconPath, label, labelColor)
  local cellLeft = NAME_WIDTH + (index - 1) * CELL_WIDTH
  local icon = header:CreateTexture(nil, "ARTWORK")
  icon:SetSize(BUFF_ICON_SIZE, BUFF_ICON_SIZE)
  icon:SetPoint("TOP", header, "TOPLEFT", cellLeft + CELL_WIDTH / 2, -4)
  icon:SetTexture(iconPath)
  -- Crop the default Blizzard icon border so the swatch reads cleanly.
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("TOP", icon, "BOTTOM", 0, -2)
  fs:SetWidth(CELL_WIDTH)
  fs:SetJustifyH("CENTER")
  fs:SetText(label)
  if labelColor then fs:SetTextColor(unpack(labelColor)) end
end

-- Header cells are built on first show, once UnitFactionGroup is reliable.
local layoutBuilt = false
local function EnsureLayout()
  if layoutBuilt then return end
  orderedBuffs = addon:GetOrderedBuffs(UnitFactionGroup("player"))
  for i, b in ipairs(orderedBuffs) do
    AddHeaderCell(i, b.icon, b.shortName)
  end
  AddHeaderCell(BOON_COL_INDEX + 1, CHRONO_ICON_PATH, "Boon", { 1, 0.84, 0 })
  layoutBuilt = true
end

-- Filter footer --------------------------------------------------------------
-- Compact in-window toggles along the bottom edge. Settings persist via
-- addon:SetSetting; the grid re-renders on each click.
local FILTER_BAR_BOTTOM = PADDING + 4
local filterBar = CreateFrame("Frame", nil, frame)
filterBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PADDING + 6, FILTER_BAR_BOTTOM)
filterBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PADDING + 6), FILTER_BAR_BOTTOM)
filterBar:SetHeight(FILTER_BAR_HEIGHT)

local filterTopLine = filterBar:CreateTexture(nil, "OVERLAY")
filterTopLine:SetPoint("TOPLEFT", filterBar, "TOPLEFT", 0, 1)
filterTopLine:SetPoint("TOPRIGHT", filterBar, "TOPRIGHT", 0, 1)
filterTopLine:SetHeight(1)
filterTopLine:SetColorTexture(0.6, 0.6, 0.6, 0.25)

local filterChecks = {}
local function MakeFilterCheck(key, label, anchorFrame, anchorPoint, ax, ay)
  local cb = CreateFrame("CheckButton", "HelloWorldBuffsFilter_" .. key, filterBar, "UICheckButtonTemplate")
  cb:SetSize(20, 20)
  cb:SetPoint("LEFT", anchorFrame, anchorPoint, ax, ay)
  local text = _G[cb:GetName() .. "Text"]
  text:SetFontObject("GameFontHighlightSmall")
  text:SetText(label)
  cb:SetScript("OnClick", function(self)
    addon:SetSetting(key, self:GetChecked())
  end)
  filterChecks[key] = cb
  return cb
end

local maxLevel = (addon.MaxLevel and addon:MaxLevel()) or 60
local lvlCheck     = MakeFilterCheck("hideBelowMax",     ("Lvl %d only"):format(maxLevel), filterBar, "LEFT", 0, 0)
local lvlText      = _G[lvlCheck:GetName() .. "Text"]
local factionCheck = MakeFilterCheck("hideOtherFaction", "My faction only",                lvlText,   "RIGHT", 12, 0)

-- Scroll body ----------------------------------------------------------------
local scroll = CreateFrame("ScrollFrame", "HelloWorldBuffsScroll", frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR_GUTTER, FILTER_BAR_BOTTOM + FILTER_BAR_HEIGHT + 2)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(GRID_WIDTH, 1)
scroll:SetScrollChild(content)

local rowPool = {}

local function AcquireRow(index)
  local row = rowPool[index]
  if row then return row end
  row = CreateFrame("Frame", nil, content)
  row:SetSize(GRID_WIDTH, ROW_HEIGHT)
  row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  -- Highlight (covers bg; coloured per-row in Refresh for the player's own).
  row.highlight = row:CreateTexture(nil, "BORDER")
  row.highlight:SetAllPoints()
  row.highlight:Hide()

  row.classIcon = row:CreateTexture(nil, "ARTWORK")
  row.classIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
  row.classIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", row.classIcon, "RIGHT", 6, 0)
  row.name:SetWidth(NAME_WIDTH - CLASS_ICON_SIZE - 18)
  row.name:SetJustifyH("LEFT")

  row.cells = {}
  for i = 1, #orderedBuffs do
    local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell:SetPoint("LEFT", row, "LEFT", NAME_WIDTH + (i - 1) * CELL_WIDTH, 0)
    cell:SetWidth(CELL_WIDTH)
    cell:SetJustifyH("CENTER")
    row.cells[i] = cell
  end

  -- Boon column shows two stacked lines: the meta-aura status on top and the
  -- bag count of Chronoboon Displacers below.
  row.boonCell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.boonCell:SetPoint("TOP", row, "TOPLEFT", NAME_WIDTH + BOON_COL_INDEX * CELL_WIDTH + CELL_WIDTH / 2, -3)
  row.boonCell:SetWidth(CELL_WIDTH)
  row.boonCell:SetJustifyH("CENTER")

  row.boonCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.boonCount:SetPoint("TOP", row.boonCell, "BOTTOM", 0, -1)
  row.boonCount:SetWidth(CELL_WIDTH)
  row.boonCount:SetJustifyH("CENTER")

  rowPool[index] = row
  return row
end

local function HideRowsFrom(index)
  for i = index, #rowPool do rowPool[i]:Hide() end
end

-- The current character is always kept in the list regardless of filter
-- settings — hiding the logged-in row from its own UI is confusing.
local function VisibleCharacters()
  local s = addon:GetSettings()
  local myKey = addon:GetMyKey()
  local myFaction = UnitFactionGroup("player") or "Neutral"
  local maxLevel = addon:MaxLevel()
  local list = {}
  for key, c in pairs(addon:GetCharacters()) do
    local keep = true
    if key ~= myKey then
      if not addon:IsInRealmCluster(c.realm) then keep = false end
      if keep and s.hideBelowMax and (c.level or 0) < maxLevel then keep = false end
      if keep and s.hideOtherFaction and c.faction and c.faction ~= myFaction then keep = false end
    end
    if keep then list[#list + 1] = { key = key, char = c } end
  end
  table.sort(list, function(a, b)
    local ak = (a.char.realm or "") .. (a.char.name or "")
    local bk = (b.char.realm or "") .. (b.char.name or "")
    return ak < bk
  end)
  return list
end

function UI:Refresh()
  if not frame:IsShown() then return end
  local now = GetServerTime()
  local chars = VisibleCharacters()
  local myKey = addon:GetMyKey()
  for i, entry in ipairs(chars) do
    local row = AcquireRow(i)
    local c = entry.char

    -- Striping + player-row highlight. The highlight texture sits above bg
    -- and shows a subtle blue wash on the current character.
    if i % 2 == 0 then
      row.bg:SetColorTexture(1, 1, 1, 0.06)
    else
      row.bg:SetColorTexture(0, 0, 0, 0)
    end
    if entry.key == myKey then
      row.highlight:SetColorTexture(0.3, 0.5, 1.0, 0.10)
      row.highlight:Show()
    else
      row.highlight:Hide()
    end

    SetClassIcon(row.classIcon, c.class)
    local r, g, b = ClassColor(c.class)
    row.name:SetTextColor(r, g, b)
    -- Name in class colour, realm suffix dimmed so eyes lock onto the name.
    row.name:SetText(("%s|cff888888-%s|r"):format(c.name or "?", c.realm or "?"))

    local boon = c.buffs and c.buffs.chronoboon
    local stored = boon and boon.contents or nil

    for j, col in ipairs(orderedBuffs) do
      local cell = row.cells[j]
      local snap = addon:VariantSnap(c.buffs, col)
      local remaining = snap and ((snap.expiresAt or 0) - now) or 0
      if remaining > 0 then
        cell:SetTextColor(1, 0.95, 0.3)
        cell:SetText(addon:FormatRemaining(remaining) or "")
      else
        -- Stored buff durations are frozen at the moment of storage and do
        -- not tick down, so we display the raw `seconds` field as-is.
        local storedSnap = addon:VariantSnap(stored, col)
        local storedSecs = storedSnap and storedSnap.seconds or 0
        if storedSecs > 0 then
          cell:SetTextColor(0.2, 0.7, 0.3)
          cell:SetText(addon:FormatRemaining(storedSecs) or "?")
        else
          cell:SetTextColor(0.35, 0.35, 0.35)
          cell:SetText("·")
        end
      end
    end

    -- When the meta-aura is up, the stored-buff cells render green — that's
    -- the visible signal. Show a countdown only if the aura has a finite one.
    if boon and boon.active then
      row.boonCell:SetTextColor(1, 0.84, 0)
      local boonRem = (boon.expiresAt or 0) - now
      row.boonCell:SetText(boonRem > 0 and (addon:FormatRemaining(boonRem) or "") or "")
    else
      row.boonCell:SetTextColor(0.35, 0.35, 0.35)
      row.boonCell:SetText("·")
    end

    local invCount = c.chronoboonCount or 0
    if invCount > 0 then
      row.boonCount:SetText(tostring(invCount))
      if invCount < 3 then
        row.boonCount:SetTextColor(1, 0.3, 0.3)
      elseif invCount < 7 then
        row.boonCount:SetTextColor(1, 0.95, 0.3)
      else
        row.boonCount:SetTextColor(0.2, 0.8, 0.4)
      end
    else
      row.boonCount:SetText("")
    end

    row:Show()
  end
  HideRowsFrom(#chars + 1)
  content:SetHeight(math.max(1, #chars * ROW_HEIGHT))
end

local function SyncFilterChecks()
  local s = addon:GetSettings()
  for key, cb in pairs(filterChecks) do
    cb:SetChecked(s[key] and true or false)
  end
end

function UI:Toggle()
  if frame:IsShown() then frame:Hide() else
    EnsureLayout()
    SyncFilterChecks()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    ApplyFrameLevel()
    frame:Show()
    self:Refresh()
  end
end

-- Tick the visible grid every second so countdowns advance without waiting
-- for the next UNIT_AURA. Cheap (single OnUpdate, only when shown).
local accum = 0
frame:SetScript("OnUpdate", function(_, elapsed)
  accum = accum + elapsed
  if accum >= 1 then
    accum = 0
    UI:Refresh()
  end
end)
