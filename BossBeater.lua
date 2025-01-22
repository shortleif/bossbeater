local BossBeater, Addon = ...
Addon = Addon or {}

-- Create empty global tables
local raidTable
local sortedBossIDs

-- Access the ranking_data and the boss_lookup table
local rankingData = Addon.ranking_data
local bossLookup = Addon.boss_lookup

-- Function to transform rankingDataBossID to dataBossID
local function GetBossID(rankingDataBossID)
  return string.match(rankingDataBossID, "b_(%d+)")
end

-- Function to transform dataBossID to rankingDataBossID
local function GetRankingDataBossID(dataBossID)
  return "b_" .. dataBossID
end

local function GetConcedeTime(rankingDataBossID)
  for _, data in ipairs(rankingData) do
    if data.g == "Concede" and data.t[rankingDataBossID] then
      return data.t[rankingDataBossID]  -- Return Concede's time for the boss
    end
  end
  return nil  -- Return nil if Concede's time is not found
end

local function SaveWrapperPosition(frame)
  local centerX, centerY = frame:GetCenter()
  Addon.BossBeaterDB.frameX = centerX
  Addon.BossBeaterDB.frameY = centerY
end

local function FormatTime(seconds)
  local minutes = floor(seconds / 60)
  local remainingSeconds = seconds % 60  -- Use modulo operator to get remaining seconds
  return string.format("%d:%02d", minutes, remainingSeconds)
end


local function CreateRaidTable()
  -- Ensure rankingData and bossLookup are available  
  if not rankingData or not bossLookup then
    print("Error: Ranking data or boss lookup table is not available.")
    return nil, nil  -- Return nil for both values to indicate an error
  end

  -- Create a table to store the raid data
  local raidTable = {}

  -- Lets find the bossIDs dynamically instead something like this
  local bossIDs = {} 
  for _, data in ipairs(rankingData) do
    for bossID, _ in pairs(data.t) do
      if not tContains(bossIDs, bossID) then
        table.insert(bossIDs, bossID)
      end
    end
  end

  -- Initialize the raidTable with default values
  for _, bossID in ipairs(bossIDs) do
    local dataBossID = GetBossID(bossID)
    if bossLookup[dataBossID] then
      local bossName = bossLookup[dataBossID].Name_lang
      raidTable[bossID] = {
        bossName = bossName,
        worldRecord = math.huge,
        guildRecord = "N/A",
        rank = "N/A",
        serverRecord = math.huge,
        serverRank = "N/A",
        time = "-",
        duration = "-",
        newRecord = "-",
      }
    end
  end

  -- Populate the raidTable with "live data" if available
  if BossBeaterDB and BossBeaterDB.liveData then
    for bossID, liveData in pairs(BossBeaterDB.liveData) do
        if raidTable[bossID] then
            raidTable[bossID].time = liveData.time
            raidTable[bossID].difference = liveData.difference
            raidTable[bossID].newRank = liveData.newRank
        end
    end
end


  -- Populate raidTable with data from the current session (killTimes)

  if killTimes then
    for _, killData in ipairs(killTimes) do
      local bossID = killData.rankingDataBossID
      if raidTable[bossID] then
          raidTable[bossID].time = FormatTime(killData.duration)
          raidTable[bossID].difference = FormatTime(killData.difference)
          raidTable[bossID].newRank = killData.newWorldRank .. " / " .. killData.newServerRank
      end
    end
  end

  -- Populate world records
  for _, bossID in ipairs(bossIDs) do
    for _, data in ipairs(rankingData) do
        if data.t[bossID] then
            local time = tonumber(data.t[bossID]) -- Convert to number
            if not raidTable[bossID].worldRecord or time < raidTable[bossID].worldRecord then
                raidTable[bossID].worldRecord = time -- Store raw time
                -- print("Boss:", bossID, "Time:", time, "Current WR:", raidTable[bossID].worldRecord)
            end
        end
    end
end

  -- Populate server records
  for _, bossID in ipairs(bossIDs) do
    for _, data in ipairs(rankingData) do
        if data.t[bossID] and data.s == "living flame" and data.r == "eu" then
            local time = tonumber(data.t[bossID]) -- Convert to number
            if not raidTable[bossID].serverRecord or time < raidTable[bossID].serverRecord then
                raidTable[bossID].serverRecord = time -- Store raw time
            end
        end
    end
end

  -- Populate guild records
  for _, data in ipairs(rankingData) do
    for _, bossID in ipairs(bossIDs) do
      if data.t[bossID] and data.g == "Concede" then
        local time = data.t[bossID]
        if not raidTable[bossID].guildRecord or time < raidTable[bossID].guildRecord then
          raidTable[bossID].guildRecord = time-- Format the time here
        end
      end
    end
  end

  -- Calculate and update ranks
  for _, data in ipairs(rankingData) do
    for _, bossID in ipairs(bossIDs) do
      if data.t[bossID] and data.g == "Concede" then
        local time = data.t[bossID]
        local worldRank = 1
        local serverRank = 1

        for _, otherData in ipairs(rankingData) do
          if otherData.t[bossID] then
            if otherData.t[bossID] < time then
              worldRank = worldRank + 1
            end
            if otherData.s == data.s and otherData.r == data.r and otherData.t[bossID] < time then
              serverRank = serverRank + 1
            end
          end
        end

        raidTable[bossID].rank = worldRank .. " / " .. serverRank
      end
    end
  end

  -- Create a sorted list of boss IDs
  local sortedBossIDs = {}
  for bossID, _ in pairs(raidTable) do
    table.insert(sortedBossIDs, bossID)
  end

  table.sort(sortedBossIDs, function(a, b)
    return tonumber(a:match("%d+")) < tonumber(b:match("%d+"))
  end)

  -- Print the entire contents of the raidTable
 --[[print("raidTable:")
  for k, v in pairs(raidTable) do
    print(k, "{")
    for innerK, innerV in pairs(v) do
      print("  ", innerK, innerV)
    end
    print("}")
  end ]]--

  return raidTable, sortedBossIDs
end


local function CreateRaidTableUI(raidTable, sortedBossIDs)
    -- Check if the frame already exists
  local frame = _G["BossBeaterRaidTable"]

  local textOffsets = { 10, 140, 200, 260, 315, 390, 440, 490 }  -- Offsets for each header

  if not frame or (frame and not frame:IsShown()) then
    -- Create the main frame (only if it doesn't exist)
    frame = CreateFrame("Frame", "BossBeaterRaidTable", UIParent)
    frame:SetSize(550, 300) -- Adjust size as needed

    if Addon.BossBeaterDB.frameX and Addon.BossBeaterDB.frameY then
      local adjustedX = Addon.BossBeaterDB.frameX - (frame:GetWidth() / 2)
      frame:SetPoint("LEFT", UIParent, "BOTTOMLEFT", adjustedX, Addon.BossBeaterDB.frameY) -- Use the same anchor points
    else
      frame:SetPoint("CENTER", UIParent, "CENTER", 700, 400) -- Default position
    end

    -- Make the frame draggable
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Create the background texture
    local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints(frame)
    bgTexture:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Create the table header
    local header = CreateFrame("Frame", nil, frame)
    local contentOffset = 25
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10 - contentOffset) -- Apply contentOffset here
    header:SetSize(550, 20) -- Adjust size as needed

    local headers = { "Boss Name", "World", "Server", "Guild", "Rank (W/S)", "Time" , "Diff" , "Rank?" }
    
    for i, text in ipairs(headers) do
      local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      headerText:SetPoint("LEFT", header, "LEFT", textOffsets[i], 0)
      headerText:SetText(text)
    end

    -- Initialize the content frame and rows
    frame.contentFrame = CreateFrame("Frame", nil, frame)
    frame.contentFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    frame.contentFrame:SetSize(550, 300)
    frame.contentFrame.rows = {}
  end

  -- Create rows
  local rowHeight = 20
  for i, rankingDataBossID in ipairs(sortedBossIDs) do
    local bossData = raidTable[rankingDataBossID]
    local row = CreateFrame("Frame", nil, frame.contentFrame)
    row:SetPoint("TOPLEFT", frame.contentFrame, "TOPLEFT", 0, -rowHeight * i + 15) -- Adjust for header height
    row:SetSize(550, rowHeight)

    -- Create cells with data from raidTable
    local cell1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell1:SetPoint("LEFT", row, "LEFT", 10, 0)
    cell1:SetText(bossData.bossName or "N/A")

    local cell2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell2:SetPoint("LEFT", row, "LEFT", 140, 0)
    cell2:SetText(FormatTime(bossData.worldRecord) or "N/A")

    local cell3 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell3:SetPoint("LEFT", row, "LEFT", 200, 0)
    cell3:SetText(FormatTime(bossData.serverRecord) or "N/A")

    local cell4 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell4:SetPoint("LEFT", row, "LEFT", 260, 0)
    cell4:SetText(FormatTime(bossData.guildRecord) or "N/A")

    local cell5 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell5:SetPoint("LEFT", row, "LEFT", 315, 0)
    cell5:SetText(bossData.rank or "N/A")

    local cell6 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell6:SetPoint("LEFT", row, "LEFT", 390, 0)
    if bossData.time == "-" then
      cell6:SetText("-")
    else
      cell6:SetText(FormatTime(bossData.time) or "-")
    end

    local cell7 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell7:SetPoint("LEFT", row, "LEFT", 440, 0)
    if bossData.difference == "-" then
      cell7:SetText("-")
    elseif bossData.difference and bossData.difference < 0 then
      local reversedDifference = bossData.difference * -1
      cell7:SetText("-" .. FormatTime(reversedDifference) or "-")
    elseif bossData.difference and bossData.difference > 0 then
      cell7:SetText(FormatTime(bossData.difference) or "-")
    else
      cell7:SetText("-")
    end

    local cell8 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell8:SetPoint("LEFT", row, "LEFT", 490, 0)
    cell8:SetText(bossData.newRank or "-")

    -- Add the row to the content frame's rows table
    table.insert(frame.contentFrame.rows, row)
  end
  -- Create the close button
  local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
  closeButton:SetScript("OnClick", function(self)
    -- Save position before hiding
    SaveWrapperPosition(frame)
    frame:Hide()
  end)

  -- Create the clear button
  local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  clearButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
  clearButton:SetSize(80, 20)
  clearButton:SetText("Clear")
  clearButton:SetScript("OnClick", function(self)
    -- Clear the raid data
    BossBeaterDB.liveData = {}  -- Reset liveData in saved variables
    print("Live data cleared. Please reload the UI.")

    StaticPopup_Show("BOSSBEATER_RELOAD_UI")
  end)

  -- Add a text near the clear button that says "Requires reload"
  local reloadText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  reloadText:SetPoint("LEFT", clearButton, "RIGHT", 10, 0)
  reloadText:SetText("Requires reload")

  StaticPopupDialogs["BOSSBEATER_RELOAD_UI"] = {
    text = "Do you want to reload the UI now?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,  -- Avoid some UI taint issues
  }

end

local function RefreshRaidTableUI(raidTable, sortedBossIDs)
  if raidTable and sortedBossIDs then
    -- Hide the existing frame if it's shown
    local existingFrame = _G["BossBeaterRaidTable"]
    if existingFrame and existingFrame:IsShown() then
      existingFrame:Hide()
    end

    -- Create a new UI with the updated data 
    CreateRaidTableUI(raidTable, sortedBossIDs)
  end
end

-- Start handling boss kill timer data for ongoing play session / raid

local tempKillTimes = {}
local killTimes =  {}

local encounterStartFrame = CreateFrame("Frame", "encounterStartFrame", UIParent)

-- Insert boss id and start time into table
local function EncounterStart(_, event, encounterID, encounterName, difficultyID, groupSize)
  rankingDataBossID = GetRankingDataBossID(encounterID)
  startTime = GetTime()

  print("EncounterStart:", rankingDataBossID, startTime)

  table.insert(tempKillTimes, {
    rankingDataBossID = rankingDataBossID,
    startTime = startTime,
  })
end

encounterStartFrame:RegisterEvent("ENCOUNTER_START")
encounterStartFrame:SetScript("OnEvent", EncounterStart)


local encounterEndFrame = CreateFrame("Frame", "encounterEndFrame", UIParent)

local function EncounterEnd(_, event, encounterID, encounterName, _, _, success)
  rankingDataBossID = GetRankingDataBossID(encounterID)
  endTime = GetTime()
  local raidTable, sortedBossIDs = CreateRaidTable()

  if success == 1 then
    -- Find the corresponding entry in tempKillTimes (without removing it yet)
    local tempEntry
    for i, entry in ipairs(tempKillTimes) do
      if entry.rankingDataBossID == rankingDataBossID then
        tempEntry = entry
        break
      end
    end

    if tempEntry then
      local startTime = tempEntry.startTime
      local duration = endTime - startTime

      -- Extract the "Concede" time directly from the raidTable
      local concedeTime = tonumber(raidTable[rankingDataBossID].guildRecord) or duration

      -- Calculate the difference from the "Concede" time
      local difference = duration - (concedeTime ~= "N/A" and tonumber(concedeTime) or duration)

      
      -- Calculate new ranks
      local newWorldRank = 1
      local newServerRank = 1
  
      for _, otherData in ipairs(rankingData) do
        if tonumber(otherData.t[rankingDataBossID]) < duration then
          newWorldRank = newWorldRank + 1
          if otherData.s == "living flame" and otherData.r == "eu" then  -- Check server and region for server rank
            newServerRank = newServerRank + 1
          end
        end
      end

      print("Encounter ended in success:", rankingDataBossID, startTime, endTime, duration, difference, newWorldRank, newServerRank)

      table.insert(killTimes, {
        rankingDataBossID = rankingDataBossID,
        startTime = startTime,
        endTime = endTime,
        duration = duration,
        difference = difference,
        newWorldRank = newWorldRank,
        newServerRank = newServerRank,
      })

      for k,v in pairs(killTimes) do
        print(k,v)
      end


      -- Update raidTable with temp data
      raidTable[rankingDataBossID].time = duration
      raidTable[rankingDataBossID].difference = difference
      raidTable[rankingDataBossID].newRank = newWorldRank .. " / " .. newServerRank

      -- Save live data to saved variables
      BossBeaterDB.liveData[rankingDataBossID] = {  -- Store only live data for this boss
        time = duration,
        difference = difference,
        newRank = newWorldRank .. " / " .. newServerRank
      }

      print("Live data saved:", rankingDataBossID, duration, difference, newWorldRank, newServerRank)
      
      RefreshRaidTableUI(raidTable, sortedBossIDs)
    end
  else
    print("Encounter failed deleting temp data")
    -- clear out the row for this rankingDataBossID in the temp table so that we can fill it again next try
    for i, entry in ipairs(tempKillTimes) do
      if entry.rankingDataBossID == rankingDataBossID then
        table.remove(tempKillTimes, i)
        break
      end
    end
  end
end

encounterEndFrame:RegisterEvent("ENCOUNTER_END")
encounterEndFrame:SetScript("OnEvent", EncounterEnd)

local function SlashCmdHandler(msg, editbox)
  local raidTable, sortedBossIDs = CreateRaidTable()
  if raidTable and sortedBossIDs then
    -- Check if the frame already exists and is shown
    local frame = _G["BossBeaterRaidTable"]
    if frame and frame:IsShown() then
      frame:Hide()  -- Hide the frame if it's already shown
    else
      if not frame then
        CreateRaidTableUI(raidTable, sortedBossIDs)  -- Create and show the UI
      else
        frame:Show()  -- Show the frame if it already exists
      end
    end
  end
end

SLASH_BOSSBEATER1 = "/bb"
SLASH_BOSSBEATER2 = "/bossbeater"
SlashCmdList["BOSSBEATER"] = SlashCmdHandler

-- Call CreateRaidTable and CreateRaidTableUI after 2 seconds to ensure data is loaded
C_Timer.After(2, function()
  local raidTable, sortedBossIDs = CreateRaidTable()
  if raidTable and sortedBossIDs then
    CreateRaidTableUI(raidTable, sortedBossIDs)
  end
end)

-- Call this function when your addon loads
local function OnAddonLoaded()
  -- Initialize BossBeaterDB if it doesn't exist
  BossBeaterDB = BossBeaterDB or {
    frameX = nil,
    frameY = nil,
    liveData = {}  -- Change raidData to liveData to store only live session data
  }
  Addon.BossBeaterDB = BossBeaterDB

  -- Load previous raid table
  raidTable = Addon.BossBeaterDB.raidData or raidTable

  CreateRaidTable()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
  if addonName == "BossBeater" then
    OnAddonLoaded()
  end
end)

local logoutFrame = CreateFrame("Frame") 
    logoutFrame:RegisterEvent("PLAYER_LOGOUT")
    logoutFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        BossBeaterDB = Addon.BossBeaterDB 
    end
end)