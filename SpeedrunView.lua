local SpeedrunView = {}

-- Timer variables
local speedrunTimer = nil
local startTime = nil
local speedrunFrame = nil
local speedrunRows = {}

-- Function to start the speedrun timer
local function StartSpeedrunTimer()
    startTime = GetTime()
    speedrunTimer = 0
    C_Timer.NewTicker(1, function()
        speedrunTimer = GetTime() - startTime
        if speedrunFrame and speedrunFrame.timerText then
            speedrunFrame.timerText:SetText(FormatTime(speedrunTimer))
        end
    end)
end

-- Function to create the speedrun UI
function SpeedrunView.CreateSpeedrunUI(raidTable, sortedBossIDs)
    -- Remove the existing frame if it exists
    if _G["SpeedrunFrame"] then
        _G["SpeedrunFrame"]:Hide()
        _G["SpeedrunFrame"] = nil
    end

    -- Create the main frame
    local frame = CreateFrame("Frame", "SpeedrunFrame", UIParent)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetSize(500, 300)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Create the timer text
    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timerText:SetPoint("TOP", frame, "TOP", 0, -10)
    timerText:SetText("00:00")
    frame.timerText = timerText

    -- Create the boss rows
    local rowHeight = 20
    for i, rankingDataBossID in ipairs(sortedBossIDs) do
        local bossData = raidTable[rankingDataBossID]
        local row = CreateFrame("Frame", nil, frame)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40 - (rowHeight * i))
        row:SetSize(480, rowHeight)

        local bossName = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bossName:SetPoint("LEFT", row, "LEFT", 10, 0)
        bossName:SetText(bossData.bossName or "N/A")

        local bossTime = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bossTime:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        bossTime:SetText("-")

        speedrunRows[rankingDataBossID] = { row = row, timeText = bossTime }
    end

    -- Create the close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    -- Show the frame
    frame:Show()
    speedrunFrame = frame
end

-- Function to update the speedrun UI when a boss is killed
function SpeedrunView.UpdateBossTime(rankingDataBossID, duration)
    if speedrunRows[rankingDataBossID] then
        local row = speedrunRows[rankingDataBossID]
        row.timeText:SetText(FormatTime(duration))

        -- Conditional formatting based on the fastest kill in the guild
        local guildTime = GetGuildTime(rankingDataBossID)
        if guildTime then
            if duration < guildTime then
                row.row:SetBackdropColor(0, 1, 0, 0.3) -- Green for faster
            else
                row.row:SetBackdropColor(1, 0, 0, 0.3) -- Red for slower
            end
        end
    end
end

-- Function to start the speedrun
function SpeedrunView.StartSpeedrun()
    StartSpeedrunTimer()
    SpeedrunView.CreateSpeedrunUI(raidTable, sortedBossIDs)
end

-- Register events for speedrun
local speedrunEventFrame = CreateFrame("Frame")
speedrunEventFrame:RegisterEvent("ENCOUNTER_START")
speedrunEventFrame:RegisterEvent("ENCOUNTER_END")
speedrunEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        if not startTime then
            StartSpeedrunTimer()
        end
    elseif event == "ENCOUNTER_END" then
        local _, _, encounterID, _, _, success = ...
        if success == 1 then
            local rankingDataBossID = GetRankingDataBossID(encounterID)
            local duration = GetTime() - startTime
            SpeedrunView.UpdateBossTime(rankingDataBossID, duration)
        end
    end
end)

-- Slash command to start the speedrun
SLASH_SPEEDRUN1 = "/speedrun"
SlashCmdList["SPEEDRUN"] = function()
    SpeedrunView.StartSpeedrun()
end

return SpeedrunView
