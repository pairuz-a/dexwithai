local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- ============================================================
local existing = PlayerGui:FindFirstChild("PapapaikumGUI")
if existing then existing:Destroy() end

-- ============================================================
-- ============================================================
local scriptActive = false
local scriptThread = nil
local afkThread = nil

_G.PapapaikumActiveSpots = _G.PapapaikumActiveSpots or {}
_G.PapapaikumSpotsToRestock = _G.PapapaikumSpotsToRestock or {}

-- ============================================================
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PapapaikumGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 110)
MainFrame.Position = UDim2.new(0, 16, 0.5, -55)
MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 2
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 8)
TopCorner.Parent = TopBar

local TopBarFix = Instance.new("Frame")
TopBarFix.Size = UDim2.new(1, 0, 0, 8)
TopBarFix.Position = UDim2.new(0, 0, 1, -8)
TopBarFix.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TopBarFix.BorderSizePixel = 0
TopBarFix.ZIndex = 2
TopBarFix.Parent = TopBar

local AccentLine = Instance.new("Frame")
AccentLine.Name = "AccentLine"
AccentLine.Size = UDim2.new(1, 0, 0, 2)
AccentLine.Position = UDim2.new(0, 0, 0, 32)
AccentLine.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
AccentLine.BorderSizePixel = 0
AccentLine.ZIndex = 3
AccentLine.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, -12, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "PAPAPAIKUM"
TitleLabel.TextColor3 = Color3.fromRGB(220, 210, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 3
TitleLabel.Parent = TopBar

local SubLabel = Instance.new("TextLabel")
SubLabel.Name = "Sub"
SubLabel.Size = UDim2.new(1, -12, 1, 0)
SubLabel.Position = UDim2.new(0, 12, 0, 0)
SubLabel.BackgroundTransparency = 1
SubLabel.Text = "Restock Auto"
SubLabel.TextColor3 = Color3.fromRGB(110, 100, 160)
SubLabel.Font = Enum.Font.Gotham
SubLabel.TextSize = 10
SubLabel.TextXAlignment = Enum.TextXAlignment.Right
SubLabel.ZIndex = 3
SubLabel.Parent = TopBar

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Size = UDim2.new(1, -16, 0, 20)
StatusLabel.Position = UDim2.new(0, 8, 0, 42)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "● IDLE"
StatusLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 2
StatusLabel.Parent = MainFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(1, -16, 0, 34)
ToggleBtn.Position = UDim2.new(0, 8, 0, 66)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 130)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "START"
ToggleBtn.TextColor3 = Color3.fromRGB(210, 200, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 13
ToggleBtn.AutoButtonColor = false
ToggleBtn.ZIndex = 2
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

-- Outer border/stroke on button
local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(90, 60, 200)
BtnStroke.Thickness = 1
BtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
BtnStroke.Parent = ToggleBtn

-- ============================================================
-- ============================================================
local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tweenBtnOn()
    TweenService:Create(ToggleBtn, tweenInfo, {
        BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    }):Play()
    TweenService:Create(BtnStroke, tweenInfo, {
        Color = Color3.fromRGB(60, 200, 110)
    }):Play()
    TweenService:Create(AccentLine, tweenInfo, {
        BackgroundColor3 = Color3.fromRGB(60, 200, 110)
    }):Play()
    StatusLabel.Text = "● RUNNING"
    StatusLabel.TextColor3 = Color3.fromRGB(60, 200, 110)
    ToggleBtn.Text = "STOP"
end

local function tweenBtnOff()
    TweenService:Create(ToggleBtn, tweenInfo, {
        BackgroundColor3 = Color3.fromRGB(60, 40, 130)
    }):Play()
    TweenService:Create(BtnStroke, tweenInfo, {
        Color = Color3.fromRGB(90, 60, 200)
    }):Play()
    TweenService:Create(AccentLine, tweenInfo, {
        BackgroundColor3 = Color3.fromRGB(90, 60, 200)
    }):Play()
    StatusLabel.Text = "● IDLE"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
    ToggleBtn.Text = "START"
end

-- ============================================================
-- ============================================================
ToggleBtn.MouseEnter:Connect(function()
    if not scriptActive then
        TweenService:Create(ToggleBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(75, 55, 155)
        }):Play()
    else
        TweenService:Create(ToggleBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(35, 130, 65)
        }):Play()
    end
end)

ToggleBtn.MouseLeave:Connect(function()
    if not scriptActive then
        TweenService:Create(ToggleBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(60, 40, 130)
        }):Play()
    else
        TweenService:Create(ToggleBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(40, 160, 80)
        }):Play()
    end
end)

-- ============================================================
-- ============================================================
local function runRestockScript()
    local Players2 = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService2 = game:GetService("RunService")
    local PathfindingService = game:GetService("PathfindingService")

    local LocalPlayer2 = Players2.LocalPlayer
    local Character = LocalPlayer2.Character or LocalPlayer2.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Character:WaitForChild("HumanoidRootPart")

    local GamePackets = require(ReplicatedStorage:WaitForChild("GamePackets"))

    local PlayerScripts = LocalPlayer2:WaitForChild("PlayerScripts")
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
                LocalPlayer2:Move(direction, false)

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
            RunService2.Heartbeat:Wait()
        end

        LocalPlayer2:Move(Vector3.new(0, 0, 0), false)
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
                warn("Too far to click! Distance: " .. tostring(distance) .. " (Max: " .. tostring(cd.MaxActivationDistance) .. ")")
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

        local currentJob = LocalPlayer2:GetAttribute("CurrentJob")
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

-- ============================================================
-- ============================================================
ToggleBtn.MouseButton1Click:Connect(function()
    scriptActive = not scriptActive

    if scriptActive then
        _G.StopRestock = nil
        tweenBtnOn()

        local VirtualUser = game:GetService("VirtualUser")
        afkThread = task.spawn(function()
            while scriptActive do
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
                task.wait(60)
            end
        end)

        scriptThread = task.spawn(function()
            local ok, err = pcall(runRestockScript)
            if not ok then
                warn("Restock script error: " .. tostring(err))
                scriptActive = false
                tweenBtnOff()
                if afkThread then task.cancel(afkThread) afkThread = nil end
            end
        end)
    else
        _G.StopRestock = true
        task.wait(0.5)
        _G.StopRestock = nil
        tweenBtnOff()
        if scriptThread then
            task.cancel(scriptThread)
            scriptThread = nil
        end
        if afkThread then
            task.cancel(afkThread)
            afkThread = nil
        end
    end
end)

print("[Papapaikum] GUI loaded. Drag the window to reposition.")