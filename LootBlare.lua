local state = {
  weird_vibes_mode = true,
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
}

local BUTTON_WIDTH = 32
local BUTTON_COUNT = 4
local BUTTON_PADING = 5
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
local LB_GET_DATA = "get data"
local LB_SET_ML = "ML set to "
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

local function formatMsg(message)
  local msg = message.msg
  local class = message.class
  local classColor = RAID_CLASS_COLORS[class]
  local textColor = colors.DEFAULT_TEXT_COLOR

  if message.maxRoll > state.msRollCap then
    textColor = colors.SR_TEXT_COLOR
  elseif message.maxRoll == state.msRollCap then
    textColor = colors.MS_TEXT_COLOR
  elseif message.maxRoll == state.osRollCap then
    textColor = colors.OS_TEXT_COLOR
  elseif message.maxRoll < state.osRollCap then
    textColor = colors.TM_TEXT_COLOR
  end

  local c_class = format("|c%s%-12s|r", classColor, message.roller)
  local max_or_special
  if message.minRoll == 1 and message.maxRoll == state.srRollCap then
    max_or_special = " SR"
  elseif message.minRoll == 1 and message.maxRoll == state.msRollCap then
    max_or_special = " MS"
  elseif message.minRoll == 1 and message.maxRoll == state.osRollCap then
    max_or_special = " OS"
  elseif message.minRoll == 1 and message.maxRoll == state.tmogRollCap then
    max_or_special = " TM"
  end
  local c_min = message.minRoll == 1 and "" or ("|cFFFF0000" .. message.minRoll .. "|c" .. textColor .. "-")
  local c_end = max_or_special or format("(%s%d)", c_min, tostring(message.maxRoll))

  return format("%s|c%s%-3s%s|r", c_class, textColor, message.roll, c_end)
end

local function tsize(t)
  c = 0
  for _ in pairs(t) do
    c = c + 1
  end
  if c > 0 then return c else return nil end
end

local function IsInRaid()
  return GetNumRaidMembers() > 0
end

local function IsInGroup()
  return GetNumPartyMembers() + GetNumRaidMembers() > 0
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
    state.time_elapsed = state.time_elapsed + arg1
    state.item_query = state.item_query - arg1
    local delta = duration - state.time_elapsed
    if frame.timerText then frame.timerText:SetText(format("%.1f", delta > 0 and delta or 0)) end
    if state.time_elapsed >= max(duration,FrameShownDuration) then
      frame.timerText:SetText("0.0")
      frame:SetScript("OnUpdate", nil)
      state.time_elapsed = 0
      state.item_query = 1.5
      state.times = 3
      rollMessages = {}
      state.isRolling = false
      if FrameAutoClose and not (state.masterLooter == UnitName("player")) then frame:Hide() end
    end
    if state.times > 0 and state.item_query < 0 and not CheckItem(item) then
      state.times = state.times - 1
    else
      if not SetItemInfo(itemRollFrame,item) then frame:Hide() end
      state.times = 5
    end
  end)
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

  for i, v in ipairs(state.rollMessages) do
    if count >= 9 then break end
    colored_msg = v.msg
    text = text .. formatMsg(v) .. "\n"
    count = count + 1
  end

  frame.textArea:SetText(text)
end

local function ExtractItemLinksFromMessage(message)
  local itemLinks = {}
  -- This pattern matches the standard item link structure in WoW
  for link in string.gfind(message, "|c.-|H(item:.-)|h.-|h|r") do
    table.insert(itemLinks, link)
  end
  return itemLinks
end

-- this isn't quite right, should just check if you are ML, since it can only check you and your party anyway rather than the whole raid
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

local function GetMasterLooterInParty()
  local lootMethod, masterLooterPartyID = GetLootMethod()
  if lootMethod == "master" and masterLooterPartyID then
    if masterLooterPartyID == 0 then
      return UnitName("player")
    else
      local senderUID = "party" .. masterLooterPartyID
      local masterLooterName = UnitName(senderUID)
      return masterLooterName
    end
  end
  return nil
end

-- todo, test this
local function PlayerIsML()
  local lootMethod, masterLooterPartyID = GetLootMethod()
  return lootMethod == "master" and masterLooterPartyID and (masterLooterPartyID == 0)
end

local pendingRequest, requestDelay = false, 0
local pendingSet, setDelay, setName = false, 1, ""
local function RequestML(delay)
  pendingRequest = true
  requestDelay   = delay or 3.0
end

local delayFrame = CreateFrame("Frame")
delayFrame:SetScript("OnUpdate", function()
  local elapsed = arg1
  if pendingRequest then
    requestDelay = requestDelay - elapsed
    if requestDelay<=0 then
      pendingRequest = false
      -- if IsInGroup() then
      SendAddonMessage(LB_PREFIX, LB_GET_DATA, GetNumRaidMembers() > 0 and "RAID" or "PARTY")
      -- end
    end
  end
  if pendingSet then
    setDelay = setDelay - elapsed
    if setDelay<=0 then
      pendingSet = false
      setDelay = 1

      if not state.masterLooter or (state.masterLooter and (state.masterLooter ~= setName)) then
        lb_print("Masterlooter set to |cFF00FF00" .. setName .. "|r")
      end
      state.masterLooter = setName
    end
  end
end)

function itemRollFrame:CHAT_MSG_LOOT(message)
  -- Hide frame for masterlooter when loot is awarded
  if not ItemRollFrame:IsVisible() or state.masterLooter ~= UnitName("player") then return end

  local _,_,who = string.find(message, "^(%a+) receive.? loot:")
  local links = ExtractItemLinksFromMessage(message)

  if who and tsize(links) == 1 then
    if this.itemLink == links[1] then
      resetRolls()
      this:Hide()
    end
  end
end

function itemRollFrame:CHAT_MSG_SYSTEM(message)
  -- detect ML announcements
  local _,_, newML = string.find(message,"(.+) is now the loot master")
  if newML then
    -- state.masterLooter = newML
    -- lb_print("Master looter set to "..newML)
    itemRollFrame:SendML(newML)
    return
  end
  if state.isRolling and string.find(message, "rolls") and string.find(message, "(%d+)") then
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

function itemRollFrame:CHAT_MSG_RAID_WARNING(message,sender)
  if sender ~= state.masterLooter then return end

  local links = ExtractItemLinksFromMessage(message)
  if tsize(links) == 1 then
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

function itemRollFrame:SendML(masterlooter)
  local chan = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
  -- send the chosen ML
  SendAddonMessage(LB_PREFIX,LB_SET_ML .. masterlooter,chan)
  -- send time if we're the chosen ML
  if masterLooter == UnitName("player") then
    SendAddonMessage(LB_PREFIX,LB_SET_ROLL_TIME .. FrameShownDuration,chan)
  end
end

function itemRollFrame:CHAT_MSG_ADDON(prefix,message,channel,sender)
  local player = UnitName("player")

  -- Someone is asking for the master looter and his roll time
  if message == LB_GET_DATA then
    local pml = GetMasterLooterInParty()
    if pml then
      self:SendML(pml)
    elseif state.masterLooter then
      self:SendML(state.masterLooter)
    end
    return
  end

  -- Someone is setting the master looter
  if string.find(message, LB_SET_ML) then
    local _,_, newML = string.find(message, "ML set to (%S+)")
    if newML then
      pendingSet = true
      setName = newML
    end
    return
  end

  -- Someone is setting the roll time
  if string.find(message, LB_SET_ROLL_TIME) then
    local _,_,duration = string.find(message, "Roll time set to (%d+)")
    duration = tonumber(duration)
    if duration and duration ~= state.MLRollDuration then
      state.MLRollDuration = duration
      if not IsSenderMasterLooter(player) then
        local roll_string = "Roll time set to " .. state.MLRollDuration .. " seconds by Master Looter."
        if state.MLRollDuration ~= FrameShownDuration then
          roll_string = roll_string .. " Your display time is " .. FrameShownDuration .." seconds."
        end
        lb_print(roll_string)
      end
    end
    return
  end
end

function itemRollFrame:RAID_ROSTER_UPDATE()
  RequestML(0.5)
end

function itemRollFrame:PARTY_MEMBERS_CHANGED()
  RequestML(0.5)
end

function itemRollFrame:PLAYER_ENTERING_WORLD()
  RequestML(8)
end

function itemRollFrame:PARTY_LOOT_METHOD_CHANGED()
  RequestML(0.5)
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
-- itemRollFrame:RegisterEvent("CHAT_MSG_RAID")
-- itemRollFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
itemRollFrame:RegisterEvent("CHAT_MSG_ADDON")
itemRollFrame:RegisterEvent("CHAT_MSG_LOOT")
itemRollFrame:RegisterEvent("RAID_ROSTER_UPDATE")
itemRollFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
itemRollFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
itemRollFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
  -- if msg == "" then
    -- if itemRollFrame:IsVisible() then
      -- itemRollFrame:Hide()
    -- else
      -- itemRollFrame:Show()
    -- end
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
      if IsSenderMasterLooter(UnitName("player")) then
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