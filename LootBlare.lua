-- Debug options (not user-facing)
local LB_DEBUG = true

local state = {
  rollMessages = {},
  rollers = {},
  isRolling = false,
  time_elapsed = 0,
  item_query = 0.5,
  times = 5,
  discover = CreateFrame("GameTooltip", "CustomTooltip1", UIParent, "GameTooltipTemplate"),
  masterLooter = nil,
  srRollCap = 101,
  msRollCap = 100,
  osRollCap = 99,
  tmogRollCap = 50,
  MLRollDuration = 15,
  rollDuration = 15,
  currentItem = nil,
}

local BUTTON_WIDTH = 32
local BUTTON_COUNT = 4
local BUTTON_PADDING = 5
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
local colors = {
  ADDON_TEXT_COLOR = "FFEDD8BB",
  DEFAULT_TEXT_COLOR = "FFFFFF00",
  SR_TEXT_COLOR = "ffe5302d",
  MS_TEXT_COLOR = "FFFFFF00",
  OS_TEXT_COLOR = "FF00FF00",
  TM_TEXT_COLOR = "FF00FFFF",
  OTHER_TEXT_COLOR = "ffff80be",
}

local LB_PREFIX = "LootBlare"
local LB_SET_ROLL_TIME = "Roll time set to "

local function lb_print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|c" .. colors.ADDON_TEXT_COLOR .. "LootBlare: " .. msg .. "|r")
end

local function resetRolls()
  state.rollMessages = {}
  state.rollers = {}
end

local function sortRolls()
  table.sort(state.rollMessages, function(a, b)
    -- Primary grouping: All entries with minRoll==1 come first.
    if a.minRoll == 1 and b.minRoll ~= 1 then
      return true
    elseif a.minRoll ~= 1 and b.minRoll == 1 then
      return false
    end

    -- Now both entries are in the same overall minRoll group.

    -- Secondary: sort by maxRoll descending.
    if a.maxRoll ~= b.maxRoll then
      return a.maxRoll > b.maxRoll
    end

    -- Tertiary: if we are in the non-minRoll==1 group, sort by minRoll descending.
    if a.minRoll ~= b.minRoll then
      return a.minRoll > b.minRoll
    end

    -- Finally: sort by the actual roll descending.
    return a.roll > b.roll
  end)
end

-- Cache for formatted strings to avoid repeated formatting
local formatCache = {}
local cacheSize = 0
local MAX_CACHE_SIZE = 100

local function formatMsg(message)
  local cacheKey = message.roller .. ":" .. message.roll .. ":" .. message.minRoll .. ":" .. message.maxRoll
  local cached = formatCache[cacheKey]
  if cached then return cached end

  local class = message.class
  local classColor = RAID_CLASS_COLORS[class] or "FFFFFFFF"
  local textColor
  
  -- Optimize color selection with early termination
  if message.maxRoll > state.msRollCap then
    textColor = colors.SR_TEXT_COLOR
  elseif message.maxRoll == state.msRollCap then
    textColor = colors.MS_TEXT_COLOR
  elseif message.maxRoll == state.osRollCap then
    textColor = colors.OS_TEXT_COLOR
  elseif message.maxRoll <= state.tmogRollCap then
    textColor = colors.TM_TEXT_COLOR
  else
    textColor = colors.DEFAULT_TEXT_COLOR
  end

  local c_class = format("|c%s%-12s|r", classColor, message.roller)
  local max_or_special
  
  if message.minRoll == 1 then
    if message.maxRoll == state.srRollCap then
      max_or_special = " SR"
    elseif message.maxRoll == state.msRollCap then
      max_or_special = " MS"
    elseif message.maxRoll == state.osRollCap then
      max_or_special = " OS"
    elseif message.maxRoll == state.tmogRollCap then
      max_or_special = " TM"
    end
  end
  
  local c_min = message.minRoll == 1 and "" or ("|cFFFF0000" .. message.minRoll .. "|c" .. textColor .. "-")
  local c_end = max_or_special or format("(%s%d)", c_min, message.maxRoll)
  
  local result = format("%s|c%s%-3s%s|r", c_class, textColor, message.roll, c_end)
  
  -- Cache management
  if cacheSize < MAX_CACHE_SIZE then
    formatCache[cacheKey] = result
    cacheSize = cacheSize + 1
  end
  
  return result
end

local function PlayerIsML()
  local lootMethod, masterLooterPartyID = GetLootMethod()
  return lootMethod == "master" and masterLooterPartyID and (masterLooterPartyID == 0)
end

-- Function to return colored text based on item quality
local function GetColoredTextByQuality(text, qualityIndex)
  -- Get the color associated with the item quality
  local _, _, _, hex = GetItemQualityColor(qualityIndex)
  -- Return the text wrapped in WoW's color formatting
  return string.format("%s%s|r", hex, text)
end

local function CheckItem(link)
  state.discover:SetOwner(UIParent, "ANCHOR_PRESERVE")
  state.discover:SetHyperlink(link)

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
  button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", index*spacing + (index-1)*BUTTON_WIDTH, BUTTON_PADDING)

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
  name:SetPoint("TOP", icon, "BOTTOM", 0, -2)

  frame.icon = icon
  frame.iconButton = iconButton
  frame.timerText = timerText
  frame.name = name
  frame.itemLink = ""

  local tt = CreateFrame("GameTooltip", "CustomTooltip2", UIParent, "GameTooltipTemplate")

  -- Set up tooltip
  iconButton:SetScript("OnEnter", function()
    tt:SetOwner(iconButton, "ANCHOR_RIGHT")
    tt:SetHyperlink(frame.itemLink or state.currentItem)
    tt:Show()
  end)
  iconButton:SetScript("OnLeave", function()
    tt:Hide()
  end)
  iconButton:SetScript("OnClick", function()
    local currentLink = frame.itemLink or state.currentItem
    if ( IsControlKeyDown() ) then
      DressUpItemLink(currentLink);
    elseif ( IsShiftKeyDown() and ChatFrameEditBox:IsVisible() ) then
      local itemName, itemLink, itemQuality, _, _, _, _, _, itemIcon = GetItemInfo(currentLink)
      if itemLink then
        ChatFrameEditBox:Insert(ITEM_QUALITY_COLORS[itemQuality].hex.."\124H"..itemLink.."\124h["..itemName.."]\124h"..FONT_COLOR_CODE_CLOSE);
      end
    end
  end)
end

local function SetItemInfo(frame, itemLinkArg)
  local itemName, itemLink, itemQuality, _, _, _, _, _, itemIcon = GetItemInfo(itemLinkArg)

  -- if we know the item, and the quality isn't green+, don't show it (unless debug flag is set)
  if itemName and itemQuality < 2 and not LB_DEBUG then return false end
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

local function CreateItemRollFrame()
  local frame = CreateFrame("Frame", "ItemRollFrame", UIParent)
  frame:SetWidth(165) -- Adjust size as needed
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
  CreateActionButton(frame, "SR", "Roll for Soft Reserve", 1, function() RandomRoll(1,state.srRollCap) end)
  CreateActionButton(frame, "MS", "Roll for Main Spec", 2, function() RandomRoll(1,state.msRollCap) end)
  CreateActionButton(frame, "OS", "Roll for Off Spec", 3, function() RandomRoll(1,state.osRollCap) end)
  CreateActionButton(frame, "TM", "Roll for Transmog", 4, function() RandomRoll(1,state.tmogRollCap) end)
  
  -- Initialize UI elements immediately
  InitItemInfo(frame)
  
  frame:Hide()

  return frame
end

local itemRollFrame = CreateItemRollFrame()

-- Set up persistent OnUpdate handler
itemRollFrame:SetScript("OnUpdate", function()
  local elapsed = arg1
  if not state.isRolling or not elapsed then return end

  state.time_elapsed = state.time_elapsed + elapsed
  state.item_query = state.item_query - elapsed
  
  local delta = state.rollDuration - state.time_elapsed
  if this.timerText then 
    this.timerText:SetText(format("%.1f", delta > 0 and delta or 0)) 
  end
  
  if state.time_elapsed >= max(state.rollDuration, FrameShownDuration) then
    this.timerText:SetText("0.0")
    state.time_elapsed = 0
    state.item_query = 1.5
    state.times = 3
    state.rollMessages = {}
    state.isRolling = false
    if FrameAutoClose and not PlayerIsML() then 
      this:Hide() 
    end
    return
  end
  
  if state.times > 0 and state.item_query < 0 and state.currentItem and not CheckItem(state.currentItem) then
    state.times = state.times - 1
  elseif state.currentItem then
    if not SetItemInfo(this, state.currentItem) then 
      this:Hide() 
    end
    state.times = 5
  end
end)

local function ShowFrame(frame,duration,item)
  state.rollDuration = duration
  state.currentItem = item
  state.isRolling = true
  state.time_elapsed = 0
  SetItemInfo(frame, item)
  frame:Show()
end

local function CreateTextArea(frame)
  local textArea = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  textArea:SetFont("Interface\\AddOns\\LootBlare\\MonaspaceNeonFrozen-Regular.ttf", 12, "")
  textArea:SetHeight(150)
  -- textArea:SetWidth(150)
  textArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -70)
  textArea:SetJustifyH("LEFT")
  textArea:SetJustifyV("TOP")

  return textArea
end

local classCache = {}
local function GetClassOfRoller(rollerName)
  local cached = classCache[rollerName]
  if cached then return cached end
  -- Iterate through the raid roster
  for i = 1, GetNumRaidMembers() do
    local name, _rank, _subgroup, _level, class, _fileName, _zone, _online, _isDead, _role, isML = GetRaidRosterInfo(i)
    if name == rollerName then
      classCache[rollerName] = class
      return class -- Return the class as a string (e.g., "Warrior", "Mage")
    end
  end
  return nil -- Return nil if the player is not found in the raid
end

local textBuffer = {}
local function UpdateTextArea(frame)
  if not frame.textArea then
    frame.textArea = CreateTextArea(frame)
  end

  sortRolls()
  
  -- Use table for efficient string building
  local count = 0
  local maxMessages = getn(state.rollMessages)
  local limit = maxMessages > 9 and 9 or maxMessages
  
  for i = 1, limit do
    count = count + 1
    textBuffer[count] = formatMsg(state.rollMessages[i])
  end
  
  -- Clear remaining buffer slots
  for i = count + 1, getn(textBuffer) do
    textBuffer[i] = nil
  end

  frame.textArea:SetText(table.concat(textBuffer, "\n"))
end

local function ExtractItemLinksFromMessage(message)
  local itemLinks = {}
  -- This pattern matches the standard item link structure in WoW
  for link in string.gfind(message, "|c.-|H(item:.-)|h.-|h|r") do
    table.insert(itemLinks, link)
  end
  return itemLinks
end


function itemRollFrame:CHAT_MSG_LOOT(message)
  -- Hide frame when loot is awarded
  if not ItemRollFrame:IsVisible() then return end

  local _,_,who = string.find(message, "^(%a+) receive.? loot:")
  if not who then return end
  
  local links = ExtractItemLinksFromMessage(message)

  if links[1] and not links[2] then
    if this.itemLink == links[1] then
      resetRolls()
      this:Hide()
    end
  end
end

function itemRollFrame:CHAT_MSG_SYSTEM(message)
  -- Early return if message doesn't contain relevant keywords
  if not string.find(message, "loot master") and not (state.isRolling and string.find(message, "rolls")) then
    return
  end
  
  -- detect ML announcements
  local _,_, newML = string.find(message,"(.+) is now the loot master")
  if newML then
    -- Send roll time if we became ML
    itemRollFrame:SendRollTime()
    return
  end
  
  if state.isRolling and string.find(message, "(%d+)") then
    local _,_,roller, roll, minRoll, maxRoll = string.find(message, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
    if roller and roll and (state.rollers[roller] == nil or LB_DEBUG) then
      roll = tonumber(roll)
      minRoll = tonumber(minRoll)
      maxRoll = tonumber(maxRoll)
      state.rollers[roller] = 1
      message = { roller = roller, roll = roll, minRoll = minRoll, maxRoll = maxRoll, msg = message, class = GetClassOfRoller(roller) }

      table.insert(state.rollMessages, message)
      UpdateTextArea(itemRollFrame)
    end
  end
end

function itemRollFrame:CHAT_MSG_RAID_WARNING(message, _sender)
  -- Early return if no item link patterns found
  if not string.find(message, "|c.-|H") then return end
  
  local links = ExtractItemLinksFromMessage(message)
  if links[1] and not links[2] then
    -- interaction with other looting addons
    if string.find(message, "^No one has nee") or
      -- prevents reblaring on loot award
      string.find(message,"has been sent to") or
      string.find(message, " received ") then
      return
    end
    resetRolls()
    UpdateTextArea(itemRollFrame)
    state.time_elapsed = 0
    state.isRolling = true
    ShowFrame(itemRollFrame,state.MLRollDuration,links[1])
  end
end

function itemRollFrame:SendRollTime()
  -- send time if we're the ML
  if PlayerIsML() then
    local chan = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    SendAddonMessage(LB_PREFIX,LB_SET_ROLL_TIME .. FrameShownDuration,chan)
  end
end

function itemRollFrame:CHAT_MSG_ADDON(prefix,message,channel,sender)
  -- Early return if not our addon
  if prefix ~= LB_PREFIX then return end
  
  -- Someone is setting the roll time
  if string.find(message, LB_SET_ROLL_TIME) then
    local _,_,duration = string.find(message, "Roll time set to (%d+)")
    duration = tonumber(duration)
    if duration and duration ~= state.MLRollDuration then
      state.MLRollDuration = duration
      local roll_string = "Roll time set to " .. state.MLRollDuration .. " seconds by Master Looter."
      if state.MLRollDuration ~= FrameShownDuration then
        roll_string = roll_string .. " Your display time is " .. FrameShownDuration .." seconds."
      end
      lb_print(roll_string)
    end
  end
end

function itemRollFrame:PARTY_LOOT_METHOD_CHANGED()
  -- Send roll time if we became ML
  self:SendRollTime()
end

function itemRollFrame:ADDON_LOADED(addon)
  if addon ~= "LootBlare" then return end

  if FrameShownDuration == nil then FrameShownDuration = 15 end
  if FrameAutoClose == nil then FrameAutoClose = true end
  state.MLRollDuration = FrameShownDuration
end

itemRollFrame:RegisterEvent("ADDON_LOADED")
itemRollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
itemRollFrame:RegisterEvent("CHAT_MSG_ADDON")
itemRollFrame:RegisterEvent("CHAT_MSG_LOOT")
itemRollFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
-- itemRollFrame:SetScript("OnEvent", function () HandleChatMessage(event,arg1,arg2) end)
itemRollFrame:SetScript("OnEvent", function ()
  itemRollFrame[event](itemRollFrame,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
end)

-- Register the slash command
SLASH_LOOTBLARE1 = '/lootblare'
SLASH_LOOTBLARE2 = '/lb'

-- Command handler
SlashCmdList["LOOTBLARE"] = function(msg)
  msg = string.lower(msg)
  if msg == "help" or msg == "" then
    lb_print("LootBlare " .. GetAddOnMetadata("LootBlare","Version") .. " is a simple addon that displays sorted item rolls in a frame.")
    lb_print("Type /lb time <seconds> to set the duration the frame is shown.")
    lb_print("Type /lb autoClose on/off to enable/disable auto closing the frame after the time has elapsed.")
    lb_print("Type /lb settings to see the current settings.")
  elseif msg == "settings" then
    lb_print("Frame shown duration: " .. FrameShownDuration .. " seconds.")
    lb_print("Auto closing: " .. (FrameAutoClose and "on" or "off"))
    lb_print("Master Looter: " .. (state.masterLooter or "unknown"))
  elseif string.find(msg, "time") then
    local _,_,newDuration = string.find(msg, "time (%d+)")
    newDuration = tonumber(newDuration)
    if newDuration and newDuration > 0 then
      FrameShownDuration = newDuration
      lb_print("Roll time set to " .. newDuration .. " seconds.")
      if PlayerIsML() then
        SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. newDuration, GetNumRaidMembers() > 0 and "RAID" or "PARTY")
      end
    else
      lb_print("Invalid duration. Please enter a number greater than 0.")
    end
  elseif string.find(msg, "autoclose") then
    local _,_,autoClose = string.find(msg, "autoclose (%a+)")
    if autoClose == "on" or autoClose == "true" then
      lb_print("Auto closing enabled.")
      FrameAutoClose = true
    elseif autoClose == "off" or autoClose == "false" then
      lb_print("Auto closing disabled.")
      FrameAutoClose = false
    else
      lb_print("Invalid option. Please enter 'on' or 'off'.")
    end
  else
  lb_print("Invalid command. Type /lb help for a list of commands.")
  end
end