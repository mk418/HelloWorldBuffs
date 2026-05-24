local _, addon = ...

local function MinimapStore()
  HelloWorldBuffsDB = HelloWorldBuffsDB or {}
  HelloWorldBuffsDB.minimap = HelloWorldBuffsDB.minimap or {}
  return HelloWorldBuffsDB.minimap
end

local DEFAULT_ANGLE = 210  -- lower-left of the minimap, clear of clock/zoom

local button = CreateFrame("Button", "HelloWorldBuffsMinimapButton", Minimap)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:SetSize(31, 31)
button:RegisterForClicks("AnyUp")
button:RegisterForDrag("LeftButton")
button:SetMovable(true)
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = button:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local bg = button:CreateTexture(nil, "BACKGROUND")
bg:SetSize(20, 20)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(17, 17)
icon:SetTexture("Interface\\Icons\\inv_misc_enggizmos_24")  -- Supercharged Chronoboon Displacer
icon:SetPoint("TOPLEFT", 7, -6)

local function UpdatePosition()
  local angle = math.rad(MinimapStore().angle or DEFAULT_ANGLE)
  local r = Minimap:GetWidth() / 2 + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function ApplyVisibility()
  button:SetShown(not MinimapStore().hide)
end

local function DraggingUpdate(self)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  MinimapStore().angle = math.deg(math.atan2(py - my, px - mx))
  UpdatePosition()
end

button:SetScript("OnDragStart", function(self)
  self:LockHighlight()
  self:SetScript("OnUpdate", DraggingUpdate)
end)
button:SetScript("OnDragStop", function(self)
  self:UnlockHighlight()
  self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(_, btn)
  if btn == "RightButton" then
    if Settings and Settings.OpenToCategory and addon.OptionsCategoryID then
      Settings.OpenToCategory(addon.OptionsCategoryID)
    end
  else
    if addon.UI then addon.UI:Toggle() end
  end
end)

button:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("HelloWorldBuffs", 1, 0.82, 0)
  GameTooltip:AddLine("Left-click: open/close the world buffs window", 1, 1, 1)
  GameTooltip:AddLine("Right-click: open options",                     1, 1, 1)
  GameTooltip:AddLine("Drag: move around the minimap edge", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function addon:SetMinimapHidden(hidden)
  MinimapStore().hide = hidden and true or false
  ApplyVisibility()
end

function addon:IsMinimapHidden()
  return MinimapStore().hide and true or false
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  UpdatePosition()
  ApplyVisibility()
end)
