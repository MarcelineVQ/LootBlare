-- Create the button frame
local button = CreateFrame("Button", "LootBlareMinimapButton", Minimap)
button:EnableMouse(true)
button:SetMovable(true)
button:SetUserPlaced(true)
button:SetPoint("TOPLEFT", Minimap)

button:SetWidth(24)
button:SetHeight(24)
button:SetFrameStrata("MEDIUM")
button:RegisterForClicks("LeftButtonDown", "RightButtonDown");
button:SetNormalTexture([[Interface\Icons\inv_ore_gold_nugget]])
button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])

button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", function() if IsShiftKeyDown() then button:StartMoving() end end)
button:SetScript("OnDragStop", function() button:StopMovingOrSizing() end)
button:SetScript("OnEnter", function(self) 
end)


-- Handle click event
button:SetScript("OnClick", function()
  if IsShiftKeyDown() then
    return nil
  end
  if arg1 == "LeftButton" then
    SlashCmdList["LOOTBLARE"]("import")
  elseif arg1 == "RightButton" then
    SlashCmdList["LOOTBLARE"]("list")
  end
  
end)

-- Tooltip on hover
button:SetScript("OnEnter", function()
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText("LootBlareKB\nLeft Click to import\nRight Click to show imported sr list.", 1, 1, 1)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)
