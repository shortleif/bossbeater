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
  return string.match(rankingDataBossID, "_100(%d+)")
end

-- Function to transform dataBossID to rankingDataBossID
local function GetRankingDataBossID(dataBossID)
  return "boss_100" .. dataBossID
end

local function GetConcedeTime(rankingDataBossID)
  for _, data in ipairs(rankingData) do
    if data.guildName == "Concede" and data.times[rankingDataBossID] then
      return data.times[rankingDataBossID]  -- Return Concede's time for the boss
    end
  end
  return nil  -- Return nil if Concede's time is not found
end

local function SaveWrapperPosition(frame)
  local centerX, centerY = frame:GetCenter()
  Addon.BossBeaterDB.frameX = centerX
  Addon.BossBeaterDB.frameY = centerY
end


-- Table handling on init
local function CreateRaidTable()
  -- Ensure rankingData and bossLookup are available  
  if not rankingData or not bossLookup then
    print("Error: Ranking data or boss lookup table is not available.")
    return nil, nil  -- Return nil for both values to indicate an error
  end

  -- Create a table to store the raid data
  local raidTable = {}

  -- Collect data for each boss
  for _, data in ipairs(rankingData) do
    for rankingDataBossID, time in pairs(data.times) do
      local dataBossID = GetBossID(rankingDataBossID)
      if bossLookup[dataBossID] then
        local bossName = bossLookup[dataBossID].Name_lang

        -- Initialize the boss entry in the raidTable if it doesn't exist
        if not raidTable[rankingDataBossID] then
          raidTable[rankingDataBossID] = {
            bossName = bossName,
            worldRecord = "N/A",
            guildRecord = "N/A",
            rank = "N/A",
            serverRecord = "N/A",
            serverRank = "N/A",
          }
        end

        -- Update world record if necessary
        if not raidTable[rankingDataBossID].worldRecord or time < raidTable[rankingDataBossID].worldRecord then
          raidTable[rankingDataBossID].worldRecord = time
        end

        -- Update guild record if necessary
        if data.guildName == "Concede" and (not raidTable[rankingDataBossID].guildRecord or time < raidTable[rankingDataBossID].guildRecord) then
          raidTable[rankingDataBossID].guildRecord = time
        end

        -- Calculate and update rank (world and server)
        if data.guildName == "Concede" then
          local worldRank = 1
          local serverRank = 1

          for _, otherData in ipairs(rankingData) do
            if otherData.times[rankingDataBossID] then
              if otherData.times[rankingDataBossID] < time then
                worldRank = worldRank + 1
              end
              if otherData.servername == data.servername and otherData.region == data.region and otherData.times[rankingDataBossID] < time then
                serverRank = serverRank + 1
              end
            end
          end

          raidTable[rankingDataBossID].rank = worldRank .. " / " .. serverRank
        end

        -- Update server record if necessary
        if data.servername == "livingflame" and data.region == "eu" and (not raidTable[rankingDataBossID].serverRecord or time < raidTable[rankingDataBossID].serverRecord) then
            raidTable[rankingDataBossID].serverRecord = time
          end
      end
    end
  end

  -- Create a sorted list of boss IDs
  local sortedBossIDs = {}

  for rankingDataBossID, _ in pairs(raidTable) do
    table.insert(sortedBossIDs, rankingDataBossID)
  end
  table.sort(sortedBossIDs, function(a, b)
    return GetBossID(a) < GetBossID(b)
  end)

  return raidTable, sortedBossIDs
end

--[[local function CreateRaidTableUI(raidTable, sortedBossIDs)
  -- Check if the frame already exists
  local frame = _G["BossBeaterRaidTable"]

  local headerWidth = { 120, 80, 90, 60, 90, 90, 85, 80 } -- Adjust widths as needed
  local textOffsets = { 10, 20, 10, 90, 0, -5, -10, -15 }  -- Offsets for each header

  if not frame then
    -- Create the main frame (only if it doesn't exist)
    frame = CreateFrame("Frame", "BossBeaterRaidTable", UIParent)
    frame:SetSize(650, 400) -- Adjust size as needed

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
    header:SetSize(650, 20) -- Adjust size as needed

    local headers = { "Boss Name", "World", "Server", "Guild", "Rank (W/S)", "Time" , "Diff" , "Rank?" }
    
    for i, text in ipairs(headers) do
      local headerText = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      headerText:SetPoint("LEFT", header, "LEFT", (headerWidth[i] * (i - 1)) + textOffsets[i], 0)
      headerText:SetText(text)
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
      raidTable = CreateRaidTable()  -- Recreate the raidTable with default values
      RefreshRaidTableUI()  -- Refresh the UI
    end)
 else
    -- If the frame exists, clear its contents
    for _, child in ipairs{frame:GetChildren()} do
      if child:GetObjectType() == "FontString" then
        child:SetText("N/A")
      end
    end
  end

  -- Load live data from saved variables
  if BossBeaterDB.liveData then
    for rankingDataBossID, liveData in pairs(BossBeaterDB.liveData) do
      if raidTable[rankingDataBossID] then
        raidTable[rankingDataBossID].time = liveData.time
        raidTable[rankingDataBossID].difference = liveData.difference
        raidTable[rankingDataBossID].newRank = liveData.newRank
      end
    end
  end

  -- Create the table rows (always recreate the rows)
  local rowHeight = 20
  local numRows = 0  -- Initialize numRows to 0
  local contentOffset = 25

  if sortedBossIDs then  -- Check if sortedBossIDs is valid
    print(sortedBossIDs)
    for _, rankingDataBossID in ipairs(sortedBossIDs) do  -- Calculate numRows
      numRows = numRows + 1
    end

    -- Adjust the height of the main frame to accommodate all rows
    frame:SetHeight(80 + numRows * rowHeight + contentOffset) -- Add contentOffset

    -- Create the content frame directly inside the main frame
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10) -- Apply offset here
    contentFrame:SetSize(800, numRows * rowHeight) -- Adjust size as needed

    for i, rankingDataBossID in ipairs(sortedBossIDs) do  -- Create rows
      local bossData = raidTable[rankingDataBossID]
      local row = CreateFrame("Frame", nil, contentFrame)
      row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -rowHeight * (i - 1))
      row:SetSize(800, rowHeight)

      local bossName = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      bossName:SetPoint("LEFT", row, "LEFT", 10, 5)
      bossName:SetWidth(headerWidth[1])
      bossName:SetText(bossData.bossName)
      bossName:SetJustifyH("LEFT")
      print(bossData.bossName)

      local worldRecord = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      worldRecord:SetPoint("LEFT", bossName, "RIGHT", 5, 0)  -- Add spacing
      worldRecord:SetWidth(headerWidth[2] - 25)  -- Adjust width to account for spacing
      worldRecord:SetText(bossData.worldRecord)
      worldRecord:SetJustifyH("LEFT")
      print(bossData.worldRecord)

      local serverRecord = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      serverRecord:SetPoint("LEFT", worldRecord, "RIGHT", 5, 0) -- Add spacing
      serverRecord:SetWidth(headerWidth[3] - 5)  -- Adjust width to account for spacing
      serverRecord:SetText(bossData.serverRecord)
      serverRecord:SetJustifyH("LEFT")
      print(bossData.serverRecord)

      local guildRecord = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      guildRecord:SetPoint("LEFT", serverRecord, "RIGHT", -25, 0) -- Add spacing
      guildRecord:SetWidth(headerWidth[4] - 5)  -- Adjust width to account for spacing
      guildRecord:SetText(bossData.guildRecord)
      guildRecord:SetJustifyH("LEFT")
      print(bossData.guildRecord)

      local rank = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      rank:SetPoint("LEFT", guildRecord, "RIGHT", -5, 0) -- Add spacing
      rank:SetWidth(headerWidth[5] - 20)  -- Adjust width to account for spacing
      rank:SetText(bossData.rank)
      print(bossData.rank)

      local time = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      time:SetPoint("LEFT", rank, "RIGHT", 35, 0)  -- Add spacing
      time:SetWidth(headerWidth[6] - 5)  -- Adjust width
      time:SetText(bossData.time)
      time:SetJustifyH("LEFT")
      print(bossData.time)

      local difference = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      difference:SetPoint("LEFT", time, "RIGHT", -35, 0) -- Add spacing
      difference:SetWidth(headerWidth[7] - 5)  -- Adjust width
      difference:SetText(bossData.difference)
      difference:SetJustifyH("LEFT")
      print(bossData.difference)

      local newRank = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      newRank:SetPoint("LEFT", difference, "RIGHT", -25, 0) -- Add spacing
      newRank:SetWidth(headerWidth[8] - 5)  -- Adjust width
      newRank:SetText(bossData.newRank)
      newRank:SetJustifyH("LEFT")
      print(bossData.newRank)

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
      raidTable = CreateRaidTable()  -- Recreate the raidTable with default values
      RefreshRaidTableUI()  -- Refresh the UI
    end)

  else
    print("Error: sortedBossIDs is nil in CreateRaidTableUI (numRows calculation)")
  end

  frame:Show() -- Show the frame after creating all elements
end]]--

local function CreateRaidTableUI(raidTable, sortedBossIDs)
    -- Check if the frame already exists
  local frame = _G["BossBeaterRaidTable"]

  local textOffsets = { 10, 140, 200, 260, 315, 390, 440, 490 }  -- Offsets for each header

  if not frame or (frame and not frame:IsShown()) then
    -- Create the main frame (only if it doesn't exist)
    frame = CreateFrame("Frame", "BossBeaterRaidTable", UIParent)
    frame:SetSize(650, 400) -- Adjust size as needed

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
    header:SetSize(650, 20) -- Adjust size as needed

    local headers = { "Boss Name", "World", "Server", "Guild", "Rank (W/S)", "Time" , "Diff" , "Rank?" }
    
    for i, text in ipairs(headers) do
      local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      headerText:SetPoint("LEFT", header, "LEFT", textOffsets[i], 0)
      headerText:SetText(text)
    end

    -- Initialize the content frame and rows
    frame.contentFrame = CreateFrame("Frame", nil, frame)
    frame.contentFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    frame.contentFrame:SetSize(800, 400)
    frame.contentFrame.rows = {}
  end

  -- Create rows
  local rowHeight = 20
  for i, rankingDataBossID in ipairs(sortedBossIDs) do
    local bossData = raidTable[rankingDataBossID]
    local row = CreateFrame("Frame", nil, frame.contentFrame)
    row:SetPoint("TOPLEFT", frame.contentFrame, "TOPLEFT", 0, -rowHeight * i - 20) -- Adjust for header height
    row:SetSize(800, rowHeight)

    -- Create cells with data from raidTable
    local cell1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell1:SetPoint("LEFT", row, "LEFT", 10, 0)
    cell1:SetText(bossData.bossName or "N/A")

    local cell2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell2:SetPoint("LEFT", row, "LEFT", 140, 0)
    cell2:SetText(bossData.worldRecord or "N/A")

    local cell3 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell3:SetPoint("LEFT", row, "LEFT", 200, 0)
    cell3:SetText(bossData.serverRecord or "N/A")

    local cell4 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell4:SetPoint("LEFT", row, "LEFT", 260, 0)
    cell4:SetText(bossData.guildRecord or "N/A")

    local cell5 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell5:SetPoint("LEFT", row, "LEFT", 315, 0)
    cell5:SetText(bossData.rank or "N/A")

    local cell6 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell6:SetPoint("LEFT", row, "LEFT", 390, 0)
    cell6:SetText(bossData.time or "-")

    local cell7 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell7:SetPoint("LEFT", row, "LEFT", 440, 0)
    cell7:SetText(bossData.difference or "-")

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
    raidTable = CreateRaidTable()  -- Recreate the raidTable with default values
    RefreshRaidTableUI()  -- Refresh the UI
  end)

end

local function RefreshRaidTableUI()
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

      -- Format duration as minutes and seconds (mm:ss)
      local minutes = math.floor(duration / 60)
      local seconds = math.floor(duration % 60)
      local formattedDuration = string.format("%02d:%02d", minutes, seconds)

      -- Calculate difference from Concede's previous record
      local concedeTime = GetConcedeTime(rankingDataBossID) or 0  -- Get Concede's time or use 0 if not found

      -- Convert concedeTime from "mm:ss" to seconds
      local concedeMinutes, concedeSeconds = string.match(concedeTime, "(%d+):(%d+)")
      concedeTime = (tonumber(concedeMinutes) or 0) * 60 + (tonumber(concedeSeconds) or 0)

      local difference = duration - concedeTime  -- Calculate difference in seconds
      local formattedDifference = string.format("%.1f", difference)


      -- Calculate new ranks
      local newWorldRank = 1
      local newServerRank = 1
  
      for _, otherData in ipairs(rankingData) do
        if otherData.times[rankingDataBossID] and otherData.times[rankingDataBossID] < formattedDuration then
          newWorldRank = newWorldRank + 1
          if otherData.servername == "livingflame" and otherData.region == "eu" then  -- Check server and region for server rank
            newServerRank = newServerRank + 1
          end
        end
      end

      print("Encounter ended in success:", rankingDataBossID, startTime, endTime, duration, difference, newRank)

      table.insert(killTimes, {
        rankingDataBossID = rankingDataBossID,
        startTime = startTime,
        endTime = endTime,
        duration = formattedDuration,
        difference = formattedDifference,
        newWorldRank = newWorldRank,
        newServerRank = newServerRank,
      })


      -- Update raidTable with temp data
      if raidTable and raidTable[rankingDataBossID] then
        raidTable[rankingDataBossID].time = formattedDuration
        raidTable[rankingDataBossID].difference = formattedDifference
        raidTable[rankingDataBossID].newRank = newWorldRank .. " / " .. newServerRank
      end

      -- Save live data to saved variables
      BossBeaterDB.liveData[rankingDataBossID] = {  -- Store only live data for this boss
        time = formattedDuration,
        difference = formattedDifference,
        newRank = newWorldRank .. " / " .. newServerRank
      }
      
      RefreshRaidTableUI()
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
      print("Hiding raid table")
      frame:Hide()  -- Hide the frame if it's already shown
    else
      print("Showing raid table")
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