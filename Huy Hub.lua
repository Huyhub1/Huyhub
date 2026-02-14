local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "One Tap PvP",
    SubTitle = "by Gemini",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "swords" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "settings-2" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Variables
local _AIMBOT_ENABLED = false
local _AIMBOT_KEY = Enum.UserInputType.MouseButton1
local _AIMBOT_SMOOTHNESS = 2 -- Lowered for snappier feel (2 is fast but smoothish)
local _AIMBOT_FOV = 100
local _AIMBOT_TARGET_PART = "Head"
local _AIMBOT_VIS_CHECK = false -- OFF by default to ensure it works first
local _AIMBOT_FIRING = false -- Track input state

local _TRIGGERBOT_ENABLED = false
local _TRIGGERBOT_DELAY = 0.1



local _ESP_ENABLED = false
local _ESP_BOX = false
local _ESP_TRACERS = false
local _ESP_NAME = false
local _ESP_TEAM_CHECK = true

-- FOV Circle Removed as per request
-- local FOVCircle = Drawing.new("Circle") ...

-- Utils
-- Input Tracker to replace unreliable IsKeyDown/IsMouseButtonPressed loop checks
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.UserInputType == _AIMBOT_KEY or input.KeyCode == _AIMBOT_KEY then
            _AIMBOT_FIRING = true
        end
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        _AIMBOT_FIRING = true -- Always track Left Click for firing context if needed
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == _AIMBOT_KEY or input.KeyCode == _AIMBOT_KEY then
        _AIMBOT_FIRING = false
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
       if _AIMBOT_KEY == Enum.UserInputType.MouseButton1 then _AIMBOT_FIRING = false end
    end
end)

local function IsFiring()
    return _AIMBOT_FIRING
end

local function IsTeammate(plr)
    if not _ESP_TEAM_CHECK then return false end
    if LocalPlayer.Team and plr.Team then
        return LocalPlayer.Team == plr.Team
    end
    return false
end

local function IsVisible(targetPart)
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local raycastParams = RaycastParams.new()
    
    local filter = {Camera}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    
    raycastParams.FilterDescendantsInstances = filter
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = Workspace:Raycast(origin, direction, raycastParams)
    if result then
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end
    -- If nil, probably nothing blocked
    return true
end

local function GetClosestPlayer()
    local closest = nil
    local shortestDistance = math.huge
    local center = Camera.ViewportSize / 2 + game:GetService("GuiService"):GetGuiInset()
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            if IsTeammate(plr) then continue end
            
            local part = plr.Character:FindFirstChild(_AIMBOT_TARGET_PART) or plr.Character:FindFirstChild("Head")
            if part then
                -- [LEGIT] Visibility Check
                if _AIMBOT_VIS_CHECK and not IsVisible(part) then
                    continue
                end
                
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < shortestDistance and dist <= _AIMBOT_FOV then
                        shortestDistance = dist
                        closest = part
                    end
                end
            end
        end
    end
    return closest
end

-- UI - Combat
local AimbotToggle = Tabs.Combat:AddToggle("Aimbot", {Title = "Legit Aimbot (Aim on Fire)", Default = false })
AimbotToggle:OnChanged(function()
    _AIMBOT_ENABLED = Options.Aimbot.Value
end)

Tabs.Combat:AddKeybind("AimbotKey", {
    Title = "Aimbot Key",
    Mode = "Hold",
    Default = "MouseButton1", -- Left Click
    Callback = function(Value)
        -- Handled in loop
    end,
    ChangedCallback = function(New)
        _AIMBOT_KEY = New
        _AIMBOT_FIRING = false -- Reset state on key change
    end
})

 Tabs.Combat:AddSlider("AimbotFOV", {
    Title = "Aimbot FOV (Radius)",
    Default = 100,
    Min = 10,
    Max = 800,
    Rounding = 0,
    Callback = function(Value)
        _AIMBOT_FOV = Value
    end
})

Tabs.Combat:AddSlider("AimbotSmoothness", {
    Title = "Smoothness (Lower = Snappier)",
    Default = 2,
    Min = 1, 
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
        _AIMBOT_SMOOTHNESS = Value
    end
})

Tabs.Combat:AddToggle("AimbotVisCheck", {Title = "Visibility Check (Wall Check)", Default = false }):OnChanged(function(v) _AIMBOT_VIS_CHECK = v end)



local TriggerBotToggle = Tabs.Combat:AddToggle("TriggerBot", {Title = "TriggerBot", Default = false })
TriggerBotToggle:OnChanged(function() _TRIGGERBOT_ENABLED = Options.TriggerBot.Value end)




-- UI - Visuals
local ESPToggle = Tabs.Visuals:AddToggle("ESP", {Title = "ESP Master Switch", Default = false })
ESPToggle:OnChanged(function() _ESP_ENABLED = Options.ESP.Value end)

Tabs.Visuals:AddToggle("ESPBox", {Title = "Box ESP", Default = false }):OnChanged(function(v) _ESP_BOX = v end)
Tabs.Visuals:AddToggle("ESPName", {Title = "Name ESP", Default = false }):OnChanged(function(v) _ESP_NAME = v end)
Tabs.Visuals:AddToggle("ESPTracers", {Title = "Tracers", Default = false }):OnChanged(function(v) _ESP_TRACERS = v end)
Tabs.Visuals:AddToggle("ESPTeamCheck", {Title = "Team Check", Default = true }):OnChanged(function(v) _ESP_TEAM_CHECK = v end)


-- Logic Loops

-- ESP Logic (Drawing API preferred for PvP, but using BillboardGui for compatibility/simplicity based on previous script style)
-- For "One Tap" style, high performance Drawing API is better, but let's stick to Highlight/Billboard for robustness across executors unless Drawing is required.
-- Let's use Drawing API tracers if available, otherwise fallback.
-- Legacy Highlight/Billboard ESP Removed for pure Drawing API (Performance + 2D Look)
-- local function AddESP(plr) ... end


RunService.RenderStepped:Connect(function()
    -- FOV Circle Removed
    -- FOVCircle.Position = ...
    
    -- Aimbot Logic (Legit Camera Smooth)
    if _AIMBOT_ENABLED and IsFiring() then 
        local target = GetClosestPlayer()
        if target then
             local camera = Workspace.CurrentCamera
             local targetPos = target.Position
             
             -- Smooth Aim
             local currentCFrame = camera.CFrame
             local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
             
             -- [LEGIT] Only affect camera if holding fire AND target is valid
             -- Uses Slerp/Lerp for natural feel
             camera.CFrame = currentCFrame:Lerp(targetCFrame, 1 / (_AIMBOT_SMOOTHNESS * 2))
        end
    end
    
    -- TRACERS Logic
    -- Tracers now handled in Unified ESP Render
end)

-- ESP Cache
local EspCache = {}

local function UpdateESPRender()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        if not EspCache[plr] then
            EspCache[plr] = {
                Box = Drawing.new("Square"),
                Tracer = Drawing.new("Line"),
                Name = Drawing.new("Text")
            }
            
            -- Setup defaults
            EspCache[plr].Box.Visible = false
            EspCache[plr].Box.Color = Color3.fromRGB(255, 0, 0)
            EspCache[plr].Box.Thickness = 1
            EspCache[plr].Box.Filled = false
            
            EspCache[plr].Tracer.Visible = false
            EspCache[plr].Tracer.Color = Color3.fromRGB(255, 0, 0)
            EspCache[plr].Tracer.Thickness = 1
            
            EspCache[plr].Name.Visible = false
            EspCache[plr].Name.Color = Color3.fromRGB(255, 255, 255)
            EspCache[plr].Name.Size = 13
            EspCache[plr].Name.Center = true
            EspCache[plr].Name.Outline = true
        end

        local esp = EspCache[plr]
        local char = plr.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        local show = _ESP_ENABLED and char and hum and hrp and hum.Health > 0 and (not IsTeammate(plr))
        
        if show then
            local Vector, OnScreen = Camera:WorldToViewportPoint(hrp.Position)
            
            if OnScreen then
                -- BOX Logic
                if _ESP_BOX then
                    local Size = (Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0)).Y - Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.6, 0)).Y) / 2
                    local BoxSize = Vector2.new(math.floor(Size * 1.5), math.floor(Size * 1.9))
                    local BoxPos = Vector2.new(math.floor(Vector.X - Size * 1.5 / 2), math.floor(Vector.Y - Size * 1.6 / 2))
                    
                    esp.Box.Size = BoxSize
                    esp.Box.Position = BoxPos
                    esp.Box.Visible = true
                    esp.Box.Color = Color3.fromRGB(255, 0, 0)
                else
                    esp.Box.Visible = false
                end
                
                -- TRACER Logic
                if _ESP_TRACERS then
                    esp.Tracer.Visible = true
                    esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, game:GetService("GuiService"):GetGuiInset().Y) -- Top Center
                    esp.Tracer.To = Vector2.new(Vector.X, Vector.Y)
                else
                    esp.Tracer.Visible = false
                end
                
                -- NAME Logic
                if _ESP_NAME then
                    esp.Name.Visible = true
                    esp.Name.Text = plr.Name .. " [" .. math.floor(hum.Health) .. "]"
                    esp.Name.Position = Vector2.new(Vector.X, Vector.Y + (esp.Box.Size.Y / 2) + 5)
                else
                   esp.Name.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Tracer.Visible = false
                esp.Name.Visible = false
            end
        else
            esp.Box.Visible = false
            esp.Tracer.Visible = false
            esp.Name.Visible = false
        end
    end
end

RunService.RenderStepped:Connect(UpdateESPRender)
-- Cleanup on player remove (Optional but good practice)
Players.PlayerRemoving:Connect(function(plr)
    if EspCache[plr] then
        for _, d in pairs(EspCache[plr]) do d:Remove() end
        EspCache[plr] = nil
    end
end)


-- UI Toggle Button
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GeminiPvPToggle"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
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
    if Window then
        Window:Minimize()
    end
end)

local AimbotBtn = Instance.new("TextButton")
AimbotBtn.Parent = ScreenGui
AimbotBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AimbotBtn.Position = UDim2.new(0, 10, 0.5, 35) -- Below Menu Toggle
AimbotBtn.Size = UDim2.new(0, 50, 0, 50)
AimbotBtn.Text = "AIM"
AimbotBtn.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red when off
AimbotBtn.TextSize = 12
AimbotBtn.Font = Enum.Font.GothamBold
AimbotBtn.BorderSizePixel = 0
AimbotBtn.BackgroundTransparency = 0.5

local UICorner2 = Instance.new("UICorner")
UICorner2.CornerRadius = UDim.new(0, 10)
UICorner2.Parent = AimbotBtn

AimbotBtn.MouseButton1Click:Connect(function()
    _AIMBOT_ENABLED = not _AIMBOT_ENABLED
    if Options.Aimbot then Options.Aimbot:SetValue(_AIMBOT_ENABLED) end
    
    if _AIMBOT_ENABLED then
        AimbotBtn.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green when on
    else
        AimbotBtn.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- Sync Aimbot Button Color with State
RunService.RenderStepped:Connect(function()
    if _AIMBOT_ENABLED then
        AimbotBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        AimbotBtn.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- SaveManager Setup
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentOneTapPvP")
SaveManager:SetFolder("FluentOneTapPvP/specific-game")

SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

Window:SelectTab(1)
Fluent:Notify({Title = "One Tap PvP", Content = "Script Loaded Successfully!", Duration = 5})
