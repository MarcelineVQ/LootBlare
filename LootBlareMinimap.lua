-- Create the button frame
local button = CreateFrame("Button", "LootBlareMinimapButton", Minimap)
button:SetWidth(32)
button:SetHeight(32)
button:SetFrameStrata("LOW")
button:SetPoint("TOPLEFT", Minimap, "TOPLEFT")  -- Adjust as needed

-- Add an icon texture
local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\inv_ore_gold_nugget")  -- Replace with desired icon
icon:SetAllPoints(button)

-- Handle click event
button:SetScript("OnClick", function()
  DEFAULT_CHAT_FRAME:AddMessage("LootBlare: Running /lb import...")
  SlashCmdList["LOOTBLARE"]("import")
end)

-- Tooltip on hover
button:SetScript("OnEnter", function()
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText("LootBlare\nClick to import", 1, 1, 1)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)
