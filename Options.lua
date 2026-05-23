local _, addon = ...

local panel = CreateFrame("Frame", "HelloWorldBuffsOptionsPanel")
panel.name = "HelloWorldBuffs"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("HelloWorldBuffs")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetWidth(560)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("Track world buffs across all your characters.")

local minimapCheck = CreateFrame("CheckButton", "HelloWorldBuffsOptMinimap", panel, "InterfaceOptionsCheckButtonTemplate")
minimapCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -12)
_G["HelloWorldBuffsOptMinimapText"]:SetText("Show minimap button")
minimapCheck:SetScript("OnClick", function(self)
  if addon.SetMinimapHidden then
    addon:SetMinimapHidden(not self:GetChecked())
  end
end)

local dataHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
dataHeader:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 2, -20)
dataHeader:SetText("Data")

local dataCount = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
dataCount:SetPoint("TOPLEFT", dataHeader, "BOTTOMLEFT", 0, -8)

local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
resetBtn:SetSize(130, 22)
resetBtn:SetPoint("TOPLEFT", dataCount, "BOTTOMLEFT", 0, -12)
resetBtn:SetText("Reset everything")
resetBtn:SetScript("OnClick", function()
  StaticPopup_Show("HELLOWORLDBUFFS_RESET")
end)

StaticPopupDialogs["HELLOWORLDBUFFS_RESET"] = {
  text = "Wipe all tracked characters and world-buff history? This cannot be undone.",
  button1 = "Reset",
  button2 = "Cancel",
  OnAccept = function()
    if addon.ResetAll then addon:ResetAll() end
    print("|cffffd700HelloWorldBuffs:|r database reset.")
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function CountChars()
  if not HelloWorldBuffsDB or not HelloWorldBuffsDB.characters then return 0 end
  local n = 0
  for _ in pairs(HelloWorldBuffsDB.characters) do n = n + 1 end
  return n
end

local function Refresh()
  minimapCheck:SetChecked(addon.IsMinimapHidden and not addon:IsMinimapHidden() or true)
  dataCount:SetText(("Characters tracked: %d"):format(CountChars()))
end

panel:SetScript("OnShow", Refresh)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, "HelloWorldBuffs")
  category.ID = "HelloWorldBuffs"
  Settings.RegisterAddOnCategory(category)
  addon.OptionsCategoryID = category:GetID()
elseif InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
end
