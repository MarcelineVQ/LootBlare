-- The duration the frame will stay visible after the last roll
local frame_shown_duration = 20

--------------------------------------------------

local function lb_print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function tsize(t)
	c = 0
	for _ in pairs(t) do
    c = c + 1
	end
	if c > 0 then return c else return nil end
end

local timeElapsed = 0
local function ResetTimer()
  timeElapsed = 0
end

local function HideAfter(frame,duration,elapsed)
	timeElapsed = timeElapsed + elapsed
	if timeElapsed >= duration then
		frame:Hide()
		frame:SetScript("OnUpdate", nil)  -- Stop updating once the frame is hidden
		ResetTimer()
	end
end

local function ShowFrame(frame,duration)
	frame:SetScript("OnUpdate", function() HideAfter(frame,duration,arg1) end)
	frame:Show()
end

local function CreateItemRollFrame()
	local frame = CreateFrame("Frame", "ItemRollFrame", UIParent)
	frame:SetWidth(145) -- Adjust size as needed
	frame:SetHeight(180)
	frame:SetPoint("CENTER",UIParent,"CENTER",0,0) -- Position at center of the parent frame
	frame:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	frame:SetBackdropColor(0, 0, 0, 1) -- Black background with full opacity

	frame:SetMovable(true)
	frame:EnableMouse(true)

	frame:RegisterForDrag("LeftButton") -- Only start dragging with the left mouse button
	frame:SetScript("OnDragStart", function () frame:StartMoving() end)
	frame:SetScript("OnDragStop", function () frame:StopMovingOrSizing() end)
	frame:Hide()

	return frame
end

local itemRollFrame = CreateItemRollFrame()

local function InitItemInfo(frame)
	-- Create the texture for the item icon
	local icon = frame:CreateTexture()
	icon:SetWidth(40) -- Size of the icon
	icon:SetHeight(40) -- Size of the icon
	icon:SetPoint("TOP", frame, "TOP", 0, -10)

	-- Create a button for mouse interaction
	local iconButton = CreateFrame("Button", nil, frame)
	iconButton:SetWidth(40) -- Size of the icon
	iconButton:SetHeight(40) -- Size of the icon
	iconButton:SetPoint("TOP", frame, "TOP", 0, -10)

	-- Create a FontString for the item name
	local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("TOP", icon, "BOTTOM", 0, -10)

	frame.icon = icon
	frame.iconButton = iconButton
	frame.name = name
	frame.itemLink = ""

	-- Set up tooltip
	iconButton:SetScript("OnEnter", function()
			GameTooltip:SetOwner(iconButton, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(frame.itemLink)
			GameTooltip:Show()
	end)
	iconButton:SetScript("OnLeave", function()
			GameTooltip:Hide()
	end)
end

-- Function to return colored text based on item quality
local function GetColoredTextByQuality(text, qualityIndex)
	-- Get the color associated with the item quality
	local r, g, b, hex = GetItemQualityColor(qualityIndex)
	-- Return the text wrapped in WoW's color formatting
	return string.format("%s%s|r", hex, text)
end

local function SetItemInfo(frame, itemLink)

	if not frame.icon then InitItemInfo(frame) end
	local itemName, itemLink, itemQuality, _, _, _, _, _, itemIcon = GetItemInfo(itemLink)
	if not itemIcon then
		lb_print("no item?")
		return
	end -- If no item, skip setting up

	frame.icon:SetTexture(itemIcon)
	frame.iconButton:SetNormalTexture(itemIcon)  -- Sets the same texture as the icon

	frame.name:SetText(GetColoredTextByQuality(itemName,itemQuality))

	frame.itemLink = itemLink
end

-- SetItemInfo(itemRollFrame, "item:19019") -- Thunderfury, for example

local function CreateTextArea(frame)
	local textArea = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	textArea:SetHeight(150) -- Size of the icon
	textArea:SetPoint("TOP", frame, "TOP", 0, -80)
	textArea:SetJustifyH("LEFT")
	textArea:SetJustifyV("TOP")

	return textArea
end

local rollMessages = {}
local function UpdateTextArea(frame)
	if not frame.textArea then
		frame.textArea = CreateTextArea(frame)
	end

	table.sort(rollMessages, function(a, b)
		return a.roll > b.roll
	end)

	-- frame.textArea:SetTeClear()  -- Clear the existing messages
	local text = ""
	local count = 0
	for i, message in ipairs(rollMessages) do
			if count >= 7 then break end
			text = text .. message.msg .. "\n"
			count = count + 1
	end
	frame.textArea:SetText(text)
end

local function ExtractItemLinksFromMessage(message)
	local itemLinks = {}
	-- This pattern matches the standard item link structure in WoW
	for link in string.gfind(message, "|c.-|H(item:.-)|h.-|h|r") do
		-- lb_print(link)
		table.insert(itemLinks, link)
	end
	return itemLinks
end

-- no good masterLooterRaidID always nil?
local function IsUnitMasterLooter(unit)
	local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
	
	if lootMethod == "master" then
			if IsInRaid() then
					-- In a raid, use the raid ID to check
					return UnitIsUnit(unit, "raid" .. masterLooterRaidID)
			elseif IsInGroup() then
					-- In a party, use the party ID to check
					return UnitIsUnit(unit, "party" .. masterLooterPartyID)
			end
	end
	
	return false
end

local function HandleChatMessage(event, message, from)
	if event == "CHAT_MSG_SYSTEM" and itemRollFrame:IsShown() then
		if string.find(message, "rolls") and string.find(message, "(%d+)") then
			-- Add the new message to the rollMessages table
			-- table.insert(rollMessages, message)
			-- Optionally, update the display immediately
			-- UpdateScrollArea(itemRollFrame)
			local _,_,roller, roll, minRoll, maxRoll = string.find(message, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
			-- lb_print(roller .. " " .. roll .. " " .. minRoll .. " " .. maxRoll)
			if roller and roll then
					roll = tonumber(roll) -- Convert roll to a number
					table.insert(rollMessages, { roller = roller, roll = roll, msg = message })
					ResetTimer()
					UpdateTextArea(itemRollFrame)
			end
		end
	elseif event == "CHAT_MSG_RAID_WARNING" then
		local lootMethod, _ = GetLootMethod()
		if lootMethod == "master" then -- check if there is a loot master
      local links = ExtractItemLinksFromMessage(message)
			if tsize(links) == 1 then
				rollMessages = {}
				UpdateTextArea(itemRollFrame)
				SetItemInfo(itemRollFrame,links[1])
				ResetTimer()
				ShowFrame(itemRollFrame,frame_shown_duration)
			end
		end
  end
end

itemRollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
itemRollFrame:SetScript("OnEvent", function () HandleChatMessage(event,arg1,arg2) end)
