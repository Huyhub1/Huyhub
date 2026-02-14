local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Harbor Havoc Farm",
    SubTitle = "by Gemini",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "home" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- Logic Variables
local Players = game:GetService("Players")
local Player = Players.LocalPlayer -- May be nil initially, handled in loops
local Workspace = game:GetService("Workspace")

local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local _DELAY = 0.1
local _FARM_SPEED = 50
local _TARGET_NAME = "Crate"
local _AUTO_FARM = false
local _FARMING_LOOP_RUNNING = false

-- Hitbox & ESP Variables
local _HITBOX_ENABLED = false
local _HITBOX_SIZE = 10
local _ESP_ENABLED = false
local _ESP_TEAMS_CHECK = true

-- Anti-Ban Utility
local function RandomWait()
    task.wait(math.random(100, 300) / 1000) -- 0.1s to 0.3s
end

local _MAP_CONFIG = {
    ["INSERT_MAP_NAME_HERE"] = CFrame.new(-21.732532501220703, -0.21339955925941467, -1074.5548095703125),
    ["Map_Default"] = CFrame.new(0, 50, 0)
}

-- UI Elements
local ToggleAutoFarm = Tabs.Main:AddToggle("AutoFarm", {Title = "Auto Farm", Default = false })
local InputTarget = Tabs.Main:AddInput("TargetName", {
    Title = "Target Name",
    Default = "Crate",
    Placeholder = "Enter item name...",
    Numeric = false,
    Finished = true,
    Callback = function(Value)
        _TARGET_NAME = Value
    end
})

local StatusParagraph = Tabs.Main:AddParagraph({
    Title = "Status",
    Content = "Idle"
})



Tabs.Main:AddButton({
    Title = "Teleport to Map",
    Description = "Teleport to known map center",
    Callback = function()
        local function CheckMap()
            for name, cords in pairs(_MAP_CONFIG) do
                if Workspace:FindFirstChild(name) then return name, cords end
            end
            return nil, nil
        end
        local mapName, mapCFrame = CheckMap()
        if mapName then
            local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                TS:Create(root, TweenInfo.new((root.Position - mapCFrame.Position).Magnitude / _FARM_SPEED, Enum.EasingStyle.Linear), {CFrame = mapCFrame}):Play()
            end
        else
            Fluent:Notify({Title = "Error", Content = "Map not found!", Duration = 3})
        end
    end
})

Tabs.Main:AddButton({
    Title = "Server Hop",
    Description = "Find a smaller server",
    Callback = function()
        local TPS = game:GetService("TeleportService")
        local Api = "https://games.roblox.com/v1/games/"
        local _place, _id = game.PlaceId, game.JobId
        local _servers = Api .. _place .. "/servers/Public?sortOrder=Asc&limit=100"
        local function ListServers(cursor)
            local Raw = game:HttpGet(_servers .. ((cursor and "&cursor=" .. cursor) or ""))
            return HttpService:JSONDecode(Raw)
        end
        local Server, Next = nil, nil
        local success, err = pcall(function()
            repeat
                local Servers = ListServers(Next)
                for _, v in pairs(Servers.data) do
                    if v.playing < v.maxPlayers and v.id ~= _id then
                        Server = v
                        break
                    end
                end
                Next = Servers.nextPageCursor
            until Server or not Next
        end)
        if success and Server then
            TPS:TeleportToPlaceInstance(_place, Server.id, game.Players.LocalPlayer)
        end
    end
})

ToggleAutoFarm:OnChanged(function()
    _AUTO_FARM = Options.AutoFarm.Value
    if _AUTO_FARM then
        StartFarmingLoop()
    end
end)

-- Combat UI
local ToggleHitbox = Tabs.Combat:AddToggle("Hitbox", {Title = "Hitbox Expander (Auto Hit)", Default = false })
ToggleHitbox:OnChanged(function()
    _HITBOX_ENABLED = Options.Hitbox.Value
end)

Tabs.Combat:AddSlider("HitboxSize", {
    Title = "Hitbox Size",
    Description = "Expand enemy hitbox size",
    Default = 10,
    Min = 2,
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
        _HITBOX_SIZE = Value
    end
})

local ToggleESP = Tabs.Combat:AddToggle("ESP", {Title = "ESP (Wallhack)", Default = false })
ToggleESP:OnChanged(function()
    _ESP_ENABLED = Options.ESP.Value
end)

Tabs.Combat:AddToggle("ESPTeamCheck", {Title = "ESP Team Check", Default = true }):OnChanged(function(val)
    _ESP_TEAMS_CHECK = val
end)


-- Logic Functions
-- [ANTI-AFK]
task.spawn(function()
    Player.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end)



-- Combat Logic
local function IsTeammate(plr)
    if Player.Team and plr.Team then
        return Player.Team == plr.Team
    end
    return false
end

-- Shared Function to Create ESP
local function CreateESP(plr)
    if not plr.Character then return end
    
    -- Highlight
    if not plr.Character:FindFirstChild("GeminiESP") then
        local hl = Instance.new("Highlight")
        hl.Name = "GeminiESP"
        hl.Adornee = plr.Character
        hl.FillColor = Color3.fromRGB(255, 0, 0)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Parent = plr.Character
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- [FIX] See through walls/vehicles
    end
    
    -- Text Info
    if not plr.Character:FindFirstChild("GeminiInfo") and plr.Character:FindFirstChild("Head") then
        local bg = Instance.new("BillboardGui")
        bg.Name = "GeminiInfo"
        bg.Adornee = plr.Character.Head
        bg.Size = UDim2.new(0, 100, 0, 50)
        bg.StudsOffset = Vector3.new(0, 2, 0)
        bg.AlwaysOnTop = true
        
        local text = Instance.new("TextLabel")
        text.Parent = bg
        text.BackgroundTransparency = 1
        text.Size = UDim2.new(1, 0, 1, 0)
        text.TextStrokeTransparency = 0
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextSize = 12
        text.Font = Enum.Font.SourceSansBold
        text.Text = plr.Name
        bg.Parent = plr.Character
        
        -- Health Loop
        task.spawn(function()
            while plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character:FindFirstChild("GeminiInfo") do
                local hum = plr.Character.Humanoid
                text.Text = plr.Name .. "\n[" .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. "]"
                if IsTeammate(plr) then
                     text.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green for Friend
                     hl.FillColor = Color3.fromRGB(0, 255, 0)
                else
                     text.TextColor3 = Color3.fromHSV((hum.Health/hum.MaxHealth)*0.3, 1, 1) -- Red/Orange for Enemy
                     hl.FillColor = Color3.fromRGB(255, 0, 0)
                end
                task.wait(0.5)
            end
        end)
    end
end

-- UI Toggle Button
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GeminiToggle"
ScreenGui.Parent = Player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleBtn.Position = UDim2.new(0, 10, 0.5, -25)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Text = "MENU"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 12
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.BorderSizePixel = 0
ToggleBtn.BackgroundTransparency = 0.5

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = ToggleBtn

ToggleBtn.MouseButton1Click:Connect(function()
    local lib = game:GetService("CoreGui"):FindFirstChild("ScreenGui")
    -- Fluent uses internal state/MinimizeKey usually.
    -- Assuming we can just find the main Window frame if accessible, but Fluent is protected.
    -- Best way: Simulate Key Press or check if Library exposes Toggle.
    -- Inspecting Fluent source: Library:Toggle().
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
        task.wait()
        vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
    end)
end)

local function ClearESP(plr)
    if plr.Character then
        if plr.Character:FindFirstChild("GeminiESP") then plr.Character.GeminiESP:Destroy() end
        if plr.Character:FindFirstChild("GeminiInfo") then plr.Character.GeminiInfo:Destroy() end
    end
end

RunService.Heartbeat:Connect(function()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= Player and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            
            local isTeam = IsTeammate(plr)
            
            -- HITBOX EXPANDER
            if _HITBOX_ENABLED and (not isTeam or not _ESP_TEAMS_CHECK) then
                 local root = plr.Character:FindFirstChild("HumanoidRootPart")
                 if root then
                     root.Size = Vector3.new(_HITBOX_SIZE, _HITBOX_SIZE, _HITBOX_SIZE)
                     root.Transparency = 0.7
                     root.CanCollide = false
                 end
            elseif plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character.HumanoidRootPart.Size.X == _HITBOX_SIZE then
                 -- Revert size if disabled
                 plr.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                 plr.Character.HumanoidRootPart.Transparency = 1
            end
            
            -- ESP
            if _ESP_ENABLED and (not isTeam or not _ESP_TEAMS_CHECK) then
                CreateESP(plr)
            else
                ClearESP(plr)
            end
        end
    end
end)

local function GetCharacter() return Player.Character or Player.CharacterAdded:Wait() end
local function GetRoot() local char = GetCharacter() return char:WaitForChild("HumanoidRootPart", 5) end

local function FireTouch(part)
    local root = GetRoot()
    if root and part:IsA("BasePart") then
        firetouchinterest(root, part, 0)
        task.wait()
        firetouchinterest(root, part, 1)
    end
end

local function FirePrompt(instance)
    for _, v in pairs(instance:GetDescendants()) do
        if v:IsA("ProximityPrompt") then fireproximityprompt(v) return true end
    end
    return false
end

local function FireClick(instance)
    for _, v in pairs(instance:GetDescendants()) do
        if v:IsA("ClickDetector") then fireclickdetector(v) return true end
    end
    return false
end

local function AttemptInteract(target)
    if not target then return end
    if FirePrompt(target) then return end
    if FireClick(target) then return end
    if target:IsA("BasePart") then FireTouch(target)
    elseif target:IsA("Model") and target.PrimaryPart then FireTouch(target.PrimaryPart) end
end

local function FindNearestTarget()
    local root = GetRoot()
    if not root then return nil end
    local nearest = nil
    local minDist = math.huge
    local count = 0
    for _, obj in pairs(Workspace:GetDescendants()) do
        count = count + 1
        if count % 2000 == 0 then task.wait() end
        if obj.Name:find(_TARGET_NAME) and obj.Parent then
            local pos = nil
            if obj:IsA("BasePart") then pos = obj.Position end
            if obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position end
            if pos then
                local dist = (root.Position - pos).Magnitude
                if dist < minDist then minDist = dist nearest = obj end
            end
        end
    end
    return nearest
end

-- Anti-Ban Utilities
local function RandomWait()
    -- Random delay between 0.5s and 1.5s
    task.wait(math.random(500, 1500) / 1000)
end




-- [LOGIC] Farming Loop with Anti-Ban
function StartFarmingLoop()
    if _FARMING_LOOP_RUNNING then return end
    _FARMING_LOOP_RUNNING = true
    task.spawn(function()
        if not Player then Player = Players.LocalPlayer end
        local CurrentTarget = nil
        local FarmStartTime = os.time()
        
        while _AUTO_FARM do
             local success, err = pcall(function()
                local root = GetRoot()
                if not root then task.wait(1) return end
                
                -- [ANTI-BAN] Micro-Break every ~5 minutes
                if os.time() - FarmStartTime > 300 then
                    StatusParagraph:SetDesc("Status: Anti-Ban Break (5s)...")
                    task.wait(5)
                    FarmStartTime = os.time()
                end
                
                -- [LOGIC] Check if in Lobby/Menu
                local PlayerGui = Player:FindFirstChild("PlayerGui")
                local waitingForGame = false
                if PlayerGui then
                    local gui = PlayerGui:FindFirstChild("gui")
                    if gui then
                        if (gui:FindFirstChild("startMenu") and gui.startMenu.Visible) or
                           (gui:FindFirstChild("teamChoice") and gui.teamChoice.Visible) or
                           (gui:FindFirstChild("spawnChoice") and gui.spawnChoice.Visible) then
                            waitingForGame = true
                        end
                    end
                end
                
                if waitingForGame then
                    StatusParagraph:SetDesc("Status: Auto Joining...")
                    task.wait(1)
                else
                    if not CurrentTarget or not CurrentTarget.Parent then
                        StatusParagraph:SetDesc("Status: Scanning for " .. _TARGET_NAME .. "...")
                        CurrentTarget = FindNearestTarget()
                    end
                    
                    if CurrentTarget then
                        local targetPos = (CurrentTarget:IsA("BasePart") and CurrentTarget.Position) or (CurrentTarget:IsA("Model") and CurrentTarget.PrimaryPart and CurrentTarget.PrimaryPart.Position)
                        if targetPos then
                            StatusParagraph:SetDesc("Status: Moving to " .. CurrentTarget.Name)
                            

                            
                            local dist = (root.Position - targetPos).Magnitude
                            if dist > 5 then
                                local time = dist / _FARM_SPEED
                                local info = TweenInfo.new(time, Enum.EasingStyle.Linear)
                                local tween = TS:Create(root, info, {CFrame = CFrame.new(targetPos)})
                                tween:Play()
                                tween.Completed:Wait()
                            end

                            -- [ANTI-BAN] Random Delay if already close
                            RandomWait()
                            AttemptInteract(CurrentTarget)
                        else
                            CurrentTarget = nil
                        end
                    else
                        task.wait(1)
                    end
                end
            end)
            if not success then task.wait(1) end
            task.wait(0.1)
        end
        _FARMING_LOOP_RUNNING = false
        StatusParagraph:SetDesc("Status: Idle")
    end)
end


local function GameLoop()
    while true do
        pcall(function()
            task.wait(2)
            local PlayerGui = Player:FindFirstChild("PlayerGui")
            if not PlayerGui then return end
            
            local gui = PlayerGui:FindFirstChild("gui")
            if gui then
                local startMenu = gui:FindFirstChild("startMenu")
                if startMenu and startMenu.Visible then
                    local windows = startMenu:FindFirstChild("windows")
                    if windows then
                        local play = windows:FindFirstChild("play")
                        if play then
                            local playFrame = play:FindFirstChild("playFrame")
                            if playFrame and playFrame.Visible then
                                VirtualUser:CaptureController()
                                VirtualUser:ClickButton1(Vector2.new(playFrame.AbsolutePosition.X + playFrame.AbsoluteSize.X/2, playFrame.AbsolutePosition.Y + playFrame.AbsoluteSize.Y/2))
                                task.wait(1)
                            end
                        end
                    end
                end
            end
            if gui then
                 local teamChoice = gui:FindFirstChild("teamChoice")
                 if teamChoice and teamChoice.Visible then
                     local options = teamChoice:FindFirstChild("options")
                     if options then
                        for _, v in pairs(options:GetChildren()) do
                            if v:IsA("ImageButton") and v.Name == "template" then
                                VirtualUser:CaptureController()
                                VirtualUser:ClickButton1(Vector2.new(v.AbsolutePosition.X + v.AbsoluteSize.X/2, v.AbsolutePosition.Y + v.AbsoluteSize.Y/2))
                                task.wait(1)
                                if not teamChoice.Visible then break end
                            end
                        end
                     end
                 end
            end
            if gui then
                local spawnChoice = gui:FindFirstChild("spawnChoice")
                if spawnChoice and spawnChoice.Visible then
                    local inputBar = spawnChoice:FindFirstChild("inputBar")
                    if inputBar and inputBar.Visible then
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton1(Vector2.new(inputBar.AbsolutePosition.X + inputBar.AbsoluteSize.X/2, inputBar.AbsolutePosition.Y + inputBar.AbsoluteSize.Y/2))
                        task.wait(1)
                    end
                end
            end
            if gui then
                local hud = gui:FindFirstChild("hud")
                if hud then
                    local winnerBanner = hud:FindFirstChild("winnerBanner")
                    if winnerBanner and winnerBanner.Visible then
                        local inside = winnerBanner:FindFirstChild("inside")
                        if inside then
                            local vote = inside:FindFirstChild("vote")
                            if vote and vote.Visible then
                                for _, v in pairs(vote:GetChildren()) do
                                    if v:IsA("ImageButton") and v.Name == "template" then
                                        VirtualUser:CaptureController()
                                        VirtualUser:ClickButton1(Vector2.new(v.AbsolutePosition.X + v.AbsoluteSize.X/2, v.AbsolutePosition.Y + v.AbsoluteSize.Y/2))
                                        task.wait(1)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

task.spawn(GameLoop)

Window:SelectTab(1)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")

SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Fluent:Notify({Title = "Harbor Havoc Farm", Content = "Script Loaded Successfully!", Duration = 5})
