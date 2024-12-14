local weird_vibes_mode = true
local srRollMessages = {}
local msRollMessages = {}
local osRollMessages = {}
local tmogRollMessages = {}
local rollers = {}
local isRolling = false
local time_elapsed = 0
local item_query = 0.5
local times = 5
local discover = CreateFrame("GameTooltip", "CustomTooltip1", UIParent, "GameTooltipTemplate")

local BUTTON_WIDTH = 32
local BUTTON_COUNT = 4
local BUTTON_PADING = 10
local FONT_NAME = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE = 12
local FONT_OUTLINE = "OUTLINE"
local RAID_CLASS_COLORS = {
  ["Warrior"] = "FFC79C6E",
  ["Mage"]    = "FF69CCF0",
  ["Rogue"]   = "FFFFF569",
  ["Druid"]   = "FFFF7D0A",
  ["Hunter"]  = "FFABD473",
  ["Shaman"]  = "FF0070DE",
  ["Priest"]  = "FFFFFFFF",
  ["Warlock"] = "FF9482C9",
  ["Paladin"] = "FFF58CBA",
}

local ADDON_TEXT_COLOR= "FFEDD8BB"
local DEFAULT_TEXT_COLOR = "FFFFFF00"
local SR_TEXT_COLOR = "FFFF0000"
local MS_TEXT_COLOR = "FFFFFF00"
local OS_TEXT_COLOR = "FF00FF00"
local TM_TEXT_COLOR = "FF00FFFF"

local function lb_print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|c" .. ADDON_TEXT_COLOR .. "LootBlare: " .. msg .. "|r")
end

local function resetRolls()
  srRollMessages = {}
  msRollMessages = {}
  osRollMessages = {}
  tmogRollMessages = {}
  rollers = {}
end

local function sortRolls()
  table.sort(srRollMessages, function(a, b)
    return a.roll > b.roll
  end)
  table.sort(msRollMessages, function(a, b)
    return a.roll > b.roll
  end)
  table.sort(osRollMessages, function(a, b)
    return a.roll > b.roll
  end)
  table.sort(tmogRollMessages, function(a, b)
    return a.roll > b.roll
  end)
end

local function colorMsg(message)
  msg = message.msg
  class = message.class
  _,_,_, message_end = string.find(msg, "(%S+)%s+(.+)")
  classColor = RAID_CLASS_COLORS[class]
  textColor = DEFAULT_TEXT_COLOR

  if string.find(msg, "-101") then
    textColor = SR_TEXT_COLOR
  elseif string.find(msg, "-100") then
    textColor = MS_TEXT_COLOR
  elseif string.find(msg, "-99") then
    textColor = OS_TEXT_COLOR
  elseif string.find(msg, "-50") then
    textColor = TM_TEXT_COLOR
  end

  colored_msg = "|c" .. classColor .. "" .. message.roller .. "|r |c" .. textColor .. message_end .. "|r"
  return colored_msg
end

local function tsize(t)
  c = 0
  for _ in pairs(t) do
    c = c + 1
  end
  if c > 0 then return c else return nil end
end

local function CheckItem(link)
  discover:SetOwner(UIParent, "ANCHOR_PRESERVE")
  discover:SetHyperlink(link)

  if discoverTextLeft1 and discoverTooltipTextLeft1:IsVisible() then
    local name = discoverTooltipTextLeft1:GetText()
    discoverTooltip:Hide()

    if name == (RETRIEVING_ITEM_INFO or "") then
      return false
    else
      return true
    end
  end
  return false
end

local function CreateCloseButton(frame)
  -- Add a close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetWidth(32) -- Button size
  closeButton:SetHeight(32) -- Button size
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5) -- Position at the top right

  -- Set textures if you want to customize the appearance
  closeButton:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
  closeButton:SetPushedTexture("Interface/Buttons/UI-Panel-MinimizeButton-Down")
  closeButton:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")

  -- Hide the frame when the button is clicked
  closeButton:SetScript("OnClick", function()
      frame:Hide()
      resetRolls()
  end)
end

local function CreateActionButton(frame, buttonText, tooltipText, index, onClickAction)
  local panelWidth = frame:GetWidth()
  local spacing = (panelWidth - (BUTTON_COUNT * BUTTON_WIDTH)) / (BUTTON_COUNT + 1)
  local button = CreateFrame("Button", nil, frame, UIParent)
  button:SetWidth(BUTTON_WIDTH)
  button:SetHeight(BUTTON_WIDTH)
  button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", index*spacing + (index-1)*BUTTON_WIDTH, BUTTON_PADING)

  -- Set button text
  button:SetText(buttonText)
  local font = button:GetFontString()
  font:SetFont(FONT_NAME, FONT_SIZE, FONT_OUTLINE)

  -- Add background 
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)
  bg:SetTexture(1, 1, 1, 1) -- White texture
  bg:SetVertexColor(0.2, 0.2, 0.2, 1) -- Dark gray background

  button:SetScript("OnMouseDown", function(self)
      bg:SetVertexColor(0.6, 0.6, 0.6, 1) -- Even lighter gray when pressed
  end)

  button:SetScript("OnMouseUp", function(self)
      bg:SetVertexColor(0.4, 0.4, 0.4, 1) -- Lighter gray on release
  end)

  -- Add tooltip
  button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, nil, nil, nil, nil, true)
      bg:SetVertexColor(0.4, 0.4, 0.4, 1) -- Lighter gray on hover
      GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function(self)
      bg:SetVertexColor(0.2, 0.2, 0.2, 1) -- Dark gray when not hovered
      GameTooltip:Hide()
  end)

  -- Add functionality to the button
  button:SetScript("OnClick", function()
    onClickAction()
  end)
end

local function CreateItemRollFrame()
  local frame = CreateFrame("Frame", "ItemRollFrame", UIParent)
  frame:SetWidth(200) -- Adjust size as needed
  frame:SetHeight(220)
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
  CreateCloseButton(frame)
  CreateActionButton(frame, "SR", "Roll for Soft Reserve", 1, function() RandomRoll(1,101) end)
  CreateActionButton(frame, "MS", "Roll for Main Spec", 2, function() RandomRoll(1,100) end)
  CreateActionButton(frame, "OS", "Roll for Off Spec", 3, function() RandomRoll(1,99) end)
  CreateActionButton(frame, "TM", "Roll for Transmog", 4, function() RandomRoll(1,50) end)
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

  -- Create a FontString for the frame hide timer
  local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  timerText:SetPoint("CENTER", frame, "TOPLEFT", 30, -32)
  timerText:SetFont(timerText:GetFont(), 20)

  -- Create a FontString for the item name
  local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  name:SetPoint("TOP", icon, "BOTTOM", 0, -10)

  frame.icon = icon
  frame.iconButton = iconButton
  frame.timerText = timerText
  frame.name = name
  frame.itemLink = ""

  local tt = CreateFrame("GameTooltip", "CustomTooltip2", UIParent, "GameTooltipTemplate")

  -- Set up tooltip
  iconButton:SetScript("OnEnter", function()
    tt:SetOwner(iconButton, "ANCHOR_RIGHT")
    tt:SetHyperlink(frame.itemLink)
    tt:Show()
  end)
  iconButton:SetScript("OnLeave", function()
    tt:Hide()
  end)
  iconButton:SetScript("OnClick", function()
    if ( IsControlKeyDown() ) then
      DressUpItemLink(frame.itemLink);
    elseif ( IsShiftKeyDown() and ChatFrameEditBox:IsVisible() ) then
      local itemName, itemLink, itemQuality, _, _, _, _, _, itemIcon = GetItemInfo(frame.itemLink)
      ChatFrameEditBox:Insert(ITEM_QUALITY_COLORS[itemQuality].hex.."\124H"..itemLink.."\124h["..itemName.."]\124h"..FONT_COLOR_CODE_CLOSE);
    end
  end)
end

-- Function to return colored text based on item quality
local function GetColoredTextByQuality(text, qualityIndex)
  -- Get the color associated with the item quality
  local r, g, b, hex = GetItemQualityColor(qualityIndex)
  -- Return the text wrapped in WoW's color formatting
  return string.format("%s%s|r", hex, text)
end

local function SetItemInfo(frame, itemLinkArg)
  local itemName, itemLink, itemQuality, _, _, _, _, _, itemIcon = GetItemInfo(itemLinkArg)
  if not frame.icon then InitItemInfo(frame) end

  -- if we know the item, and the quality isn't green+, don't show it
  if itemName and itemQuality < 2 then return false end
  if not itemIcon then
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    frame.name:SetText("Unknown item, attempting to query...")
    -- could be an item we want to see, try to show it
    return true
  end

  frame.icon:SetTexture(itemIcon)
  frame.iconButton:SetNormalTexture(itemIcon)  -- Sets the same texture as the icon

  frame.name:SetText(GetColoredTextByQuality(itemName,itemQuality))

  frame.itemLink = itemLink
  return true
end

local function ShowFrame(frame,duration,item)
  frame:SetScript("OnUpdate", function()
    time_elapsed = time_elapsed + arg1
    item_query = item_query - arg1
    if frame.timerText then frame.timerText:SetText(format("%.1f", duration - time_elapsed)) end
    if time_elapsed >= duration then
      frame:SetScript("OnUpdate", nil)
      time_elapsed = 0
      item_query = 1.5
      times = 3
      rollMessages = {}
      isRolling = false
      if FrameAutoClose then frame:Hide() end
    end
    if times > 0 and item_query < 0 and not CheckItem(item) then
      times = times - 1
    else
      if not SetItemInfo(itemRollFrame,item) then frame:Hide() end
      times = 5
    end
  end)
  frame:Show()
end

local function CreateTextArea(frame)
  local textArea = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  textArea:SetHeight(150) -- Size of the icon
  textArea:SetPoint("TOP", frame, "TOP", 0, -80)
  textArea:SetJustifyH("LEFT")
  textArea:SetJustifyV("TOP")

  return textArea
end

local function GetClassOfRoller(rollerName)
  -- Iterate through the raid roster
  for i = 1, GetNumRaidMembers() do
      local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i)
      if name == rollerName then
          return class -- Return the class as a string (e.g., "Warrior", "Mage")
      end
  end
  return nil -- Return nil if the player is not found in the raid
end

local function UpdateTextArea(frame)
  if not frame.textArea then
    frame.textArea = CreateTextArea(frame)
  end

  -- frame.textArea:SetTeClear()  -- Clear the existing messages
  local text = ""
  local colored_msg = ""
  local count = 0

  sortRolls()

  for i, v in ipairs(srRollMessages) do
    if count >= 5 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v) .. "\n"
    count = count + 1
  end
  for i, v in ipairs(msRollMessages) do
    if count >= 6 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v) .. "\n"
    count = count + 1
  end
  for i, v in ipairs(osRollMessages) do
    if count >= 7 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v) .. "\n"
    count = count + 1
  end
  for i, v in ipairs(tmogRollMessages) do
    if count >= 8 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v) .. "\n"
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

local function IsSenderMasterLooter(sender)
  local lootMethod, masterLooterPartyID = GetLootMethod()
  if lootMethod == "master" and masterLooterPartyID then
      if masterLooterPartyID == 0 then
          return sender == UnitName("player")
      else
        local senderUID = "party" .. masterLooterPartyID
        local masterLooterName = UnitName(senderUID)
        return masterLooterName == sender
      end
  end
  return false
end


local function HandleChatMessage(event, message, sender)
  if IsSenderMasterLooter(sender) and (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") then

    local _,_,duration = string.find(message, "Roll time set to (%d+) seconds")
    duration = tonumber(duration)
    if duration and duration ~= FrameShownDuration then
      FrameShownDuration = duration
      -- The players get the new duration from the master looter after the first rolls
      lb_print("Rolling duration set to " .. FrameShownDuration .. " seconds. (set by Master Looter)")
    end
  elseif event == "CHAT_MSG_SYSTEM" and isRolling then
    if string.find(message, "rolls") and string.find(message, "(%d+)") then
      local _,_,roller, roll, minRoll, maxRoll = string.find(message, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
      if roller and roll and rollers[roller] == nil then
        roll = tonumber(roll)
        rollers[roller] = 1
        message = { roller = roller, roll = roll, msg = message, class = GetClassOfRoller(roller) }
        if maxRoll == "101" then
          table.insert(srRollMessages, message)
        elseif maxRoll == "100" then
          table.insert(msRollMessages, message)
        elseif maxRoll == "99" then
          table.insert(osRollMessages, message)
        elseif maxRoll == "50" then
          table.insert(tmogRollMessages, message)
        end
        time_elapsed = 0
        UpdateTextArea(itemRollFrame)
      end
    end
  elseif event == "CHAT_MSG_RAID_WARNING" then
    local isSenderML = IsSenderMasterLooter(sender)
    if isSenderML then -- only show if the sender is the master looter

      -- check if the player is the sender of the message
      playerName = UnitName("player")
      if playerName == sender then
        -- send chat message to the raid
        SendChatMessage("Rolling is now open for " .. message .. ". Roll time set to " .. FrameShownDuration .. " seconds.", "RAID")
      end
      local links = ExtractItemLinksFromMessage(message)
      if tsize(links) == 1 then
        if string.find(message, "^No one has need:") or
           string.find(message,"has been sent to") or
           string.find(message, " received ") then
          itemRollFrame:Hide()
          return
        elseif string.find(message,"Rolling Cancelled") or -- usually a cancel is accidental in my experience
               string.find(message,"seconds left to roll") or
               string.find(message,"Rolling is now Closed") then
          return
        end
        resetRolls()
        UpdateTextArea(itemRollFrame)
        time_elapsed = 0
        isRolling = true
        ShowFrame(itemRollFrame,FrameShownDuration,links[1])
      end
    end
  elseif event == "ADDON_LOADED" and arg1 == "LootBlare" then
    if FrameShownDuration == nil then FrameShownDuration = 15 end
    if FrameAutoClose == nil then FrameAutoClose = true end
  end
end

itemRollFrame:RegisterEvent("ADDON_LOADED")
itemRollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
itemRollFrame:SetScript("OnEvent", function () HandleChatMessage(event,arg1,arg2) end)

-- Register the slash command
SLASH_LOOTBLARE1 = '/lootblare'
SLASH_LOOTBLARE2 = '/lb'

-- Command handler
SlashCmdList["LOOTBLARE"] = function(msg)
  if msg == "" then
    if itemRollFrame:IsVisible() then
      itemRollFrame:Hide()
    else
      itemRollFrame:Show()
    end
  elseif msg == "help" then
    lb_print("LootBlare is a simple addon that displays and sort item rolls in a frame.")
    lb_print("Type /lb time <seconds> to set the duration the frame is shown. This value will be automatically set by the master looter after the first rolls.")
    lb_print("Type /lb autoClose on/off to enable/disable auto closing the frame after the time has elapsed.")
    lb_print("Type /lb settings to see the current settings.")
  elseif msg == "settings" then
    lb_print("Frame shown duration: " .. FrameShownDuration .. " seconds.")
    lb_print("Auto closing: " .. (FrameAutoClose and "on" or "off"))
  elseif string.find(msg, "time") then
    local _,_,newDuration = string.find(msg, "time (%d+)")
    newDuration = tonumber(newDuration)
    if newDuration and newDuration > 0 then
      FrameShownDuration = newDuration
      lb_print("Roll time set to " .. newDuration .. " seconds.")
      if IsSenderMasterLooter(UnitName("player")) then
        SendChatMessage("Roll time set to " .. newDuration .. " seconds.", "RAID")
      end
    else
      lb_print("Invalid duration. Please enter a number greater than 0.")
    end
  elseif string.find(msg, "autoClose") then
    local _,_,autoClose = string.find(msg, "autoClose (%a+)")
    if autoClose == "on" then
      lb_print("Auto closing enabled.")
      FrameAutoClose = true
    elseif autoClose == "off" then
      lb_print("Auto closing disabled.")
      FrameAutoClose = false
    else
      lb_print("Invalid option. Please enter 'on' or 'off'.")
    end
  else
  lb_print("Invalid command. Type /lb help for a list of commands.")
  end
end