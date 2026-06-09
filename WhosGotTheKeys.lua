local ADDON = "WhosGotTheKeys"
local _, ns = ...
local LibEditMode = ns.LibEditMode
local LSM = LibStub("LibSharedMedia-3.0")
local LKS = LibStub("LibKeystone")

local frame = CreateFrame("Frame", ADDON .. "Frame", UIParent)
frame:SetSize(300, 100)
frame:SetFrameStrata("MEDIUM")
frame:SetFixedFrameStrata(true)
frame:SetFrameLevel(9400)
frame:SetFixedFrameLevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(false)
frame:SetMovable(false)
frame:Hide()

local header = frame:CreateFontString(nil, "OVERLAY")
header:SetPoint("TOP", 0, -6)
header:SetJustifyH("CENTER")
header:SetFont(DEFAULT_FONT, 16, "OUTLINE")
header:SetText("Who's got the keys?")
header:SetTextColor(1, 0.82, 0, 1)

local playerLines = {}
for i = 1, 5 do
    local line = frame:CreateFontString(nil, "OVERLAY")
    line:SetPoint("TOP", i == 1 and header or playerLines[i - 1], "BOTTOM", 0, -4)
    line:SetJustifyH("CENTER")
    line:SetFont(DEFAULT_FONT, 14, "OUTLINE")
    line:SetTextColor(1, 1, 1, 1)
    line:SetText("")
    playerLines[i] = line
end

local DEFAULT_FONT = GameFontNormal:GetFont()

local function GetFontValues()
    local values = {}
    for _, name in ipairs(LSM:List("font")) do
        values[#values + 1] = { text = name, value = LSM:Fetch("font", name) }
    end
    return values
end

local defaultPosition = {
    point = "TOP",
    x = 0,
    y = -20,
}

local currentInstanceID = nil
local partyKeys = {}

local function UpdateDisplay()
    local sorted = {}
    for playerName, data in pairs(partyKeys) do
        if UnitInParty(playerName) or playerName == UnitNameUnmodified("player") then
            local keyLevel, challengeMapID = data[1], data[2]
            if challengeMapID > 0 then
                local _, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(challengeMapID)
                local isCurrentDungeon = mapID == currentInstanceID
                if isCurrentDungeon and keyLevel > 0 then
                    local _, classFile = UnitClass(playerName)
                    local color = classFile and C_ClassColor.GetClassColor(classFile):GenerateHexColor() or "FFFFFFFF"
                    local shortName = playerName:gsub("%-.+", "*")
                    sorted[#sorted + 1] = {
                        name = string.format("|c%s%s|r +%d", color, shortName, keyLevel),
                        level = keyLevel,
                        playerName = playerName,
                    }
                end
            end
        end
    end

    table.sort(sorted, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.playerName < b.playerName
    end)

    for i = 1, 5 do
        if sorted[i] then
            playerLines[i]:SetText(sorted[i].name)
            playerLines[i]:Show()
        else
            playerLines[i]:SetText("")
            playerLines[i]:Hide()
        end
    end

    local height = 30
    for i = 1, 5 do
        if sorted[i] then
            height = height + 20
        end
    end
    frame:SetHeight(height)

    if #sorted > 0 then
        frame:Show()
    else
        frame:Hide()
    end
end

local function GetDB(layoutName)
    if not WhosGotTheKeysDB then WhosGotTheKeysDB = {} end
    if not WhosGotTheKeysDB[layoutName] then
        WhosGotTheKeysDB[layoutName] = {
            point = defaultPosition.point,
            x = defaultPosition.x,
            y = defaultPosition.y,
            font = DEFAULT_FONT,
        }
    end
    return WhosGotTheKeysDB[layoutName]
end

local function ApplyFont(fontPath)
    header:SetFont(fontPath, 16, "OUTLINE")
    for i = 1, 5 do
        playerLines[i]:SetFont(fontPath, 14, "OUTLINE")
    end
end

local function onPositionChanged(_, layoutName, point, x, y)
    local db = GetDB(layoutName)
    db.point = point
    db.x = x
    db.y = y
end

LibEditMode:RegisterCallback('enter', function()
    header:SetText("Who's got the keys?")
    playerLines[1]:SetText("|cFFF58CBAPaladin|r +15")
    playerLines[2]:SetText("|cFFABD473Hunter|r +12")
    playerLines[3]:SetText("|cFFC79C6EWarrior|r +10")
    for i = 1, 3 do
        playerLines[i]:Show()
    end
    for i = 4, 5 do
        playerLines[i]:SetText("")
        playerLines[i]:Hide()
    end
    frame:SetHeight(90)
    frame:Show()
end)

LibEditMode:RegisterCallback('exit', function()
    UpdateDisplay()
end)

LibEditMode:RegisterCallback('layout', function(layoutName)
    local db = GetDB(layoutName)
    frame:ClearAllPoints()
    frame:SetPoint(db.point, db.x, db.y)
    ApplyFont(db.font)
end)

LibEditMode:AddFrame(frame, onPositionChanged, defaultPosition, "Who's Got The Keys")

LibEditMode:AddFrameSettings(frame, {
    {
        name = 'Font',
        kind = LibEditMode.SettingType.Dropdown,
        default = DEFAULT_FONT,
        get = function(layoutName)
            return GetDB(layoutName).font
        end,
        set = function(layoutName, value)
            GetDB(layoutName).font = value
            ApplyFont(value)
        end,
        values = GetFontValues,
        height = 300,
    },
})

local addon = {}
LKS.Register(addon, function(keyLevel, challengeMapID, rating, playerName, channel)
    if channel ~= "PARTY" then return end
    partyKeys[playerName] = { keyLevel, challengeMapID, rating }
    UpdateDisplay()
end)

local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
        self:UnregisterEvent("ENCOUNTER_START")
        self:UnregisterEvent("PLAYER_LEAVING_WORLD")
        self:UnregisterEvent("UNIT_CONNECTION")

        partyKeys = {}

        C_Timer.After(0, function()
            local _, _, diffID, _, _, _, _, instanceID = GetInstanceInfo()
            if diffID == 23 then
                currentInstanceID = instanceID
                self:RegisterEvent("CHALLENGE_MODE_START")
                self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
                self:RegisterEvent("PLAYER_LEAVING_WORLD")
                self:RegisterEvent("ENCOUNTER_START")
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:RegisterEvent("UNIT_CONNECTION")
                LKS.Request("PARTY")
            else
                currentInstanceID = nil
                frame:Hide()
            end
        end)
    elseif event == "CHALLENGE_MODE_START" then
        self:UnregisterEvent("CHALLENGE_MODE_START")
        self:UnregisterEvent("ENCOUNTER_START")
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        self:UnregisterEvent("UNIT_CONNECTION")
        frame:Hide()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        C_Timer.After(5, function()
            local _, _, diffID, _, _, _, _, instanceID = GetInstanceInfo()
            if diffID == 8 then
                currentInstanceID = instanceID
                partyKeys = {}
                LKS.Request("PARTY")
                self:RegisterEvent("ENCOUNTER_START")
                self:RegisterEvent("PLAYER_REGEN_DISABLED")
                self:RegisterEvent("UNIT_CONNECTION")
            end
        end)
    elseif event == "ENCOUNTER_START" then
        frame:Hide()
    elseif event == "PLAYER_LEAVING_WORLD" then
        self:UnregisterEvent("CHALLENGE_MODE_START")
        self:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
        self:UnregisterEvent("ENCOUNTER_START")
        self:UnregisterEvent("PLAYER_LEAVING_WORLD")
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self:UnregisterEvent("UNIT_CONNECTION")
        frame:Hide()
    elseif event == "PLAYER_REGEN_DISABLED" then
        frame:Hide()
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        C_Timer.After(10, function()
            if currentInstanceID then
                UpdateDisplay()
            end
        end)
    elseif event == "UNIT_CONNECTION" then
        local unitTarget, isConnected = ...
        if isConnected and UnitInParty(unitTarget) then
            C_Timer.After(1, function() LKS.Request("PARTY") end)
        end
    end
end

frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
