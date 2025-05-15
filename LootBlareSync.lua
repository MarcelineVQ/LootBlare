local previousRaidMembers = {}
local PREFIX = "LootBlareKBSync"
local playerName = UnitName("player") or ""

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

local function SendSyncMessage(target)
    if target == playerName then return end
    if not LootBlare.masterLooter then return end
    if tostring(playerName) ~= tostring(LootBlare.masterLooter) then return end

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
    local currentRaidMembers = GetRaidMemberNames()

    for name in pairs(currentRaidMembers) do
        SendSyncMessage(name)
    end

    previousRaidMembers = currentRaidMembers
end

local function OnRaidUpdate()
    local someoneJoinedOrLeft = false
    local currentRaidMembers = GetRaidMemberNames()

    -- Check for new members
    for name in pairs(currentRaidMembers) do
        if not previousRaidMembers[name] then
            --DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Raid member joined: " .. name, 0, 1, 0)
            SendSyncMessage(name)
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
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sync finished from " .. author, 0, 1, 0)
    else
        -- Unknown sync message
        DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Unknown sync message: " .. msg, 1, 1, 0)
    end
end

-- Add this function to update the master looter and detect "returning" players
local function DetectReturns()
    local currentRaidMembers = {}
    local hasReturningPlayer = false

    for i = 1, GetNumRaidMembers() do
        local name = select(1, GetRaidRosterInfo(i))
        if name then
            currentRaidMembers[name] = true

            -- Detect if player was missing previously, now back online
            if previousRaidMembers and not previousRaidMembers[name] and name ~= playerName then
                hasReturningPlayer = true
            end
        end
    end

    -- Update previousRaidMembers for next check
    previousRaidMembers = currentRaidMembers

    -- If there is at least one returning player, master looter sends sync to RAID (not individually)
    if hasReturningPlayer then
        if LootBlare.masterLooter and playerName == LootBlare.masterLooter then
            -- Send sync to all raid members
            LootBlare:SyncRaid()
            DEFAULT_CHAT_FRAME:AddMessage("[LootBlare] Sync sent to raid due to returning player(s)")
        end
    end
end



-- Frame to handle RAID_ROSTER_UPDATE and CHAT_MSG_WHISPER
local frame = CreateFrame("Frame")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Reset previousRaidMembers on login
        previousRaidMembers = {}
        DetectReturns()
    elseif event == "RAID_ROSTER_UPDATE" then
        DetectReturns()
        OnRaidUpdate()
        -- You can still keep your OnRaidUpdate if needed for other logic
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
        if prefix == PREFIX then
            HandleInboundSync(msg, sender)
        end
    end
end)