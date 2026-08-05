local Library = loadstring(game:HttpGet(
    "https://codeberg.org/VenomVent/Ventura-UI/raw/branch/main/VenturaLibrary.lua"
))()

local GUI = Library:new({
    name = "Jobs & Farming Hub",
    subtitle = "Silent Roadwork • Auto Restock",
    accent = Color3.fromRGB(90, 60, 200),
    toggleKey = Enum.KeyCode.Insert,
    minimizeKey = Enum.KeyCode.K,
    loadingTime = 1.5,
    keyEnabled = false,
})


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    RootPart = char:WaitForChild("HumanoidRootPart")
end)



local function GetPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function PhysicalClick(guiObject)
    if not guiObject or not guiObject.AbsolutePosition then return false end
    
    local pos = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2 + inset.Y
    
    local success = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
    
    return success
end

local function IsMachineUIVisible()
    local pg = GetPlayerGui()
    if not pg then return false end
    
    local machines = pg:FindFirstChild("Machines")
    if not machines then return false end
    
    local container = machines:FindFirstChild("Container")
    return container and container.Visible
end



local RoadworkFarm = {
    Active = false,
    AutoBuy = true,
    ScanSpeed = 0.08,
    MaxBuyDistance = 30,
    SelectedStat = "Stamina",
    TouchedCache = {},
    ZonesPurged = false,
    BoxingGymPos = Vector3.new(-24.290, 39.497, -2.150),
    GymProximity = 150
}

function RoadworkFarm:PurgeZones()
    if self.ZonesPurged then return end
    
    local zones = Workspace:FindFirstChild("Zones")
    if zones then
        local streets = zones:FindFirstChild("Streets")
        if streets then
            pcall(function() streets:Destroy() end)
            self.ZonesPurged = true
        end
    end
end

function RoadworkFarm:GetTool()
    local tool = Character:FindFirstChild("Roadwork")
    if tool and tool:IsA("Tool") then return tool end
    
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        tool = bp:FindFirstChild("Roadwork")
        if tool and tool:IsA("Tool") then return tool end
    end
    
    return nil
end

function RoadworkFarm:EquipTool()
    local tool = self:GetTool()
    if not tool then return false end
    
    if tool.Parent ~= Character then
        Humanoid:EquipTool(tool)
        task.wait(0.2)
    end
    
    pcall(function() tool:Activate() end)
    return true
end

function RoadworkFarm:SelectStat()
    if not IsMachineUIVisible() then return false end
    
    local pg = GetPlayerGui()
    if not pg then return false end
    
    local btns = pg.Machines.Container.btns
    local statFrame = btns:FindFirstChild(self.SelectedStat)
    
    if not statFrame then return false end
    
    local frame = statFrame:FindFirstChild("frame")
    local img = frame and frame:FindFirstChild("img")
    
    return PhysicalClick(img or frame or statFrame)
end

function RoadworkFarm:SilentTouch(part)
    if not part or not part.Parent or self.TouchedCache[part] then 
        return 
    end
    
    self.TouchedCache[part] = true
    self:PurgeZones()
    
    local firetouch = getgenv().firetouchinterest or firetouchinterest
    if firetouch then
        pcall(function()
            firetouch(RootPart, part, 0)
            task.wait(0.02)
            firetouch(RootPart, part, 1)
        end)
    end
    
    task.delay(3, function()
        self.TouchedCache[part] = nil
    end)
end

function RoadworkFarm:GetScanParts()
    local junk = Workspace:FindFirstChild("Junk")
    if not junk then return {} end
    
    local parts = {}
    for _, item in ipairs(junk:GetChildren()) do
        if item:IsA("BasePart") and 
           string.match(item.Name, "^ScanPart") and
           not self.TouchedCache[item] then
            table.insert(parts, item)
        end
    end
    
    table.sort(parts, function(a, b)
        return (RootPart.Position - a.Position).Magnitude < 
               (RootPart.Position - b.Position).Magnitude
    end)
    
    return parts
end

function RoadworkFarm:AutoBuy()
    local distToGym = (RootPart.Position - self.BoxingGymPos).Magnitude
    if distToGym > self.GymProximity then
        return false
    end
    
    local buyFolder = Workspace:FindFirstChild("BuyButtons")
    if not buyFolder then return false end
    
    local closest, closestDist = nil, self.MaxBuyDistance
    
    for _, child in ipairs(buyFolder:GetChildren()) do
        if child.Name == "Roadwork" and child:IsA("BasePart") then
            local btnDistToGym = (child.Position - self.BoxingGymPos).Magnitude
            if btnDistToGym < self.GymProximity then
                local dist = (RootPart.Position - child.Position).Magnitude
                if dist < closestDist then
                    closest, closestDist = child, dist
                end
            end
        end
    end
    
    if not closest then return false end
    
    local detector = closest:FindFirstChildOfClass("ClickDetector")
    local fireclick = getgenv().fireclickdetector or fireclickdetector
    
    if detector and fireclick then
        fireclick(detector)
        return true
    end
    
    return false
end

function RoadworkFarm:Start()
    self.Active = true
    self.TouchedCache = {}
    self.ZonesPurged = false
    self:PurgeZones()

    -- Notif hider loop
    task.spawn(function()
        while self.Active do
            task.wait(0.1)
            local pg = GetPlayerGui()
            if not pg then continue end
            for _, name in ipairs({"NewNotif", "NotifInterface"}) do
                local gui = pg:FindFirstChild(name)
                if gui then
                    pcall(function() gui.Enabled = false end)
                end
            end
        end
    end)

    -- Auto buy: trigger when RoadworkWaypointMarker is removed (session complete)
    task.spawn(function()
        local junk = Workspace:FindFirstChild("Junk")
        if not junk then return end

        junk.ChildRemoved:Connect(function(child)
            if not self.Active then return end
            if not self.AutoBuy then return end
            if child.Name == "RoadworkWaypointMarker_" .. LocalPlayer.UserId then
                task.wait(0.5)
                self:AutoBuy()
            end
        end)
    end)

    -- Auto equip loop: instant spam
    task.spawn(function()
        while self.Active do
            task.wait()
            if not Character or not RootPart then continue end
            local tool = self:GetTool()
            if tool and tool.Parent ~= Character then
                pcall(function() Humanoid:EquipTool(tool) end)
            elseif tool and tool.Parent == Character then
                pcall(function() tool:Activate() end)
            end
        end
    end)

    -- Main scan loop
    task.spawn(function()
        while self.Active do
            if not Character or not RootPart or Humanoid.Health <= 0 then
                task.wait(1)
                continue
            end

            if IsMachineUIVisible() then
                self:SelectStat()
            end
            
            for _, part in ipairs(self:GetScanParts()) do
                if not self.Active then break end
                self:SilentTouch(part)
                task.wait(self.ScanSpeed)
            end
            
            task.wait(0.1)
        end
    end)
end

function RoadworkFarm:Stop()
    self.Active = false
    self.TouchedCache = {}
    local pg = GetPlayerGui()
    if pg then
        for _, name in ipairs({"NewNotif", "NotifInterface"}) do
            local gui = pg:FindFirstChild(name)
            if gui then pcall(function() gui.Enabled = true end) end
        end
    end
end

Workspace.ChildAdded:Connect(function(child)
    if child.Name:lower() == "zones" then
        task.wait(0.05)
        RoadworkFarm:PurgeZones()
    end
end)



local Restock = {
    Active = false,
    ActiveSpots = {},
    SpotsToRestock = {},
    Connection = nil
}

function Restock:WalkTo(targetPos)
    local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
    local Controls = PlayerModule:GetControls()
    
    Controls:Disable()
    
    local function computePath(start, finish)
        local path = PathfindingService:CreatePath({
            AgentRadius = 3,
            AgentHeight = 6,
            AgentCanJump = true,
            WaypointSpacing = 4
        })
        
        local ok = pcall(function() path:ComputeAsync(start, finish) end)
        if ok and path.Status == Enum.PathStatus.Success then
            return path:GetWaypoints()
        end
        return nil
    end
    
    local waypoints = computePath(RootPart.Position, targetPos) or 
                     {{Position = targetPos, Action = Enum.PathWaypointAction.Walk}}
    
    local idx, lastPos, lastCheck = 1, RootPart.Position, os.clock()
    
    while idx <= #waypoints and self.Active do
        local wp = waypoints[idx]
        local currentPos = RootPart.Position
        local targetFlat = Vector3.new(wp.Position.X, currentPos.Y, wp.Position.Z)
        local dist = (currentPos - targetFlat).Magnitude
        
        if dist <= 1.5 then
            idx = idx + 1
        else
            LocalPlayer:Move((targetFlat - currentPos).Unit, false)
            
            if wp.Action == Enum.PathWaypointAction.Jump then
                Humanoid.Jump = true
            end
            
            if os.clock() - lastCheck > 1.5 then
                if (RootPart.Position - lastPos).Magnitude < 1.5 then
                    Humanoid.Jump = true
                    waypoints = computePath(RootPart.Position, targetPos) or waypoints
                    idx = 1
                end
                lastPos = RootPart.Position
                lastCheck = os.clock()
            end
        end
        
        RunService.Heartbeat:Wait()
    end
    
    LocalPlayer:Move(Vector3.zero, false)
    Controls:Enable()
end

function Restock:Interact(part)
    local cd = part:FindFirstChildOfClass("ClickDetector")
    if not cd then return end
    
    RootPart.CFrame = CFrame.new(
        RootPart.Position, 
        Vector3.new(part.Position.X, RootPart.Position.Y, part.Position.Z)
    )
    task.wait(0.1)
    
    if (RootPart.Position - part.Position).Magnitude <= cd.MaxActivationDistance then
        fireclickdetector(cd, 0)
        task.wait(0.5)
    end
end

function Restock:Start()
    self.Active = true
    self.ActiveSpots = {}
    self.SpotsToRestock = {}
    
    local GamePackets = require(ReplicatedStorage:WaitForChild("GamePackets"))
    
    if self.Connection then
        self.Connection:Disconnect()
    end
    
    self.Connection = GamePackets.JobsClientPush.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" or data[1] ~= "Stocker" then return end
        
        local action = data[2]
        
        if action == "BoxPickedUp" then
            self.ActiveSpots = data[3] or {}
            self.SpotsToRestock = {}
            for _, spot in pairs(self.ActiveSpots) do
                if spot and spot.Parent then
                    table.insert(self.SpotsToRestock, spot)
                end
            end
            
        elseif action == "SpotUsed" then
            local idx = data[3]
            if idx then
                local spot = self.ActiveSpots[idx]
                self.ActiveSpots[idx] = nil
                
                for i = #self.SpotsToRestock, 1, -1 do
                    if self.SpotsToRestock[i] == spot then
                        table.remove(self.SpotsToRestock, i)
                    end
                end
            end
            
        elseif action == "EndJob" then
            self.ActiveSpots = {}
            self.SpotsToRestock = {}
        end
    end)
    
    task.spawn(function()
        local stockBox = Workspace.Jobs.Restock.JLF:WaitForChild("Stock")
        
        while self.Active do
            if (RootPart.Position - stockBox.Position).Magnitude > 100 then
                task.wait(5)
                continue
            end
            
            if LocalPlayer:GetAttribute("CurrentJob") ~= "Restocking" then
                GamePackets.JobsCommand:Fire({"Stocker"})
                task.wait(1.5)
            end
            
            if #self.SpotsToRestock == 0 then
                self:WalkTo(stockBox.Position)
                if not self.Active then break end
                task.wait(0.8)
                self:Interact(stockBox)
                
                local waitStart = os.clock()
                while #self.SpotsToRestock == 0 and os.clock() - waitStart < 4 do
                    task.wait(0.1)
                    if not self.Active then break end
                end
            end
            
            while #self.SpotsToRestock > 0 and self.Active do
                local closest, closestDist = nil, math.huge
                
                for _, spot in ipairs(self.SpotsToRestock) do
                    if spot and spot.Parent then
                        local dist = (RootPart.Position - spot.Position).Magnitude
                        if dist < closestDist then
                            closest, closestDist = spot, dist
                        end
                    end
                end
                
                if closest then
                    self:WalkTo(closest.Position)
                    if not self.Active then break end
                    task.wait(1.5)
                    self:Interact(closest)
                    task.wait(0.5)
                else
                    self.SpotsToRestock = {}
                end
            end
            
            task.wait(1)
        end
    end)
    
    task.spawn(function()
        local VirtualUser = game:GetService("VirtualUser")
        while self.Active do
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            task.wait(60)
        end
    end)
end

function Restock:Stop()
    self.Active = false
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self.ActiveSpots = {}
    self.SpotsToRestock = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
--  UI TABS
-- ═══════════════════════════════════════════════════════════════════════════

GUI:NavSection("TRAIN")
local TrainTab = GUI:CreateTab({name = "Train"})

TrainTab:Section({name = "Silent Roadwork"})

TrainTab:Slider({
    name = "Scan Speed",
    min = 0.02, max = 0.5, default = 0.08,
    suffix = "s",
    callback = function(v)
        RoadworkFarm.ScanSpeed = v
    end,
})

TrainTab:Slider({
    name = "Max Buy Distance",
    min = 10, max = 100, default = 30,
    suffix = " studs",
    callback = function(v)
        RoadworkFarm.MaxBuyDistance = v
    end,
})

TrainTab:Toggle({
    name = "Auto Buy (every 3.5s when in range)",
    default = true,
    callback = function(v)
        RoadworkFarm.AutoBuy = v
    end,
})

TrainTab:Toggle({
    name = "Silent Roadwork",
    description = "Auto-collect roadwork junk",
    default = false,
    callback = function(v)
        if v then
            RoadworkFarm:Start()
            GUI.notify("Started", "Silent Roadwork active", 2, "success")
        else
            RoadworkFarm:Stop()
            GUI.notify("Stopped", "Roadwork halted", 2)
        end
    end,
})

TrainTab:Section({name = "Stat Selection"})

local StatLabel = nil

local function UpdateStatLabel()
    if StatLabel then
        local newText = "Current: " .. RoadworkFarm.SelectedStat
        pcall(function()
            if StatLabel.SetText then
                StatLabel:SetText(newText)
            elseif StatLabel.Update then
                StatLabel:Update({text = newText})
            elseif StatLabel.text then
                StatLabel.text = newText
            end
        end)
    end
end

StatLabel = TrainTab:Label({text = "Current: Stamina"})

TrainTab:ButtonGrid({
    columns = 2,
    buttons = {
        {
            name = "Stamina",
            callback = function()
                RoadworkFarm.SelectedStat = "Stamina"
                UpdateStatLabel()
                GUI.notify("Stat", "Using: Stamina", 2)
            end
        },
        {
            name = "Agility",
            callback = function()
                RoadworkFarm.SelectedStat = "Agility"
                UpdateStatLabel()
                GUI.notify("Stat", "Using: Agility", 2)
            end
        },
    }
})

TrainTab:Separator()
TrainTab:Label({text = "Stat selection only works at machines"})

-- ═══════════════════════════════════════════════════════════════════════════
--  JOBS TAB
-- ═══════════════════════════════════════════════════════════════════════════

GUI:NavSection("JOBS")
local JobsTab = GUI:CreateTab({name = "Jobs"})

JobsTab:Section({name = "Auto Restock Job"})

JobsTab:Toggle({
    name = "Auto Restock",
    description = "Automatically restock shelves at JLF",
    default = false,
    callback = function(v)
        if v then
            Restock:Start()
            GUI.notify("Started", "Auto Restock active", 2, "success")
        else
            Restock:Stop()
            GUI.notify("Stopped", "Auto Restock halted", 2)
        end
    end,
})

JobsTab:Separator()
JobsTab:Label({text = "📍 Requires JLF proximity"})
JobsTab:Label({text = "🎯 Uses smart pathfinding"})

-- ═══════════════════════════════════════════════════════════════════════════
--  MISC TAB
-- ═══════════════════════════════════════════════════════════════════════════

GUI:NavSection("MISC")
local MiscTab = GUI:CreateTab({name = "Misc", icon = "🔧"})

MiscTab:Section({name = "Info"})
MiscTab:Label({text = "Optimized v4.2 • Boxing Gym Safety"})
MiscTab:Label({text = "Game: [🔥RELEASE] KEN"})
MiscTab:Chip({text = "STABLE", color = Color3.fromRGB(60, 200, 100), icon = "✅"})

MiscTab:Section({name = "Controls"})
MiscTab:ControlHint({name = "Toggle UI", key = "Insert"})
MiscTab:ControlHint({name = "Minimize UI", key = "K"})

MiscTab:Section({name = "Utilities"})
MiscTab:ButtonGrid({
    columns = 2,
    buttons = {
        {
            name = "Copy UserId",
            icon = "📋",
            callback = function()
                setclipboard(tostring(LocalPlayer.UserId))
                GUI.notify("Copied", "UserId: " .. LocalPlayer.UserId, 2, "success")
            end
        },
        {
            name = "Rejoin",
            icon = "🔄",
            callback = function()
                game:GetService("TeleportService"):Teleport(game.PlaceId)
            end
        },
    }
})

task.delay(2, function()
    GUI.notify("Jobs & Farming Hub", "Loaded! Press Insert to toggle", 4, "success")
end)