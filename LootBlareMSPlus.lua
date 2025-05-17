local f = LootBlareMSPlusFrame
local scrollFrame = LootBlareMsPlusScrollFrame

---------------------------------------------------------------------
--                            UTILITY
---------------------------------------------------------------------

local function CountTable(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function IsPlayerInRaid(name)
    for i = 1, GetNumRaidMembers() do
        local raidName = GetRaidRosterInfo(i)
        if raidName == name then
            return true
        end
    end
    return false
end

-- Function to check if a raid member is online
local function IsRaidMemberOnlineByName(playerName)
    for i = 1, GetNumRaidMembers() do
        local name, _, _, _, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i)
        if name == playerName then
            if UnitIsConnected("raid" .. i) then
                return true
            else
                return false
            end
        end
    end
    return false
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

---------------------------------------------------------------------
--                           MS+1 Frame Creation
---------------------------------------------------------------------

-- Create the scroll child manually
local scrollChild = CreateFrame("Frame", "LootBlareMsPlusScrollChild", scrollFrame)
scrollChild:SetHeight(1)  -- Will be updated dynamically
scrollFrame:SetScrollChild(scrollChild)

-- Set content height dynamically
local rowHeight = 35
local rowSpacing = 32
scrollChild:SetWidth(220)

local createdRows = {}

local function ClearRows()
    for i, row in ipairs(createdRows) do
        row:Hide()
        row:SetParent(nil)
    end
    createdRows = {}
end


-- Create rows dynamically
local function CreateRaidRow(parent, index, name, points)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(220)
    row:SetHeight(35)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, -10 - ((index - 1) * rowSpacing))
    row:SetBackdrop({
        bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
        tile = true,
        tileSize = 16,
        edgeFile = nil,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    if IsPlayerInRaid(name) then
        if IsRaidMemberOnlineByName(name) then
            row:SetBackdropColor(0, 0, 0, 0.7) -- default dark          
        else
            row:SetBackdropColor(1.0, 1.0, 0.0, 0.7) -- yellow
        end

    else
        row:SetBackdropColor(0.6, 0, 0, 0.7) -- red
    end

    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetText(name or "Unknown")
    nameText:SetPoint("LEFT", 10, 0)

    local pointsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pointsText:SetText(points or 0)
    pointsText:SetPoint("LEFT", 140, 0)

    local function ChangePointsByName(name, value)
        for _, member in pairs(LootBlare.msplus) do 
            if member.name == name then
                member.points = (member.points or 0) + value
                if member.points < 0 then member.points = 0 end
                pointsText:SetText(member.points)
            end
        end
    end

    local upButton = CreateFrame("Button", nil, row)
    upButton:SetWidth(20)
    upButton:SetHeight(20)
    upButton:SetNormalTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Up]])
    upButton:SetPushedTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Down]])
    upButton:SetHighlightTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Highlight]])
    upButton:SetPoint("RIGHT", -10, 6)

    local downButton = CreateFrame("Button", nil, row)
    downButton:SetWidth(20)
    downButton:SetHeight(20)
    downButton:SetNormalTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Up]])
    downButton:SetPushedTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Down]])
    downButton:SetHighlightTexture([[Interface\Buttons\UI-ScrollBar-ScrollDownButton-Highlight]])
    downButton:SetPoint("RIGHT", -10, -6)

    upButton:SetScript("OnClick", function()
        if IsSenderMasterLooter(UnitName("player")) == false then
            PlaySoundFile("Sound\\Interface\\Error.wav")
            return 
        end
        ChangePointsByName(name, 1)
        LootBlare:SendMSPointSync()
        PlaySoundFile("Sound\\interface\\iUiInterfaceButtonA.wav")
    end)

    downButton:SetScript("OnClick", function()
        if IsSenderMasterLooter(UnitName("player")) == false then
            PlaySoundFile("Sound\\Interface\\Error.wav")
            return 
        end
        ChangePointsByName(name, -1)
        LootBlare:SendMSPointSync()
        PlaySoundFile("Sound\\interface\\iUiInterfaceButtonA.wav")
    end)

    row:Show()
    scrollChild:Show()

    return row
end

---------------------------------------------------------------------
--                           MS+1 Update
---------------------------------------------------------------------

local entries = CountTable(LootBlare.msplus)
-- Set the total height of the scroll child based on number of rows
scrollChild:SetHeight(entries * rowSpacing + 10)
--scrollChild:SetHeight(500)

local function ClearRows()
    for i, row in ipairs(createdRows) do
        row:Hide()
        row:SetParent(nil)
    end
    createdRows = {}
end

function LootBlare:UpdateScrollFrame()
    ClearRows()

    for i, v in ipairs(LootBlare.msplus) do
        local row = CreateRaidRow(scrollChild, i, v.name, v.points)
        table.insert(createdRows, row)
    end

    local entries = CountTable(LootBlare.msplus)
    scrollChild:SetHeight(entries * rowSpacing + 10)
    scrollChild:Show()
end