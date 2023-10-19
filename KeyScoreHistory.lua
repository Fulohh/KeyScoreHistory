-- KeyScoreHistory.lua
KeyScoreHistory = {}
KeyScoreHistoryData = {
    players = {},
}

local locked = true
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHALLENGE_MODE_START" then
        print("KeyScoreHistory - Donjon commencé")
        KeyScoreHistory:OnDungeonStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        print("Donjon terminé !")
        local mapID, level, time, onTime, keystoneUpgradeLevels = C_ChallengeMode.GetCompletionInfo()
        KeyScoreHistory:OnDungeonEnd(onTime)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            KeyScoreHistory:OnPlayerLogin()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        KeyScoreHistory:CheckForLeavers()
    end
end)

function KeyScoreHistory:OnPlayerLogin()
    -- Initialisation de la base de données si elle n'existe pas
    if not KeyScoreHistoryDB then
        KeyScoreHistoryDB = KeyScoreHistoryData
    else
        KeyScoreHistoryData = KeyScoreHistoryDB
    end
end

function KeyScoreHistory:OnDungeonStart()
    -- Enregistrement des joueurs présents dans le groupe
    local groupMembers = GetHomePartyInfo()
    for i, playerName in ipairs(groupMembers) do
        if not KeyScoreHistoryData.players[playerName] then
            KeyScoreHistoryData.players[playerName] = 0
        end
    end
    self.currentGroup = groupMembers
    self.penaltyApplied = false
    locked = false
end

function KeyScoreHistory:CheckForLeavers()
    if locked then
        return
    end
    if self.currentGroup then
        local currentMembers = GetHomePartyInfo()
        for i, playerName in ipairs(self.currentGroup) do
            if not tContains(currentMembers, playerName) and not self.penaltyApplied then
                -- Un joueur a quitté le groupe, lui retirer un point à tous
                for _, memberName in ipairs(self.currentGroup) do
                    print("KeyScoreHistory -1 point à " .. memberName)
                    KeyScoreHistoryData.players[memberName] = KeyScoreHistoryData.players[memberName] - 1
                end
                self.penaltyApplied = true
                locked = true
                break
            end
        end
    end
end

function KeyScoreHistory:OnDungeonEnd(onTime)
    -- Si le donjon est terminé dans les temps, ajouter un point. Sinon, retirer un point.
    if locked then
        return
    end
    local pointChange = onTime and 1 or -1
    print("KeyScoreHistory " .. pointChange .. " point(s) à tous les joueurs")
    print(onTime)
    for i, playerName in ipairs(self.currentGroup) do
        KeyScoreHistoryData.players[playerName] = KeyScoreHistoryData.players[playerName] + pointChange
    end
    locked = true
end

-- Ajout des commandes Slash
SLASH_KEYSCOREHISTORY1 = "/keyscorehistory"
SLASH_KEYSCOREHISTORY2 = "/ksh"
SlashCmdList["KEYSCOREHISTORY"] = function(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    if command == "list" then
        print("KeyScoreHistory - List of players:")
        for playerName, score in pairs(KeyScoreHistoryData.players) do
            print(playerName .. ": " .. score)
        end
    elseif command == "remove_point" then
        local name, server = UnitName("target")
        if not server then
            server = GetRealmName() -- si 'server' est nil, le joueur est du même serveur que vous
        end
        local targetName = name .. "-" .. server

        if not KeyScoreHistoryData.players[targetName] then
            KeyScoreHistoryData.players[targetName] = 0
        end
        KeyScoreHistoryData.players[targetName] = KeyScoreHistoryData.players[targetName] - 1
        print("KeyScoreHistory - Removed 1 point to " .. targetName)
    elseif command == "add_point" then
        local name, server = UnitName("target")
        if not server then
            server = GetRealmName() -- si 'server' est nil, le joueur est du même serveur que vous
        end
        local targetName = name .. "-" .. server

        if not KeyScoreHistoryData.players[targetName] then
            KeyScoreHistoryData.players[targetName] = 0
        end
        KeyScoreHistoryData.players[targetName] = KeyScoreHistoryData.players[targetName] + 1
        print("KeyScoreHistory - Added 1 point to " .. targetName)
    elseif command == "reset" then
        KeyScoreHistoryData.players = {}
        print("KeyScoreHistory - Database reset.")
    elseif command == "test" then
        local fakeName = "FakePlayer" .. random(1, 100)
        KeyScoreHistoryData.players[fakeName] = random(-10, 10)
        print("KeyScoreHistory - Added " .. fakeName .. " with score " .. KeyScoreHistoryData.players[fakeName])
    end
end

local function OnTooltipSetItem(tooltip, data)
    if tooltip == GameTooltip then
        local name = data.lines[1].leftText
        if KeyScoreHistoryData.players[name] then
            if KeyScoreHistoryData.players[name] > 0 then
                GameTooltip:AddLine("KeyScoreHistory : " .. KeyScoreHistoryData.players[name], 0, 1, 0)
            else
                GameTooltip:AddLine("KeyScoreHistory : " .. KeyScoreHistoryData.players[name], 1, 0, 0)
            end
        else
            GameTooltip:AddLine("KeyScoreHistory : 0", 1, 1, 0)
        end
    end
end


TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnTooltipSetItem)

hooksecurefunc('LFGListApplicantMember_OnEnter', function(self)
    local applicantID = self:GetParent().applicantID;
    local memberIdx = self.memberIdx;

    local activeEntryInfo = C_LFGList.GetActiveEntryInfo();
    if (not activeEntryInfo) then
        return;
    end
    local activityInfo = C_LFGList.GetActivityInfoTable(activeEntryInfo.activityID);
    if (not activityInfo) then
        return;
    end

    local applicantInfo = C_LFGList.GetApplicantInfo(applicantID);
    local name, class, localizedClass, level, itemLevel, honorLevel, tank, healer, damage, assignedRole, relationship, dungeonScore, pvpItemLevel, factionGroup, raceID =
        C_LFGList.GetApplicantMemberInfo(applicantID, memberIdx);

    if KeyScoreHistoryData.players[name] then
        if KeyScoreHistoryData.players[name] > 0 then
            GameTooltip:AddLine("KeyScoreHistory : " .. KeyScoreHistoryData.players[name], 0, 1, 0)
        else
            GameTooltip:AddLine("KeyScoreHistory : " .. KeyScoreHistoryData.players[name], 1, 0, 0)
        end
    else
        GameTooltip:AddLine("KeyScoreHistory : 0", 1, 1, 0)
    end
end)
