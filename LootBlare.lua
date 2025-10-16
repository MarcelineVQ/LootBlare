-- LootBlare: Displays sorted item rolls in a draggable frame
local LB_DEBUG = false

-- Constants
local LB_PREFIX = "LootBlare"
local LB_SET_ROLL_TIME = "Roll time set to "
local BUTTON_WIDTH, BUTTON_COUNT, BUTTON_PADDING = 32, 4, 5
local FONT_NAME, FONT_SIZE, FONT_OUTLINE = "Fonts\\FRIZQT__.TTF", 12, "OUTLINE"

local RAID_CLASS_COLORS = {
  Warrior = "FFC79C6E", Mage = "FF69CCF0", Rogue = "FFFFF569", Druid = "FFFF7D0A",
  Hunter = "FFABD473", Shaman = "FF0070DE", Priest = "FFFFFFFF", Warlock = "FF9482C9", Paladin = "FFF58CBA"
}

local colors = {
  ADDON = "FFEDD8BB", DEFAULT = "FFFFFF00", SR = "ffe5302d", MS = "FFFFFF00",
  OS = "FF00FF00", TM = "FF00FFFF", OTHER = "ffff80be"
}

-- State
local state = {
  rollMessages = {}, rollers = {}, isRolling = false, time_elapsed = 0,
  item_query = 0.5, times = 5, currentItem = nil,
  discover = CreateFrame("GameTooltip", "CustomTooltip1", UIParent, "GameTooltipTemplate"),
  masterLooter = nil, srRollCap = 101, msRollCap = 100, osRollCap = 99, tmogRollCap = 50,
  MLRollDuration = 15, rollDuration = 15,
}

-- Caches
local formatCache, classCache, textBuffer = {}, {}, {}
local cacheSize, MAX_CACHE_SIZE = 0, 100

-- Utility functions
local function lb_print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|c" .. colors.ADDON .. "LootBlare: " .. msg .. "|r")
end

local function PlayerIsML()
  local lootMethod, masterLooterPartyID = GetLootMethod()
  return lootMethod == "master" and masterLooterPartyID and masterLooterPartyID == 0
end

local function GetColoredTextByQuality(text, qualityIndex)
  local _, _, _, hex = GetItemQualityColor(qualityIndex)
  return hex .. text .. "|r"
end

local function ExtractItemLinksFromMessage(message)
  local itemLinks = {}
  for link in string.gfind(message, "|c.-|H(item:.-)|h.-|h|r") do
    table.insert(itemLinks, link)
  end
  return itemLinks
end

local function CheckItem(link)
  state.discover:SetOwner(UIParent, "ANCHOR_PRESERVE")
  state.discover:SetHyperlink(link)
  if discoverTextLeft1 and discoverTooltipTextLeft1:IsVisible() then
    local name = discoverTooltipTextLeft1:GetText()
    discoverTooltip:Hide()
    return name ~= (RETRIEVING_ITEM_INFO or "")
  end
  return false
end

local function resetRolls()
  state.rollMessages, state.rollers = {}, {}
end

local function GetClassOfRoller(rollerName)
  if classCache[rollerName] then return classCache[rollerName] end
  for i = 1, GetNumRaidMembers() do
    local name, _, _, _, class = GetRaidRosterInfo(i)
    if name == rollerName then
      classCache[rollerName] = class
      return class
    end
  end
  return nil
end

-- Roll formatting and sorting
local function sortRolls()
  table.sort(state.rollMessages, function(a, b)
    if a.minRoll == 1 and b.minRoll ~= 1 then return true
    elseif a.minRoll ~= 1 and b.minRoll == 1 then return false end
    if a.maxRoll ~= b.maxRoll then return a.maxRoll > b.maxRoll end
    if a.minRoll ~= b.minRoll then return a.minRoll > b.minRoll end
    return a.roll > b.roll
  end)
end

local function formatMsg(msg)
  local cacheKey = msg.roller .. ":" .. msg.roll .. ":" .. msg.minRoll .. ":" .. msg.maxRoll
  if formatCache[cacheKey] then return formatCache[cacheKey] end

  local classColor = RAID_CLASS_COLORS[msg.class] or "FFFFFFFF"
  local textColor = msg.maxRoll > state.msRollCap and colors.SR
    or msg.maxRoll == state.msRollCap and colors.MS
    or msg.maxRoll == state.osRollCap and colors.OS
    or msg.maxRoll <= state.tmogRollCap and colors.TM
    or colors.DEFAULT

  local c_class = format("|c%s%-12s|r", classColor, msg.roller)
  local max_or_special
  if msg.minRoll == 1 then
    max_or_special = msg.maxRoll == state.srRollCap and " SR"
      or msg.maxRoll == state.msRollCap and " MS"
      or msg.maxRoll == state.osRollCap and " OS"
      or msg.maxRoll == state.tmogRollCap and " TM"
  end

  local c_min = msg.minRoll == 1 and "" or ("|cFFFF0000" .. msg.minRoll .. "|c" .. textColor .. "-")
  local c_end = max_or_special or format("(%s%d)", c_min, msg.maxRoll)
  local result = format("%s|c%s%-3s%s|r", c_class, textColor, msg.roll, c_end)

  if cacheSize < MAX_CACHE_SIZE then
    formatCache[cacheKey] = result
    cacheSize = cacheSize + 1
  end
  return result
end

-- UI creation
local function SetItemInfo(frame, itemLinkArg)
  local itemName, itemLink, itemQuality, _, _, _, _, _, itemIcon = GetItemInfo(itemLinkArg)
  if itemName and itemQuality < 2 and not LB_DEBUG then return false end

  if not itemIcon then
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    frame.name:SetText("Unknown item, attempting to query...")
    return true
  end

  frame.icon:SetTexture(itemIcon)
  frame.iconButton:SetNormalTexture(itemIcon)
  frame.name:SetText(GetColoredTextByQuality(itemName, itemQuality))
  frame.itemLink = itemLink
  return true
end

local function UpdateTextArea(frame)
  if not frame.textArea then
    frame.textArea = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.textArea:SetFont("Interface\\AddOns\\LootBlare\\MonaspaceNeonFrozen-Regular.ttf", 12, "")
    frame.textArea:SetHeight(150)
    frame.textArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -70)
    frame.textArea:SetJustifyH("LEFT")
    frame.textArea:SetJustifyV("TOP")
  end

  sortRolls()
  local count, maxMessages = 0, getn(state.rollMessages)
  local limit = maxMessages > 9 and 9 or maxMessages

  for i = 1, limit do
    count = count + 1
    textBuffer[count] = formatMsg(state.rollMessages[i])
  end
  for i = count + 1, getn(textBuffer) do textBuffer[i] = nil end
  frame.textArea:SetText(table.concat(textBuffer, "\n"))
end

local function CreateItemRollFrame()
  local frame = CreateFrame("Frame", "ItemRollFrame", UIParent)
  frame:SetWidth(165)
  frame:SetHeight(220)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
  })
  frame:SetBackdropColor(0, 0, 0, 1)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() frame:StartMoving() end)
  frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

  -- Close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetWidth(32)
  closeButton:SetHeight(32)
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
  closeButton:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
  closeButton:SetPushedTexture("Interface/Buttons/UI-Panel-MinimizeButton-Down")
  closeButton:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight")
  closeButton:SetScript("OnClick", function() frame:Hide() resetRolls() end)

  -- Roll buttons
  local rollButtons = {
    {text = "SR", tooltip = "Roll for Soft Reserve", cap = state.srRollCap},
    {text = "MS", tooltip = "Roll for Main Spec", cap = state.msRollCap},
    {text = "OS", tooltip = "Roll for Off Spec", cap = state.osRollCap},
    {text = "TM", tooltip = "Roll for Transmog", cap = state.tmogRollCap}
  }

  local panelWidth = frame:GetWidth()
  local spacing = (panelWidth - (BUTTON_COUNT * BUTTON_WIDTH)) / (BUTTON_COUNT + 1)

  for i, btnData in ipairs(rollButtons) do
    local tooltip = btnData.tooltip
    local cap = btnData.cap
    local btn = CreateFrame("Button", nil, frame, UIParent)
    btn:SetWidth(BUTTON_WIDTH)
    btn:SetHeight(BUTTON_WIDTH)
    btn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", i*spacing + (i-1)*BUTTON_WIDTH, BUTTON_PADDING)
    btn:SetText(btnData.text)
    btn:GetFontString():SetFont(FONT_NAME, FONT_SIZE, FONT_OUTLINE)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexture(1, 1, 1, 1)
    bg:SetVertexColor(0.2, 0.2, 0.2, 1)

    btn:SetScript("OnMouseDown", function() bg:SetVertexColor(0.6, 0.6, 0.6, 1) end)
    btn:SetScript("OnMouseUp", function() bg:SetVertexColor(0.4, 0.4, 0.4, 1) end)
    btn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
      bg:SetVertexColor(0.4, 0.4, 0.4, 1)
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() bg:SetVertexColor(0.2, 0.2, 0.2, 1) GameTooltip:Hide() end)
    btn:SetScript("OnClick", function() RandomRoll(1, cap) end)
  end

  -- Item icon and info
  frame.icon = frame:CreateTexture()
  frame.icon:SetWidth(40)
  frame.icon:SetHeight(40)
  frame.icon:SetPoint("TOP", frame, "TOP", 0, -10)

  frame.iconButton = CreateFrame("Button", nil, frame)
  frame.iconButton:SetWidth(40)
  frame.iconButton:SetHeight(40)
  frame.iconButton:SetPoint("TOP", frame, "TOP", 0, -10)

  frame.timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.timerText:SetPoint("CENTER", frame, "TOPLEFT", 30, -32)
  frame.timerText:SetFont(FONT_NAME, 20, FONT_OUTLINE)

  frame.name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.name:SetPoint("TOP", frame.icon, "BOTTOM", 0, -2)
  frame.itemLink = ""

  local tt = CreateFrame("GameTooltip", "CustomTooltip2", UIParent, "GameTooltipTemplate")
  frame.iconButton:SetScript("OnEnter", function()
    tt:SetOwner(frame.iconButton, "ANCHOR_RIGHT")
    tt:SetHyperlink(frame.itemLink or state.currentItem)
    tt:Show()
  end)
  frame.iconButton:SetScript("OnLeave", function() tt:Hide() end)
  frame.iconButton:SetScript("OnClick", function()
    local currentLink = frame.itemLink or state.currentItem
    if IsControlKeyDown() then
      DressUpItemLink(currentLink)
    elseif IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
      local itemName, itemLink, itemQuality = GetItemInfo(currentLink)
      if itemLink then
        ChatFrameEditBox:Insert(ITEM_QUALITY_COLORS[itemQuality].hex.."\124H"..itemLink.."\124h["..itemName.."]\124h"..FONT_COLOR_CODE_CLOSE)
      end
    end
  end)

  frame:Hide()
  return frame
end

local itemRollFrame = CreateItemRollFrame()

-- Frame update handler
itemRollFrame:SetScript("OnUpdate", function()
  local elapsed = arg1
  if not state.isRolling or not elapsed then return end

  state.time_elapsed = state.time_elapsed + elapsed
  state.item_query = state.item_query - elapsed

  local delta = state.rollDuration - state.time_elapsed
  if this.timerText then this.timerText:SetText(format("%.1f", delta > 0 and delta or 0)) end

  if state.time_elapsed >= max(state.rollDuration, FrameShownDuration) then
    this.timerText:SetText("0.0")
    state.time_elapsed = 0
    state.item_query = 1.5
    state.times = 3
    state.rollMessages = {}
    state.isRolling = false
    if FrameAutoClose and not PlayerIsML() then this:Hide() end
    return
  end

  if state.times > 0 and state.item_query < 0 and state.currentItem and not CheckItem(state.currentItem) then
    state.times = state.times - 1
  elseif state.currentItem then
    if not SetItemInfo(this, state.currentItem) then this:Hide() end
    state.times = 5
  end
end)

local function ShowFrame(frame, duration, item)
  state.rollDuration = duration
  state.currentItem = item
  state.isRolling = true
  state.time_elapsed = 0
  SetItemInfo(frame, item)
  frame:Show()
end

-- Event handlers
function itemRollFrame:CHAT_MSG_LOOT(message)
  if not ItemRollFrame:IsVisible() then return end
  local _, _, who = string.find(message, "^(%a+) receive.? loot:")
  if not who then return end

  local links = ExtractItemLinksFromMessage(message)
  if links[1] and not links[2] and this.itemLink == links[1] then
    resetRolls()
    this:Hide()
  end
end

function itemRollFrame:CHAT_MSG_SYSTEM(message)
  if not string.find(message, "loot master") and not (state.isRolling and string.find(message, "rolls")) then
    return
  end

  local _, _, newML = string.find(message, "(.+) is now the loot master")
  if newML then
    itemRollFrame:SendRollTime()
    return
  end

  if state.isRolling and string.find(message, "(%d+)") then
    local _, _, roller, roll, minRoll, maxRoll = string.find(message, "(%S+) rolls (%d+) %((%d+)%-(%d+)%)")
    if roller and roll and (state.rollers[roller] == nil or LB_DEBUG) then
      state.rollers[roller] = 1
      table.insert(state.rollMessages, {
        roller = roller, roll = tonumber(roll), minRoll = tonumber(minRoll),
        maxRoll = tonumber(maxRoll), msg = message, class = GetClassOfRoller(roller)
      })
      UpdateTextArea(itemRollFrame)
    end
  end
end

function itemRollFrame:CHAT_MSG_RAID_WARNING(message)
  if not string.find(message, "|c.-|H") then return end

  local links = ExtractItemLinksFromMessage(message)
  if links[1] and not links[2] then
    if string.find(message, "^No one has nee") or string.find(message, "has been sent to")
      or string.find(message, " received ") then return end
    resetRolls()
    UpdateTextArea(itemRollFrame)
    state.time_elapsed = 0
    state.isRolling = true
    ShowFrame(itemRollFrame, state.MLRollDuration, links[1])
  end
end

function itemRollFrame:SendRollTime()
  if PlayerIsML() then
    local chan = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. FrameShownDuration, chan)
  end
end

function itemRollFrame:CHAT_MSG_ADDON(prefix, message)
  if prefix ~= LB_PREFIX or not string.find(message, LB_SET_ROLL_TIME) then return end

  local _, _, duration = string.find(message, "Roll time set to (%d+)")
  duration = tonumber(duration)
  if duration and duration ~= state.MLRollDuration then
    state.MLRollDuration = duration
    local msg = "Roll time set to " .. state.MLRollDuration .. " seconds by Master Looter."
    if state.MLRollDuration ~= FrameShownDuration then
      msg = msg .. " Your display time is " .. FrameShownDuration .. " seconds."
    end
    lb_print(msg)
  end
end

function itemRollFrame:PARTY_LOOT_METHOD_CHANGED()
  self:SendRollTime()
end

function itemRollFrame:ADDON_LOADED(addon)
  if addon ~= "LootBlare" then return end
  if FrameShownDuration == nil then FrameShownDuration = 15 end
  if FrameAutoClose == nil then FrameAutoClose = true end
  state.MLRollDuration = FrameShownDuration
end

-- Register events
itemRollFrame:RegisterEvent("ADDON_LOADED")
itemRollFrame:RegisterEvent("CHAT_MSG_SYSTEM")
itemRollFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
itemRollFrame:RegisterEvent("CHAT_MSG_ADDON")
itemRollFrame:RegisterEvent("CHAT_MSG_LOOT")
itemRollFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
itemRollFrame:SetScript("OnEvent", function()
  itemRollFrame[event](itemRollFrame, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
end)

-- Slash commands
SLASH_LOOTBLARE1, SLASH_LOOTBLARE2 = '/lootblare', '/lb'
SlashCmdList["LOOTBLARE"] = function(msg)
  msg = string.lower(msg)
  if msg == "help" or msg == "" then
    lb_print("LootBlare " .. GetAddOnMetadata("LootBlare", "Version") .. " displays sorted item rolls.")
    lb_print("Commands: /lb time <seconds> | /lb autoclose on/off | /lb settings")
  elseif msg == "settings" then
    lb_print("Duration: " .. FrameShownDuration .. "s | Auto-close: " .. (FrameAutoClose and "on" or "off"))
  elseif string.find(msg, "time") then
    local _, _, newDuration = string.find(msg, "time (%d+)")
    newDuration = tonumber(newDuration)
    if newDuration and newDuration > 0 then
      FrameShownDuration = newDuration
      lb_print("Roll time set to " .. newDuration .. " seconds.")
      if PlayerIsML() then
        SendAddonMessage(LB_PREFIX, LB_SET_ROLL_TIME .. newDuration, GetNumRaidMembers() > 0 and "RAID" or "PARTY")
      end
    else
      lb_print("Invalid duration. Enter a number > 0.")
    end
  elseif string.find(msg, "autoclose") then
    local _, _, autoClose = string.find(msg, "autoclose (%a+)")
    if autoClose == "on" or autoClose == "true" then
      FrameAutoClose = true
      lb_print("Auto-close enabled.")
    elseif autoClose == "off" or autoClose == "false" then
      FrameAutoClose = false
      lb_print("Auto-close disabled.")
    else
      lb_print("Invalid option. Use 'on' or 'off'.")
    end
  else
    lb_print("Invalid command. Type /lb help for commands.")
  end
end
