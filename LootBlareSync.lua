local previousRaidMembers = {}
local PREFIX = "LootBlareKBSync"

local function GetRaidMemberNames()
    local names = {}
    for i = 1, GetNumRaidMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            names[name] = true
        end
    end
    return names
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

local function SendSyncMessage()
    if IsSenderMasterLooter(UnitName("player")) == false then return end
    --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sending a sync message", 1, 0, 0)
    if not LootBlare.rollBonuses then
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] No rollBonuses to sync", 1, 0, 0)
        return
    end

    -- Send START sync message
    SendAddonMessage(PREFIX, "START", "RAID")
    local maxLength = 220 -- Safety buffer for prefix, names, etc.
    local batchStr = ""
    
    for player, items in pairs(LootBlare.rollBonuses) do
        for itemID, bonus in pairs(items) do
            local entry = player .. ":" .. itemID .. ":" .. bonus
            if batchStr == "" then
                batchStr = entry
            else
                batchStr = batchStr .. ";" .. entry
            end

            -- Check if adding more would exceed safe limit
            if string.len(PREFIX .. "DATA " .. batchStr) >= maxLength then
                SendAddonMessage(PREFIX, "DATA " .. batchStr, "RAID")
                batchStr = ""
            end
        end
    end

    -- Send remaining batch
    if batchStr ~= "" then
        SendAddonMessage(PREFIX, "DATA " .. batchStr, "RAID")
    end

    -- End signal
    SendAddonMessage(PREFIX, "END", "RAID")
end

-- Sync with entire raid group
function LootBlare:SyncRaid()
    if IsSenderMasterLooter(UnitName("player")) == false then return end
    DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] ML Syncing with raid.")
    local currentRaidMembers = GetRaidMemberNames()
    for name in pairs(currentRaidMembers) do
        if name ~= UnitName("player") then
            SendSyncMessage()
        end
    end
    SendAddonMessage(PREFIX, "ML "..UnitName("player"), "RAID")
    previousRaidMembers = currentRaidMembers
end

local function OnRaidUpdate()
    local someoneJoinedOrLeft = false
    local currentRaidMembers = GetRaidMemberNames()

    -- Check for new members
    for name in pairs(currentRaidMembers) do
        if not previousRaidMembers[name] then
            --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Raid member joined: " .. name, 0, 1, 0)
            SendSyncMessage()
            someoneJoinedOrLeft = true
        end
    end

    -- Check for members who left
    for name in pairs(previousRaidMembers) do
        if not currentRaidMembers[name] then
            --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Raid member left: " .. name, 1, 0, 0)
            someoneJoinedOrLeft = true
        end
    end

    -- Update the stored list
    if someoneJoinedOrLeft then
        previousRaidMembers = currentRaidMembers
    end
end



local function HandleInboundSync(msg, author)
        --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Message Received "..msg, 0, 1, 0)
    if string.find(msg, "^START") then
        LootBlare.rollBonuses = {}
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Full sync started by " .. author .. ", cleared all bonuses", 1, 1, 0)   
    elseif string.find(msg, "^DATA ") then
        local dataPart = string.sub(msg, string.len("DATA ") + 1)

        -- Split by ;
        local pos = 1
        while true do
            local sepStart, sepEnd = string.find(dataPart, ";", pos)
            local entry
            if sepStart then
                entry = string.sub(dataPart, pos, sepStart - 1)
                pos = sepEnd + 1
            else
                entry = string.sub(dataPart, pos)
                pos = nil
            end

            -- Parse entry: player:itemID:bonus
            local _, _, player, itemID, bonus = string.find(entry, "^([^:]+):([^:]+):([^:]+)$")
            if player and itemID and bonus then
                LootBlare.rollBonuses[player] = LootBlare.rollBonuses[player] or {}
                LootBlare.rollBonuses[player][itemID] = tonumber(bonus)
                --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Synced: " .. player .. " | ItemID: " .. itemID .. " | Bonus: " .. bonus, 0, 1, 0)
            end

            if not pos then break end
        end
    elseif string.find(msg, "^END") then
        --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sync finished from " .. author, 0, 1, 0)
    elseif string.find(msg, "^REQ_SYNC") then
        LootBlare.SyncRaid()
    elseif string.find(msg, "^ML") then
        LootBlare.masterLooter = string.sub(msg, string.len("ML ") + 1)
    else
        -- Unknown sync message
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Unknown sync message: " .. msg, 1, 1, 0)
    end
end

local function RequestSync()
    if IsSenderMasterLooter(UnitName("player")) then 
        LootBlare.masterLooter = UnitName("player")
        return
    end
    SendAddonMessage(PREFIX, "REQ_SYNC", "RAID")
    DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sending a Sync Request.", 1, 1, 0)
end

-- Add this function to update the master looter and detect "returning" players
local function DetectReturns()
    if IsSenderMasterLooter(UnitName("player")) == false then return end
    DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] ML detecting Returns.")
    local currentRaidMembers = {}
    for i = 1, GetNumRaidMembers() do
        local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
        if name and online then
            currentRaidMembers[name] = true
            -- Detect if player was not present before
            if not previousRaidMembers[name] and name ~= UnitName("player") then
                --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Detected returning player: " .. name, 0, 1, 0)
                LootBlare:SyncRaid()
            end
        end
    end

    -- Update previousRaidMembers for next check
    previousRaidMembers = currentRaidMembers
end


local function TryRequestSync()
    if GetNumRaidMembers() > 0 then
        RequestSync()
    
        return true
    end
    return false
end

local delayFrame = CreateFrame("Frame")
delayFrame:SetScript("OnUpdate", function()
    if TryRequestSync() then
        delayFrame:SetScript("OnUpdate", nil)
    end
end)




-- Frame to handle RAID_ROSTER_UPDATE and CHAT_MSG_WHISPER
local frame = CreateFrame("Frame")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        delayFrame:Show()
    elseif event == "RAID_ROSTER_UPDATE" then
        DetectReturns()
        OnRaidUpdate()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
        if prefix == PREFIX then
            HandleInboundSync(msg, sender)
        end
    end
end)
