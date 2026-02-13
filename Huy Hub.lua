local _DELAY = 0.1
local _FARM_SPEED = 50
local _TARGET_NAME = "Crate"
local _AUTO_FARM = false

local _MAP_CONFIG = {
    ["INSERT_MAP_NAME_HERE"] = CFrame.new(-21.732532501220703, -0.21339955925941467, -1074.5548095703125),
    ["Map_Default"] = CFrame.new(0, 50, 0)
}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

-- [ANTI-AFK]
Player.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

    return nil, nil
end

-- [APPLIED KNOWLEDGE]: Advanced Interaction Functions
local function FireTouch(part)
    local root = GetRoot()
    if root and part:IsA("BasePart") then
        firetouchinterest(root, part, 0) -- Touch
        task.wait()
        firetouchinterest(root, part, 1) -- Release
    end
end

local function FirePrompt(instance)
    for _, v in pairs(instance:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            fireproximityprompt(v)
            return true
        end
    end
    return false
end

local function FireClick(instance)
    for _, v in pairs(instance:GetDescendants()) do
        if v:IsA("ClickDetector") then
            fireclickdetector(v)
            return true
        end
    end
    return false
end

local function AttemptInteract(target)
    if not target then return end
    
    -- 1. Try ProximityPrompt (E key)
    if FirePrompt(target) then return end
    
    -- 2. Try ClickDetector (Mouse Click)
    if FireClick(target) then return end
    
    -- 3. Try Touch (Physical Touch)
    if target:IsA("BasePart") then
        FireTouch(target)
    elseif target:IsA("Model") and target.PrimaryPart then
        FireTouch(target.PrimaryPart)
    end
end

local function ServerHop()

local function ServerHop()
    local Http = game:GetService("HttpService")
    local TPS = game:GetService("TeleportService")
    local Api = "https://games.roblox.com/v1/games/"
    local _place, _id = game.PlaceId, game.JobId
    local _servers = Api .. _place .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local function ListServers(cursor)
        local Raw = game:HttpGet(_servers .. ((cursor and "&cursor=" .. cursor) or ""))
        return Http:JSONDecode(Raw)
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
    else
        return nil
    end
end

local function SendToHost(filename, data)
    local url = "http://localhost:3000/save"
    local timestamp = os.date("%H:%M:%S")
    local contentWithTime = "[" .. timestamp .. "] " .. data
    
    local body = HttpService:JSONEncode({
        filename = filename,
        content = contentWithTime,
        mode = "append"
    })
    
    local headers = {["Content-Type"] = "application/json"}
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    
    if req then
        pcall(function()
            req({Url = url, Method = "POST", Headers = headers, Body = body})
        end)
    end
end

local function LogError(msg)
    SendToHost("error.txt", "[ERROR]: " .. tostring(msg))
end

local _FARMING_LOOP_RUNNING = false

local function FindNearestTarget()
    local root = GetRoot()
    if not root then return nil end
    
    local nearest = nil
    local minDist = math.huge
    
    -- Optimize: Only scan Workspace, potentially specific folders if known
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == _TARGET_NAME and obj.Parent then -- Check .Parent to ensure it exists
            local pos = nil
            if obj:IsA("BasePart") then pos = obj.Position end
            if obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position end
            
            if pos then
                local dist = (root.Position - pos).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearest = obj
                end
            end
        end
    end
    return nearest
end

local function StartFarmingLoop()
    if _FARMING_LOOP_RUNNING then return end
    _FARMING_LOOP_RUNNING = true
    
    task.spawn(function()
        local CurrentTarget = nil
        
        while _AUTO_FARM do
             local success, err = pcall(function()
                local root = GetRoot()
                if not root then 
                    task.wait(1)
                    return 
                end
                
                -- [OPTIMIZATION]: Only scan if we don't have a valid target
                if not CurrentTarget or not CurrentTarget.Parent then
                    CurrentTarget = FindNearestTarget()
                end
                
                if CurrentTarget then
                     local targetPos = (CurrentTarget:IsA("BasePart") and CurrentTarget.Position) or (CurrentTarget:IsA("Model") and CurrentTarget.PrimaryPart and CurrentTarget.PrimaryPart.Position)
                    
                    if targetPos then
                        local dist = (root.Position - targetPos).Magnitude
                        
                        if dist > 5 then
                            local time = dist / _FARM_SPEED
                            local info = TweenInfo.new(time, Enum.EasingStyle.Linear)
                            local tween = TS:Create(root, info, {CFrame = CFrame.new(targetPos)})
                            tween:Play()
                            
                            -- While tweening, update target status
                            local tweenRunning = true
                            local checkConnection
                            checkConnection = game:GetService("RunService").Heartbeat:Connect(function()
                                if not _AUTO_FARM or not CurrentTarget or not CurrentTarget.Parent then
                                    tween:Cancel()
                                    tweenRunning = false
                                    checkConnection:Disconnect()
                                end
                                -- Attempt interact while moving
                                if CurrentTarget and (root.Position - targetPos).Magnitude < 10 then
                                     AttemptInteract(CurrentTarget)
                                end
                            end)
                            
                            tween.Completed:Wait()
                            if checkConnection then checkConnection:Disconnect() end
                        end
                        
                        -- Final attempt
                        AttemptInteract(CurrentTarget)
                    else
                         CurrentTarget = nil -- Invalid target
                    end
                else
                    task.wait(1) -- [OPTIMIZATION]: Wait longer when no targets found to save CPU
                end
            end)
            
            if not success then
                LogError("AutoFarm Error: " .. tostring(err))
                task.wait(1)
            end
            task.wait(0.1)
        end
        _FARMING_LOOP_RUNNING = false
    end)
end

local function GameLoop()
    while true do
        local success, err = pcall(function()
            task.wait(2)
            
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
        
        if not success then
            LogError("GameLoop Error: " .. tostring(err))
            task.wait(5)
        end
    end
end

task.spawn(GameLoop)

local function CreateElement(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end

local ScreenGui = CreateElement("ScreenGui", {Name = "Gemini_Harbor_Farm_Original", Parent = game.CoreGui, ResetOnSpawn = false})

local ToggleBtn = CreateElement("TextButton", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 80, 0, 30),
    Position = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = Color3.fromRGB(0, 150, 200),
    Text = "MỞ MENU (RC)",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.SourceSansBold,
    TextSize = 14,
    ZIndex = 10
})
CreateElement("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ToggleBtn})

local Main = CreateElement("Frame", {
    Parent = ScreenGui,
    BackgroundColor3 = Color3.fromRGB(25, 25, 25),
    BorderSizePixel = 0,
    Position = UDim2.new(0.02, 0, 0.4, 0),
    Size = UDim2.new(0, 200, 0, 300),
    Visible = false,
    Active = true,
    Draggable = true
})
CreateElement("UICorner", {CornerRadius = UDim.new(0, 8), Parent = Main})

local Title = CreateElement("TextLabel", {
    Parent = Main,
    Size = UDim2.new(1, 0, 0, 35),
    BackgroundColor3 = Color3.fromRGB(45, 45, 45),
    Text = "HARBOR AUTO FARM (VN)",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 12,
    Font = Enum.Font.SourceSansBold
})
CreateElement("UICorner", {CornerRadius = UDim.new(0, 8), Parent = Title})

local function ToggleMenu()
    Main.Visible = not Main.Visible
    ToggleBtn.Text = Main.Visible and "ĐÓNG MENU (RC)" or "MỞ MENU (RC)"
    ToggleBtn.BackgroundColor3 = Main.Visible and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(0, 150, 200)
    task.wait(_DELAY)
end

ToggleBtn.MouseButton1Click:Connect(ToggleMenu)

UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightControl then
        ToggleMenu()
    end
end)

local function GetCharacter()
    return Player.Character or Player.CharacterAdded:Wait()
end

local function GetRoot()
    local char = GetCharacter()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function TweenTo(cframe)
    local root = GetRoot()
    if not root then return end
    
    local dist = (root.Position - cframe.Position).Magnitude
    local time = dist / _FARM_SPEED
    
    local info = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local tween = TS:Create(root, info, {CFrame = cframe})
    tween:Play()
    tween.Completed:Wait()
end

local function AddFuncButton(text, color, pos, callback)
    local btn = CreateElement("TextButton", {
        Parent = Main,
        Text = text,
        Size = UDim2.new(0.9, 0, 0, 40),
        Position = pos,
        BackgroundColor3 = color,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13
    })
    CreateElement("UICorner", {CornerRadius = UDim.new(0, 6), Parent = btn})

    btn.MouseButton1Click:Connect(function()
        TS:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = Color3.fromRGB(0, 0, 0)}):Play()
        task.wait(0.1)
        TS:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = color, TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        
        task.wait(_DELAY)
        callback(btn)
    end)
    return btn
end

local InputBox = CreateElement("TextBox", {
    Parent = Main,
    Size = UDim2.new(0.9, 0, 0, 30),
    Position = UDim2.new(0.05, 0, 0.32, 0),
    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
    Text = _TARGET_NAME,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    PlaceholderText = "Nhập tên vật phẩm...",
    TextSize = 12
})
CreateElement("UICorner", {CornerRadius = UDim.new(0, 6), Parent = InputBox})
InputBox.FocusLost:Connect(function()
    _TARGET_NAME = InputBox.Text
end)

local FarmButton
FarmButton = AddFuncButton("🚜 Bắt Đầu Farm", Color3.fromRGB(0, 180, 100), UDim2.new(0.05, 0, 0.45, 0), function(btn)
    _AUTO_FARM = not _AUTO_FARM
    
    if _AUTO_FARM then
        btn.Text = "🛑 Dừng Farm"
        btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        StartFarmingLoop()
    else
        btn.Text = "🚜 Bắt Đầu Farm"
        btn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    end
end)
-- Add a loop to update button state externally (in case GameLoop toggles it)
task.spawn(function()
    while true do
        task.wait(0.5)
        if _AUTO_FARM then
            FarmButton.Text = "� Dừng Farm"
            FarmButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        else
            FarmButton.Text = "🚜 Bắt Đầu Farm"
            FarmButton.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        end
    end
end)

AddFuncButton("⚡ Tăng Tốc Độ", Color3.fromRGB(0, 100, 200), UDim2.new(0.05, 0, 0.65, 0), function()
    local char = GetCharacter()
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = 50
    end
end)

AddFuncButton("🏝️ TP Theo Map", Color3.fromRGB(0, 150, 150), UDim2.new(0.05, 0, 0.75, 0), function()
    local mapName, mapCFrame = CheckMap()
    if mapName then
        TweenTo(mapCFrame)
    else
    end
end)

AddFuncButton("🔀 Server Hop (Ít người)", Color3.fromRGB(150, 0, 150), UDim2.new(0.05, 0, 0.85, 0), function()
    ServerHop()
end)
