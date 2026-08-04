
-- ── Load Library ──────────────────────────────────────────────────────────────
local Library = loadstring(game:HttpGet(
    "https://codeberg.org/VenomVent/Ventura-UI/raw/branch/main/VenturaLibrary.lua"
))()

-- ── Window ────────────────────────────────────────────────────────────────────
local GUI = Library:new({
    name        = "Jobs & Farming Hub",
    subtitle    = "Silent Roadwork • Auto Restock",
    accent      = Color3.fromRGB(90, 60, 200),
    toggleKey   = Enum.KeyCode.Insert,
    minimizeKey = Enum.KeyCode.K,
    loadingTime = 1.5,
    keyEnabled  = false,
})

-- ── Services ──────────────────────────────────────────────────────────────────
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

-- ════════════════════════════════════════════════════════════════════════════
--  STAT SELECTION SYSTEM
-- ════════════════════════════════════════════════════════════════════════════

local StatSettings = {
    AutoSelect = false,
    SelectedStat = "Stamina" -- "Stamina" or "Agility"
}

local function PhysicalClick(guiObject: GuiObject)
    if not guiObject or not guiObject.AbsolutePosition then return end

    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local inset = GuiService:GetGuiInset()

    local clickX = absPos.X + (absSize.X / 2)
    local clickY = absPos.Y + (absSize.Y / 2) + inset.Y

    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 1)
    end)
end

local function SelectStat(statName: string)
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end

        local btns = playerGui:FindFirstChild("Machines")
            and playerGui.Machines:FindFirstChild("Container")
            and playerGui.Machines.Container:FindFirstChild("btns")

        if not btns then return end

        -- Try exact match first, then case-insensitive partial match
        local targetStat = btns:FindFirstChild(statName)
        if not targetStat then
            local lowerTarget = string.lower(statName)
            for _, child in ipairs(btns:GetChildren()) do
                if string.lower(child.Name):find(lowerTarget, 1, true) then
                    targetStat = child
                    break
                end
            end
        end

        if not targetStat then
            -- Debug: print available stat buttons so you can fix the name
            local names = {}
            for _, child in ipairs(btns:GetChildren()) do
                table.insert(names, child.Name)
            end
            warn("[SelectStat] Could not find stat '" .. statName .. "'. Available: " .. table.concat(names, ", "))
            return
        end

        local innerFrame = targetStat:FindFirstChild("frame")
        local imgBtn = innerFrame and innerFrame:FindFirstChild("img")

        local clickableObject = imgBtn or innerFrame or targetStat

        if clickableObject and clickableObject:IsA("GuiObject") then
            PhysicalClick(clickableObject)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  SILENT ROADWORK (NEW BUY LOGIC)
-- ════════════════════════════════════════════════════════════════════════════

type FarmState = {
    IsFarming: boolean,
    AutoBuy: boolean,
    ScanSpeed: number,
    MaxBuyDistance: number,
    SelectedStat: string
}

local FarmService = {}
FarmService.__index = FarmService

export type FarmServiceClass = typeof(setmetatable({} :: FarmState, FarmService))

local touchedParts = {} -- Debounce tracking

function FarmService.new(): FarmServiceClass
    local self: FarmState = {
        IsFarming = false,
        AutoBuy = true,
        ScanSpeed = 0.08,
        MaxBuyDistance = 30,
        SelectedStat = "Stamina"
    }
    return setmetatable(self, FarmService) :: any
end

function FarmService.PurgeZones(self: FarmServiceClass): ()
    pcall(function()
        local zones = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("zones")
        if zones then
            local streets = zones:FindFirstChild("Streets") or zones:FindFirstChild("streets")
            if streets then
                for _, child in ipairs(streets:GetChildren()) do
                    pcall(function() child:Destroy() end)
                end
                pcall(function() streets:Destroy() end)
            end
        end
    end)
end

function FarmService.SilentTouch(self: FarmServiceClass, hrp: BasePart, targetPart: BasePart): ()
    if not hrp or not targetPart or not targetPart.Parent then return end
    if not targetPart:IsDescendantOf(workspace) then return end
    
    -- Debounce check
    if touchedParts[targetPart] then return end
    touchedParts[targetPart] = true
    
    pcall(function()
        self:PurgeZones()
        local firetouch = (getgenv() :: any).firetouchinterest or firetouchinterest
        if firetouch then
            firetouch(hrp, targetPart, 0)
            task.wait(0.02)
            firetouch(hrp, targetPart, 1)
        end
    end)
    
    -- Clear debounce after 3s
    task.delay(3, function()
        touchedParts[targetPart] = nil
    end)
end

-- ── Tool helpers ─────────────────────────────────────────────────────────────
function FarmService.GetRoadworkTool(self: FarmServiceClass): Tool?
    local char = LocalPlayer.Character
    if char then
        local t = char:FindFirstChild("Roadwork")
        if t and t:IsA("Tool") then return t :: Tool end
    end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local t = backpack:FindFirstChild("Roadwork")
        if t and t:IsA("Tool") then return t :: Tool end
    end
    return nil
end

function FarmService.HasRoadwork(self: FarmServiceClass): boolean
    return self:GetRoadworkTool() ~= nil
end

function FarmService.EquipAndActivateRoadwork(self: FarmServiceClass): boolean
    local tool = self:GetRoadworkTool()
    if not tool then return false end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if tool.Parent ~= char and humanoid then
        humanoid:EquipTool(tool)
        task.wait(0.2)
    end
    pcall(function() tool:Activate() end)
    task.wait(0.2)
    return true
end

-- ── Stat UI click ────────────────────────────────────────────────────────────
function FarmService.SelectStatUI(self: FarmServiceClass): ()
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local btns = playerGui:FindFirstChild("Machines")
            and playerGui.Machines:FindFirstChild("Container")
            and playerGui.Machines.Container:FindFirstChild("btns")
        if not btns then return end

        -- Exact match first, then case-insensitive partial fallback
        local statContainer = btns:FindFirstChild(self.SelectedStat)
        if not statContainer then
            local lower = string.lower(self.SelectedStat)
            for _, child in ipairs(btns:GetChildren()) do
                if string.lower(child.Name):find(lower, 1, true) then
                    statContainer = child
                    break
                end
            end
        end
        if not statContainer then
            local names = {}
            for _, c in ipairs(btns:GetChildren()) do table.insert(names, c.Name) end
            warn("[SelectStatUI] '" .. self.SelectedStat .. "' not found. Available: " .. table.concat(names, ", "))
            return
        end

        local innerFrame = statContainer:FindFirstChild("frame")
        local imgBtn = innerFrame and innerFrame:FindFirstChild("img")
        local target = imgBtn or innerFrame or statContainer
        if target and target:IsA("GuiObject") then
            PhysicalClick(target)
        end
    end)
end

-- ✅ NEW: Improved buy logic with distance checking
function FarmService.AutoBuyButtons(self: FarmServiceClass): boolean
    local success = false
    pcall(function()
        local buyFolder = workspace:FindFirstChild("BuyButtons")
        if not buyFolder then return end
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end

        -- Find all Roadwork buttons
        local roadworkButtons = {}
        for _, child in ipairs(buyFolder:GetChildren()) do
            if child.Name == "Roadwork" and child:IsA("BasePart") then
                table.insert(roadworkButtons, child)
            end
        end

        if #roadworkButtons == 0 then return end

        -- Find closest button within range
        local closestBtn = nil
        local closestDist = self.MaxBuyDistance

        for _, btn in ipairs(roadworkButtons) do
            local dist = (hrp.Position - btn.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestBtn = btn
            end
        end

        if not closestBtn then return end

        -- Try to click the closest button
        local detector = closestBtn:FindFirstChildOfClass("ClickDetector")
        local fireclick = (getgenv() :: any).fireclickdetector or fireclickdetector
        
        if detector and fireclick then
            fireclick(detector :: ClickDetector)
            success = true
            print("[AUTO BUY] Roadwork purchased! Distance:", math.floor(closestDist))
        end
    end)
    return success
end

function FarmService.GetScanParts(self: FarmServiceClass): {BasePart}
    local targets: {BasePart} = {}
    local junkFolder = workspace:FindFirstChild("Junk")
    
    if junkFolder then
        for _, item: Instance in ipairs(junkFolder:GetChildren()) do
            -- ✅ FIXED: Only match parts that START with "ScanPart"
            if item:IsA("BasePart") and string.match(item.Name, "^ScanPart") then
                -- Only add if valid and not touched recently
                if item.Parent and item:IsDescendantOf(workspace) and not touchedParts[item] then
                    table.insert(targets, item)
                end
            end
        end
    end
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hrp then
        table.sort(targets, function(a: BasePart, b: BasePart)
            return (hrp.Position - a.Position).Magnitude < (hrp.Position - b.Position).Magnitude
        end)
    end
    
    return targets
end

local RoadworkApp = FarmService.new()
RoadworkApp:PurgeZones()

workspace.ChildAdded:Connect(function(child: Instance)
    if string.lower(child.Name) == "zones" then
        task.wait(0.05)
        RoadworkApp:PurgeZones()
    end
end)

local zonesFolder = workspace:FindFirstChild("Zones") or workspace:FindFirstChild("zones")
if zonesFolder then
    zonesFolder.ChildAdded:Connect(function(child: Instance)
        if string.lower(child.Name) == "streets" then
            task.wait(0.05)
            RoadworkApp:PurgeZones()
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  AUTO RESTOCK
-- ════════════════════════════════════════════════════════════════════════════

_G.PapapaikumActiveSpots = _G.PapapaikumActiveSpots or {}
_G.PapapaikumSpotsToRestock = _G.PapapaikumSpotsToRestock or {}

local restockThread = nil
local restockActive = false

local function runRestockScript()
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local PathfindingService = game:GetService("PathfindingService")

    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Character:WaitForChild("HumanoidRootPart")

    local GamePackets = require(ReplicatedStorage:WaitForChild("GamePackets"))
    local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
    local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
    local Controls = PlayerModule:GetControls()

    local activeSpots = _G.PapapaikumActiveSpots
    local spotsToRestock = _G.PapapaikumSpotsToRestock

    if _G.PapapaikumJobConnection then
        _G.PapapaikumJobConnection:Disconnect()
        _G.PapapaikumJobConnection = nil
    end

    local jobConnection
    jobConnection = GamePackets.JobsClientPush.OnClientEvent:Connect(function(data)
        if type(data) == "table" and data[1] == "Stocker" then
            local action = data[2]
            if action == "BoxPickedUp" then
                table.clear(activeSpots)
                local newSpots = data[3] or {}
                for k, v in pairs(newSpots) do activeSpots[k] = v end
                table.clear(spotsToRestock)
                for _, spot in pairs(activeSpots) do
                    if spot and spot.Parent then
                        table.insert(spotsToRestock, spot)
                    end
                end
            elseif action == "SpotUsed" then
                local spotIndex = data[3]
                if spotIndex then
                    local spotInstance = activeSpots[spotIndex]
                    if spotInstance then
                        activeSpots[spotIndex] = nil
                        for i = #spotsToRestock, 1, -1 do
                            if spotsToRestock[i] == spotInstance then
                                table.remove(spotsToRestock, i)
                            end
                        end
                    end
                end
            elseif action == "EndJob" then
                table.clear(activeSpots)
                table.clear(spotsToRestock)
            end
        end
    end)
    _G.PapapaikumJobConnection = jobConnection

    local function walkTo(targetPos)
        local distanceThreshold = 1.5
        Controls:Disable()

        local function getPath(start, target)
            local path = PathfindingService:CreatePath({
                AgentRadius = 3,
                AgentHeight = 6,
                AgentCanJump = true,
                WaypointSpacing = 4
            })
            local success, _ = pcall(function()
                path:ComputeAsync(start, target)
            end)
            if success and path.Status == Enum.PathStatus.Success then
                return path:GetWaypoints()
            end
            return nil
        end

        local waypoints = getPath(RootPart.Position, targetPos)
        if not waypoints then
            warn("Pathfinding failed, attempting direct walk")
            waypoints = { { Position = targetPos, Action = Enum.PathWaypointAction.Walk } }
        end

        local currentWaypointIndex = 1
        local lastPos = RootPart.Position
        local lastStuckCheck = os.clock()

        while currentWaypointIndex <= #waypoints do
            if _G.StopRestock then break end
            local waypoint = waypoints[currentWaypointIndex]
            local currentPos = RootPart.Position
            local targetPosHorizontal = Vector3.new(waypoint.Position.X, currentPos.Y, waypoint.Position.Z)
            local distance = (currentPos - targetPosHorizontal).Magnitude

            if distance <= distanceThreshold then
                currentWaypointIndex = currentWaypointIndex + 1
            else
                local direction = (targetPosHorizontal - currentPos).Unit
                LocalPlayer:Move(direction, false)

                if waypoint.Action == Enum.PathWaypointAction.Jump and Humanoid.FloorMaterial ~= Enum.Material.Air then
                    Humanoid.Jump = true
                end

                if os.clock() - lastStuckCheck > 1.5 then
                    if (RootPart.Position - lastPos).Magnitude < 1.5 then
                        Humanoid.Jump = true
                        print("Stuck! Recalculating path...")
                        local newWaypoints = getPath(RootPart.Position, targetPos)
                        if newWaypoints then
                            waypoints = newWaypoints
                            currentWaypointIndex = 1
                        end
                    end
                    lastPos = RootPart.Position
                    lastStuckCheck = os.clock()
                end
            end
            RunService.Heartbeat:Wait()
        end

        LocalPlayer:Move(Vector3.new(0, 0, 0), false)
        Controls:Enable()
    end

    local function interactWith(part)
        local cd = part:FindFirstChildOfClass("ClickDetector")
        if cd then
            RootPart.CFrame = CFrame.new(RootPart.Position, Vector3.new(part.Position.X, RootPart.Position.Y, part.Position.Z))
            task.wait(0.1)
            local distance = (RootPart.Position - part.Position).Magnitude
            if distance <= cd.MaxActivationDistance then
                fireclickdetector(cd, 0)
                task.wait(0.5)
            else
                warn("Too far to click! Distance: " .. tostring(distance))
            end
        end
    end

    local jlf = Workspace:WaitForChild("Jobs"):WaitForChild("Restock"):WaitForChild("JLF")
    local stockBox = jlf:WaitForChild("Stock")

    while true do
        if _G.StopRestock then
            Controls:Enable()
            print("Restock script stopped.")
            break
        end

        local distanceToJLF = (RootPart.Position - stockBox.Position).Magnitude
        if distanceToJLF > 100 then
            print("You're not in the place, cannot start job")
            task.wait(5)
            continue
        end

        local currentJob = LocalPlayer:GetAttribute("CurrentJob")
        if currentJob ~= "Restocking" then
            print("Starting Restocking Job...")
            GamePackets.JobsCommand:Fire({"Stocker"})
            task.wait(1.5)
        end

        if #spotsToRestock == 0 then
            print("Walking to Stock Box...")
            walkTo(stockBox.Position)
            if _G.StopRestock then break end
            task.wait(0.8)
            interactWith(stockBox)

            local waitStart = os.clock()
            while #spotsToRestock == 0 and os.clock() - waitStart < 4 do
                task.wait(0.1)
                if _G.StopRestock then break end
            end
        end

        if _G.StopRestock then break end

        while #spotsToRestock > 0 do
            if _G.StopRestock then break end

            local closestSpot = nil
            local closestDistance = math.huge
            for _, spot in ipairs(spotsToRestock) do
                if spot and spot.Parent then
                    local targetPosHorizontal = Vector3.new(spot.Position.X, RootPart.Position.Y, spot.Position.Z)
                    local dist = (RootPart.Position - targetPosHorizontal).Magnitude
                    if dist < closestDistance then
                        closestDistance = dist
                        closestSpot = spot
                    end
                end
            end

            if closestSpot then
                print("Walking to closest spot...")
                walkTo(closestSpot.Position)
                if _G.StopRestock then break end
                task.wait(1.5)
                interactWith(closestSpot)

                local waitStart = os.clock()
                local initialCount = #spotsToRestock
                while #spotsToRestock == initialCount and os.clock() - waitStart < 3 do
                    task.wait(0.1)
                    if _G.StopRestock then break end
                end
            else
                table.clear(spotsToRestock)
            end
            task.wait(0.5)
        end
        task.wait(1)
    end
end

GUI:NavSection("TRAIN")
local JobsTab = GUI:CreateTab({ name = "Train" })

JobsTab:Section({ name = "Silent Roadwork" })

JobsTab:Slider({
    name     = "Scan Speed",
    min      = 0.02, max = 0.5, default = 0.08,
    suffix   = "s",
    callback = function(v)
        RoadworkApp.ScanSpeed = v
    end,
})

JobsTab:Slider({
    name     = "Max Buy Distance",
    min      = 10, max = 100, default = 30,
    suffix   = " studs",
    callback = function(v)
        RoadworkApp.MaxBuyDistance = v
    end,
})

JobsTab:Toggle({
    name     = "Auto Buy After Completion",
    description = "Buys roadwork ONLY after all items collected",
    default  = true,
    callback = function(v)
        RoadworkApp.AutoBuy = v
    end,
})

JobsTab:Toggle({
    name     = "Silent Roadwork",
    description = "Auto-collect roadwork junk",
    default  = false,
    callback = function(v)
        RoadworkApp.IsFarming = v
        
        if RoadworkApp.IsFarming then
            RoadworkApp:PurgeZones()
            table.clear(touchedParts)
            GUI.notify("Started", "Silent Roadwork active.", 2, "success")
            
            task.spawn(function()
                while RoadworkApp.IsFarming do
                    local character = LocalPlayer.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

                    if hrp and humanoid and humanoid.Health > 0 then
                        -- 1. If no tool, try to auto-buy first
                        if not RoadworkApp:HasRoadwork() then
                            if RoadworkApp.AutoBuy then
                                local bought = RoadworkApp:AutoBuyButtons()
                                if bought then
                                    GUI.notify("Auto Buy", "Roadwork purchased!", 2)
                                    task.wait(1.5) -- wait for tool to appear
                                else
                                    GUI.notify("Auto Buy", "No buy button in range", 2, "warning")
                                end
                            end
                            task.wait(0.2)
                        end

                        -- 2. Equip + activate tool, then click the selected stat
                        if RoadworkApp:HasRoadwork() then
                            RoadworkApp:EquipAndActivateRoadwork()
                            RoadworkApp:SelectStatUI()
                        end

                        -- 3. Silent-touch all scan parts
                        local scanParts = RoadworkApp:GetScanParts()
                        for _, part in ipairs(scanParts) do
                            if not RoadworkApp.IsFarming then break end
                            if not part or not part.Parent or not part:IsDescendantOf(workspace) then
                                continue
                            end
                            pcall(function()
                                RoadworkApp:SilentTouch(hrp, part)
                            end)
                            task.wait(RoadworkApp.ScanSpeed)
                        end
                    end

                    task.wait(0.1)
                end
            end)
        else
            GUI.notify("Stopped", "Roadwork halted.", 2)
        end
    end,
})

JobsTab:Section({ name = "Stat Selection" })
JobsTab:Label({ text = "Current stat: " .. RoadworkApp.SelectedStat })

-- Workaround: two buttons instead of dropdown (dropdown unreliable)
JobsTab:Button({
    name        = "Select Stamina",
    description = "Set active stat to Stamina",
    callback    = function()
        RoadworkApp.SelectedStat  = "Stamina"
        StatSettings.SelectedStat = "Stamina"
        GUI.notify("Stat", "Now using: Stamina", 2)
    end,
})

JobsTab:Button({
    name        = "Select Agility",
    description = "Set active stat to Agility",
    callback    = function()
        RoadworkApp.SelectedStat  = "Agility"
        StatSettings.SelectedStat = "Agility"
        GUI.notify("Stat", "Now using: Agility", 2)
    end,
})

JobsTab:Toggle({
    name        = "Auto Select Stat",
    description = "Automatically clicks selected stat button every 5s",
    default     = false,
    callback    = function(v)
        StatSettings.AutoSelect = v
        
        if StatSettings.AutoSelect then
            GUI.notify("Started", "Auto stat selection active.", 2, "success")
            task.spawn(function()
                while StatSettings.AutoSelect do
                    RoadworkApp:SelectStatUI()
                    task.wait(5)
                end
            end)
        else
            GUI.notify("Stopped", "Auto stat selection halted.", 2)
        end
    end,
})

JobsTab:Separator()
JobsTab:Label({ text = "Finds closest buy button" })
JobsTab:Label({ text = "Distance check before buying" })

GUI:NavSection("JOBS")
local TrainTab = GUI:CreateTab({ name = "Jobs" })

TrainTab:Section({ name = "Auto Restock Job" })

TrainTab:Toggle({
    name        = "Auto Restock",
    description = "Automatically restock shelves at JLF",
    default     = false,
    callback    = function(v)
        restockActive = v
        
        if restockActive then
            _G.StopRestock = nil
            GUI.notify("Started", "Auto Restock active.", 2, "success")
            
            local VirtualUser = game:GetService("VirtualUser")
            task.spawn(function()
                while restockActive do
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                    task.wait(60)
                end
            end)

            restockThread = task.spawn(function()
                local ok, err = pcall(runRestockScript)
                if not ok then
                    warn("Restock script error: " .. tostring(err))
                    restockActive = false
                    GUI.notify("Error", "Restock failed: " .. tostring(err), 4, "error")
                end
            end)
        else
            _G.StopRestock = true
            task.wait(0.5)
            _G.StopRestock = nil
            
            if restockThread then
                task.cancel(restockThread)
                restockThread = nil
            end
            
            GUI.notify("Stopped", "Auto Restock halted.", 2)
        end
    end,
})

TrainTab:Separator()
TrainTab:Label({ text = "📍 Restock requires JLF proximity" })
TrainTab:Label({ text = "🎯 Stat selection works at machines" })

GUI:NavSection("MISC")
local MiscTab = GUI:CreateTab({ name = "Misc", icon = "🔧" })

MiscTab:Section({ name = "Info" })
MiscTab:Label({ text = "VenturaUI v3.3 • Smart Buy Logic" })
MiscTab:Label({ text = "Game: [🔥RELEASE] KEN" })
MiscTab:Chip({ text = "STABLE", color = Color3.fromRGB(60, 200, 100), icon = "✅" })

MiscTab:Section({ name = "Controls" })
MiscTab:ControlHint({ name = "Toggle UI",   key = "Insert", description = "Show / hide window" })
MiscTab:ControlHint({ name = "Minimize UI", key = "K",      description = "Collapse to titlebar" })

MiscTab:Section({ name = "Utilities" })
MiscTab:ButtonGrid({
    columns = 2,
    buttons = {
        { name = "Copy UserId", icon = "📋", callback = function()
            pcall(function() setclipboard(tostring(LocalPlayer.UserId)) end)
            GUI.notify("Copied!", "UserId: " .. LocalPlayer.UserId, 2, "success")
        end },
        { name = "Rejoin", icon = "🔄", callback = function()
            pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId) end)
        end },
    }
})

task.delay(2, function()
    GUI.notify("Jobs & Farming Hub", "Loaded! Press Insert to toggle.", 4, "success")
end)