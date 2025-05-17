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
    SlashCmdList["LOOTBLARE"]("ms")
    PlaySoundFile("Sound\\interface\\iUiInterfaceButtonA.wav")
  elseif arg1 == "RightButton" then
    SlashCmdList["LOOTBLARE"]("import")
    PlaySoundFile("Sound\\interface\\iUiInterfaceButtonA.wav")
  end
  
end)

-- Tooltip on hover
button:SetScript("OnEnter", function()
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
GameTooltip:SetText("LootBlareKB\n", 1, 1, 1)  -- Title (White color)

  -- Add lines with specific colors for Left Click and Right Click
  GameTooltip:AddLine("\[Left Click\]", 0, 1, 0)  
  GameTooltip:AddLine(": Shows MS+ table.\n\n", 1, 1, 1) 
  GameTooltip:AddLine("\[Right Click\]:", 0, 1, 0)  
  GameTooltip:AddLine(": Shows SR Import.", 1, 1, 1) 

  GameTooltip:SetText("LootBlareKB\nLeft Click: Show MS+\n\nRight Click: Show SR Import.", 1, 1, 1)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)
