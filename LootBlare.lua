LootBlare = LootBlare or {}
local weird_vibes_mode = true
local srRollMessages = {}
local msRollMessages = {}
local msPlusRollMessages = {}
local osRollMessages = {}
local tmogRollMessages = {}
local rollers = {}
local isRolling = false
local time_elapsed = 0
local item_query = 0.5
local times = 5
local discover = CreateFrame("GameTooltip", "CustomTooltip1", UIParent, "GameTooltipTemplate")
LootBlare.masterLooter = nil
local srRollCap = 100
local msRollCap = 100
local msPlusRollCap = 120
local osRollCap = 99
local tmogRollCap = 98

LootBlare.rollBonuses = LootBlare.rollBonuses or {}
LootBlare.msplus = LootBlare.msplus or {}
local currentItem = ""
local importText = "" -- will hold the imported text


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
--local SR_TEXT_COLOR = "FFFF0000"
local SR_TEXT_COLOR = "FFFF0000"
local MS_TEXT_COLOR = "FFFFFF00"
local MSPlus_TEXT_COLOR = "00FFFF00"
local OS_TEXT_COLOR = "FF00FF00"
local TM_TEXT_COLOR = "FF00FFFF"

local LB_PREFIX = "LootBlare"
local LB_GET_DATA = "get data"
local LB_SET_ML = "ML set to "
local LB_SET_ROLL_TIME = "Roll time set to "

UIPanelWindows["LootBlareImportFrame"] = { area = "center", pushable = 1 }

local function lb_print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|c" .. ADDON_TEXT_COLOR .. "LootBlare: " .. msg .. "|r")
end

local function resetRolls()
  srRollMessages = {}
  msRollMessages = {}
  msPlusRollMessages = {}
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
table.sort(msPlusRollMessages, function(a, b)
  if a.maxRoll ~= b.maxRoll then
    return a.maxRoll < b.maxRoll  -- highest total first
  else
    return a.roll > b.roll    -- fallback to base roll
  end
end)
  table.sort(osRollMessages, function(a, b)
    return a.roll > b.roll
  end)
  table.sort(tmogRollMessages, function(a, b)
    return a.roll > b.roll
  end)
end

local function IsInSRRollMessages(msg)
    for _, entry in ipairs(srRollMessages) do
        if msg == entry then
            return true
        end
    end
    return false
end

local function colorMsg(message, isSR)
  msg = message.msg
  class = message.class
  _,_,_, message_end = string.find(msg, "(%S+)%s+(.+)")
  classColor = RAID_CLASS_COLORS[class]
  textColor = DEFAULT_TEXT_COLOR

  if isSR and string.find(msg, "-"..srRollCap) then
    textColor = SR_TEXT_COLOR
    --print("[DEBUG] SR" .. msg)
  elseif string.find(msg, "-"..msRollCap) then
    textColor = MS_TEXT_COLOR  
  elseif string.find(msg, "-"..osRollCap) then
    textColor = OS_TEXT_COLOR
  elseif string.find(msg, "-"..tmogRollCap) then
    textColor = TM_TEXT_COLOR
  else
    textColor = MSPlus_TEXT_COLOR
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

   local function GetPointsByName(name)
        for i, member in pairs(LootBlare.msplus) do 
            if member.name == name then
                return member.points
            end
        end
    end

local function CreateCloseButton(frame)
  -- Add a close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetWidth(32) -- Button size
  closeButton:SetHeight(32) -- Button size
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2) -- Position at the top right

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
  frame:SetWidth(320) -- Adjust size as needed
  frame:SetHeight(250)
  frame:SetPoint("CENTER",UIParent,"CENTER",0,0) -- Position at center of the parent frame
  frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile="Interface/DialogFrame/UI-DialogBox-Border",
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
  CreateActionButton(frame, "SR", "Roll for Soft Reserve", 1, function() RandomRoll(1,srRollCap) end)
  CreateActionButton(frame, "MS", "Roll for Main Spec", 2, function() RandomRoll(1,100+GetPointsByName(UnitName("player"))) end)
  CreateActionButton(frame, "OS", "Roll for Off Spec", 3, function() RandomRoll(1,osRollCap) end)
  CreateActionButton(frame, "TM", "Roll for Transmog", 4, function() RandomRoll(1,tmogRollCap) end)
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
      frame.timerText:SetText("0.0")
      frame:SetScript("OnUpdate", nil)
      time_elapsed = 0
      item_query = 1.5
      times = 3
      --rollMessages = {}
      isRolling = false
      if FrameAutoClose and not (LootBlare.masterLooter == UnitName("player")) then frame:Hide() end
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
    text = text .. colorMsg(v, true) .. "\n"
    count = count + 1
  end
  for i, v in ipairs(msRollMessages) do
    if count >= 6 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v, false) .. "\n"
    count = count + 1
  end
    for i, v in ipairs(msPlusRollMessages) do
    if count >= 6 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v, false) .. "\n"
    count = count + 1
  end
  for i, v in ipairs(osRollMessages) do
    if count >= 7 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v, false) .. "\n"
    count = count + 1
  end
  for i, v in ipairs(tmogRollMessages) do
    if count >= 8 then break end
    colored_msg = v.msg
    text = text .. colorMsg(v, false) .. "\n"
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

  local iterator = string.gfind(message, "|c.-|Hitem:.-|h%[([^%]]+)%]|h|r")
  local itemName = iterator()
  if itemName then
    currentItem = itemName
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

function HandleEditBox(editBox)
  local scrollBar = getglobal(editBox:GetParent():GetName().."ScrollBar")
  editBox:GetParent():UpdateScrollChildRect();

  local _, max = scrollBar:GetMinMaxValues();
  scrollBar.prevMaxValue = scrollBar.prevMaxValue or max

  if math.abs(scrollBar.prevMaxValue - scrollBar:GetValue()) <= 1 then
      -- if scroll is down and add new line then move scroll
      scrollBar:SetValue(max);
  end
  if max ~= scrollBar.prevMaxValue then
      -- save max value
      scrollBar.prevMaxValue = max
  end
end



---------------------------------------------------------------------
--                      SR Import
---------------------------------------------------------------------

local function SplitBySemicolon(text)
  local result = {}
  local index = 1

  for entry in string.gfind(text, "([^;]+)") do
    result[index] = entry
    index = index + 1
  end

  return result
end

local function SplitByNewline(text)
  local result = {}
  text = string.gsub(text, "\r\n", "\n")
  text = string.gsub(text, "\r", "\n")

  local index = 1
  for entry in string.gfind(text, "([^\n]+)") do
    result[index] = entry
    index = index + 1
  end
  return result
end

-- Helper function to detect if the text matches the CSV format
local function DetectCSVFormat(text)
  -- Check if the text contains headers typical for the CSV format
   if string.find(text, "ID%s*,%s*Item%s*,%s*Boss") then
    return true
  end
  return false
end

local function SplitCSVLine(line)
  local fields = {}
  local currentField = ""
  local insideQuotes = false
  local i = 1
  local len = string.len(line)
  while i <= len do
    local char = string.sub(line, i, i)
    if char == '"' then
      insideQuotes = not insideQuotes
    elseif char == ',' and not insideQuotes then
      local trimmedField = currentField
      local startPos, endPos = string.find(trimmedField, "^%s*(.-)%s*$")
      if startPos then
        trimmedField = string.sub(trimmedField, startPos, endPos)
      end
      table.insert(fields, trimmedField)
      currentField = ""
    else
      currentField = currentField .. char
    end
    i = i + 1
  end
  if string.len(currentField) > 0 then
    local trimmedField = currentField
    local startPos, endPos = string.find(trimmedField, "^%s*(.-)%s*$")
    if startPos then
      trimmedField = string.sub(trimmedField, startPos, endPos)
    end
    table.insert(fields, trimmedField)
  end

  return fields
end



-- Function to handle the new CSV format
local function LootBlare_ImportDataSRFormat(text)
  LootBlare.rollBonuses = {} -- Clear the existing table

  if not text or text == "" then
    DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] No text received or text is empty! ", 1, 1, 0)
    return
  end
  -- Split the input text into lines
  local lines = SplitByNewline(text)
  local imported = 0

  -- Skip header line
  local header = table.remove(lines, 1)
  for _, line in ipairs(lines) do
    -- Trim whitespace
    line = gsub(line, "^%s*(.-)%s*$", "%1")

    local fields = SplitCSVLine(line)

    -- Assuming the columns are as per the example:
    -- ID, Item, Boss, Attendee, Class, Specialization, Comment, Date (GMT), SR+
    local item = fields[2]
    local player = fields[4] -- Attendee is the player
    local bonus = 0  -- Points should be 0 for this format

    if player and item then
      if not LootBlare.rollBonuses[player] then
        LootBlare.rollBonuses[player] = {}
      end
      LootBlare.rollBonuses[player][item] = bonus
      DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Set Player: " .. player .. " SR=" .. item .. " Bonus= " .. bonus)
      imported = imported + 1
    else
      DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Skipped malformed line: " .. line)
    end
  end

  LootBlare:RequestSync()
end

-- Function to handle the old format (semicolon-separated)
local function LootBlare_ImportDataSRPlusFormat(text)
  LootBlare.rollBonuses = {} -- Clear the existing table 

  if not text or text == "" then
    DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] No text received or text is empty! ", 1, 1, 0)
    return
  end

  local lines = SplitBySemicolon(text)
  local imported = 0

  for _, line in ipairs(lines) do
    -- Trim whitespace
    line = gsub(line, "^%s*(.-)%s*$", "%1")

    local player, itemID, bonus = nil, nil, nil
    for entry in string.gfind(line, "([^|]+)") do
      if not player then
        player = entry
      elseif not itemID then
        itemID = entry
      elseif not bonus then
        bonus = entry
      end
    end

    if player and itemID and bonus then
      if not LootBlare.rollBonuses[player] then
        LootBlare.rollBonuses[player] = {}
      end
      LootBlare.rollBonuses[player][itemID] = bonus
      imported = imported + 1
    else
      DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Skipped malformed line: " .. line)
    end
  end

  LootBlare:RequestSync()
end


-- Main function to decide which format to import
function LootBlare_ImportData(text)
  -- Check if the text is in CSV format
  if DetectCSVFormat(text) then
    LootBlare_ImportDataSRFormat(text)
  else
    LootBlare_ImportDataSRPlusFormat(text)
  end
end


local function SplitRollMessage(msg)
  local _, _, who, roll, minRoll, maxRoll = string.find(msg, "^(%S+)%s+.*%s+(%d+)%s+%((%d+)%-(%d+)%)")
  local before = who .. " rolls " .. roll
  local bracket = "("..minRoll.."-"..maxRoll..")"
  if before and bracket then
      return before, bracket
  else
      return msg, nil -- fallback if no brackets found
  end
end

local function HandleChatMessage(event, message, sender)
  if (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") then
    local _,_,duration = string.find(message, "Roll time set to (%d+) seconds")
    duration = tonumber(duration)
    if duration and duration ~= FrameShownDuration then
      FrameShownDuration = duration
      -- The players get the new duration from the master looter after the first rolls
      lb_print("Rolling duration set to " .. FrameShownDuration .. " seconds. (set by Master Looter)")
    end
  elseif event == "CHAT_MSG_LOOT" then
    -- Hide frame for masterlooter when loot is awarded
    if not ItemRollFrame:IsVisible() or LootBlare.masterLooter ~= UnitName("player") then return end

    local _,_,who = string.find(message, "^(%a+) receive.? loot:")
    local links = ExtractItemLinksFromMessage(message)

    if who and tsize(links) == 1 then
      if this.itemLink == links[1] then
        resetRolls()
        this:Hide()
      end
    end
  elseif event == "CHAT_MSG_SYSTEM" then
    local _,_, newML = string.find(message, "(%S+) is now the loot master")
    if newML then
      LootBlare.masterLooter = newML
      LootBlare:RequestSync()
      playerName = UnitName("player")
      -- if the player is the new master looter, announce the roll time
      if newML == playerName then
        SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. FrameShownDuration .. " seconds", "RAID")
      end
    elseif isRolling and string.find(message, "rolls") and string.find(message, "(%d+)") then
      --print("[DEBUG] Received message: " .. message)
      --print("[DEBUG] isRolling = " .. tostring(isRolling))
      local _,_,roller, roll, minRoll, maxRoll = string.find(message, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
      --print("[DEBUG] Parsed roll: roller=" .. tostring(roller) ..
      --", roll=" .. tostring(roll) ..
      --", minRoll=" .. tostring(minRoll) ..
      --", maxRoll=" .. tostring(maxRoll))
      if roller and roll and rollers[roller] == nil then
        --print("[DEBUG] New roller:" .. roller)
        roll = tonumber(roll)
        rollers[roller] = 1

        if type(LootBlare.rollBonuses[roller]) == "table" then
          for item, bonus in pairs(LootBlare.rollBonuses[roller]) do
            --print("[DEBUG]: " .. roller .. " -> " .. item .. " = " .. bonus)
          end
        else
          DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] No bonuses found for " .. roller, 1, 1, 0)
        end
        

        local bonus = 0
        local class = GetClassOfRoller(roller)
        local itemLink = itemRollFrame and itemRollFrame.itemLink
        local msg = message
        if itemLink then 
          --print("[DEBUG] itemLink exists:".. itemLink)
          if not itemRollFrame or not itemRollFrame.itemLink then
            DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] itemRollFrame or itemLink is nil", 1, 1, 0)
          end
          --print("[DEBUG] currentItem:" .. currentItem)
          if maxRoll == tostring(msRollCap) then
            -- Check if the player's name and item name are in the roll bonuses
            if currentItem and LootBlare.rollBonuses[roller] and LootBlare.rollBonuses[roller][currentItem] then
              --print("[DEBUG] Bonus found for roller=" .. tostring(roller) ..
              --", itemName=" .. tostring(currentItem) ..
              --" -> bonus=" .. tostring(rollBonuses[roller] and rollBonuses[roller][currentItem]))
              bonus = tonumber(LootBlare.rollBonuses[roller][currentItem]) or 0
              roll = roll + bonus
              if bonus > 0 then
                local part1, part2 = SplitRollMessage(msg)
                msg = part1 .. " + " .. bonus .. " = " .. roll .. " " .. part2 -- Append bonus to message for display
                msg = tostring(msg) 
              end
            end
          end
        end
        message = { roller = roller, roll = roll, msg = msg, class = class, maxRoll = maxRoll }
        if LootBlare.rollBonuses[roller] and LootBlare.rollBonuses[roller][currentItem] and maxRoll == tostring(srRollCap) then
          table.insert(srRollMessages, message)
        elseif maxRoll == tostring(msRollCap) then
          table.insert(msRollMessages, message)
        elseif maxRoll == tostring(osRollCap) then
          table.insert(osRollMessages, message)
        elseif maxRoll == tostring(tmogRollCap) then
          table.insert(tmogRollMessages, message)
        else
          if tonumber(maxRoll) < 100 then return end
          if tonumber(maxRoll) > msPlusRollCap then return end
          table.insert(msPlusRollMessages, message)
        end
        --print("[DEBUG] Final roll inserted with bonus =" .. tostring(bonus) .. "->" .. tostring(roll))
        --print("[DEBUG] Final message:"  .. msg)
        UpdateTextArea(itemRollFrame)
      end
    end

  elseif event == "CHAT_MSG_RAID_WARNING" and sender == LootBlare.masterLooter then
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
      time_elapsed = 0
      isRolling = true
      ShowFrame(itemRollFrame,FrameShownDuration,links[1])
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    SendAddonMessage(LB_PREFIX, LB_GET_DATA, "RAID") -- fetch ML info
  elseif event == "ADDON_LOADED"then
    if FrameShownDuration == nil then FrameShownDuration = 15 end
    if FrameAutoClose == nil then FrameAutoClose = true end
    if IsSenderMasterLooter(UnitName("player")) then
      SendAddonMessage(LB_PREFIX, LB_SET_ML .. UnitName("player"), "RAID")
      SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. FrameShownDuration, "RAID")
      itemRollFrame:UnregisterEvent("ADDON_LOADED")
    else
      SendAddonMessage(LB_PREFIX, LB_GET_DATA, "RAID")
    end
  elseif event == "CHAT_MSG_ADDON" and arg1 == LB_PREFIX then
    local prefix, message, channel, sender = arg1, arg2, arg3, arg4

    -- Someone is asking for the master looter and his roll time
    if message == LB_GET_DATA and IsSenderMasterLooter(UnitName("player")) then
      LootBlare.masterLooter = UnitName("player")
      SendAddonMessage(LB_PREFIX, LB_SET_ML .. LootBlare.masterLooter, "RAID")
      SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. FrameShownDuration, "RAID")
    end

    -- Someone is setting the master looter
    if string.find(message, LB_SET_ML) then
      local _,_, newML = string.find(message, "ML set to (%S+)")
      LootBlare.masterLooter = newML
      LootBlare:RequestSync()
    end
    -- Someone is setting the roll time
    if string.find(message, LB_SET_ROLL_TIME) then
      local _,_,duration = string.find(message, "Roll time set to (%d+)")
      duration = tonumber(duration)
      if duration and duration ~= FrameShownDuration then
        FrameShownDuration = duration
        lb_print("Roll time set to " .. FrameShownDuration .. " seconds.")
      end
    end
  end
end

itemRollFrame:RegisterEvent("ADDON_LOADED")
itemRollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
itemRollFrame:RegisterEvent("CHAT_MSG_ADDON")
itemRollFrame:RegisterEvent("CHAT_MSG_LOOT")
itemRollFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
itemRollFrame:SetScript("OnEvent", function () HandleChatMessage(event,arg1,arg2) end)

-- Register the slash command
SLASH_LOOTBLARE1 = '/lootblare'
SLASH_LOOTBLARE2 = '/lb'

-- Command handler
SlashCmdList["LOOTBLARE"] = function(msg)
  msg = string.lower(msg)
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
    lb_print("Type /lb import to open import window.")
    lb_print("Type /lb ms to open MS+1 window.")
    lb_print("Type /lb debug to print out the SR+ and MS+1 list.")
  elseif msg == "settings" then
    lb_print("Frame shown duration: " .. FrameShownDuration .. " seconds.")
    lb_print("Auto closing: " .. (FrameAutoClose and "on" or "off"))
    lb_print("Master Looter: " .. (LootBlare.masterLooter or "unknown"))
  elseif msg == "import" then
    if LootBlareImportFrame:IsShown() then
      LootBlareImportFrame:Hide()
    else
      if LootBlareMSPlusFrame:IsShown() then
        LootBlareMSPlusFrame:Hide()
      end
      LootBlareImportFrame:Show()
    end
  elseif string.find(msg, "time") then
    local _,_,newDuration = string.find(msg, "time (%d+)")
    newDuration = tonumber(newDuration)
    if newDuration and newDuration > 0 then
      FrameShownDuration = newDuration
      lb_print("Roll time set to " .. newDuration .. " seconds.")
      if IsSenderMasterLooter(UnitName("player")) then
        SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. newDuration, "RAID")
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
  elseif msg == "debug" then
        -- Check if LootBlare and its rollBonuses exist
    if not LootBlare or not LootBlare.rollBonuses then
      lb_print("[LootBlare] rollBonuses table not initialized")
      return
    end

    -- Loop to inspect and print roll bonuses
    local hasEntries = false
    for player, items in pairs(LootBlare.rollBonuses) do
      if type(items) == "table" then
        for itemID, bonus in pairs(items) do
          hasEntries = true
          DEFAULT_CHAT_FRAME:AddMessage(string.format("[LootBlare] %s -> ItemID: %s, Bonus: %s", player, tostring(itemID), tostring(bonus)), 1, 1, 0)
        end
      end
    end

    if not hasEntries then
      DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] rollBonuses table is empty", 1, 0, 0)
    end

    -- Display LootMaster information if available
    if LootBlare and LootBlare.masterLooter then
      DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] LootMaster: " .. LootBlare.masterLooter, 1, 1, 0)
    end

    -- Display MS+1 information if available
    if LootBlare and LootBlare.msplus then
      for i, member in pairs(LootBlare.msplus) do
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] MS+1 " .. member.name .. " " .. member.points, 1, 1, 0)
      end
    end
  elseif msg == "ms" then
    if LootBlareMSPlusFrame:IsShown() then
      LootBlareMSPlusFrame:Hide()
    else
      if LootBlareImportFrame:IsShown() then
        LootBlareImportFrame:Hide()
      end
      LootBlareMSPlusFrame:Show()
    end
  else
  lb_print("Invalid command. Type /lb help for a list of commands.")
  end
end