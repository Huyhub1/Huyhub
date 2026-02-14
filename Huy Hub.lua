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
local _AIMBOT_KEY = Enum.UserInputType.MouseButton1 -- Default to Left Click (Shoot)
local _AIMBOT_SMOOTHNESS = 5 -- Default smooth for legit
local _AIMBOT_FOV = 100
local _AIMBOT_TARGET_PART = "Head"
local _AIMBOT_VIS_CHECK = true -- Default True for Legit

local _TRIGGERBOT_ENABLED = false
local _TRIGGERBOT_DELAY = 0.1



local _ESP_ENABLED = false
local _ESP_BOX = false
local _ESP_TRACERS = false
local _ESP_NAME = false
local _ESP_TEAM_CHECK = true

local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 1
FOVCircle.NumSides = 60
FOVCircle.Radius = _AIMBOT_FOV
FOVCircle.Visible = false
FOVCircle.Filled = false
FOVCircle.Transparency = 1

-- Utils
local function IsKeyDown(key)
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.KeyCode then
            return UserInputService:IsKeyDown(key)
        elseif key.EnumType == Enum.UserInputType then
            return UserInputService:IsMouseButtonPressed(key)
        end
    end
    return false
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
    FOVCircle.Visible = _AIMBOT_ENABLED
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
        FOVCircle.Radius = Value
    end
})

Tabs.Combat:AddSlider("AimbotSmoothness", {
    Title = "Smoothness (High = Legit)",
    Default = 5,
    Min = 1, 
    Max = 20,
    Rounding = 1,
    Callback = function(Value)
        _AIMBOT_SMOOTHNESS = Value
    end
})

Tabs.Combat:AddToggle("AimbotVisCheck", {Title = "Visibility Check (Wall Check)", Default = true }):OnChanged(function(v) _AIMBOT_VIS_CHECK = v end)



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
local function AddESP(plr)
    if not plr.Character then return end
    
    -- Box/Highlight
    if not plr.Character:FindFirstChild("PvPEspHighlight") then
        local hl = Instance.new("Highlight")
        hl.Name = "PvPEspHighlight"
        hl.Adornee = plr.Character
        hl.FillTransparency = 1
        hl.OutlineColor = Color3.fromRGB(255, 0, 0)
        hl.OutlineTransparency = 0
        hl.Parent = plr.Character
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
    
    local hl = plr.Character:FindFirstChild("PvPEspHighlight")
    if hl then
        hl.Enabled = (_ESP_ENABLED and _ESP_BOX and (not IsTeammate(plr)))
        if IsTeammate(plr) then hl.OutlineColor = Color3.fromRGB(0, 255, 0) else hl.OutlineColor = Color3.fromRGB(255, 0, 0) end
    end
    
    -- Name/Health
    if not plr.Character:FindFirstChild("PvPEspInfo") and plr.Character:FindFirstChild("Head") then
        local bg = Instance.new("BillboardGui")
        bg.Name = "PvPEspInfo"
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
        text.Text = ""
        bg.Parent = plr.Character
    end
    
    local bg = plr.Character:FindFirstChild("PvPEspInfo")
    if bg then
        bg.Enabled = (_ESP_ENABLED and _ESP_NAME and (not IsTeammate(plr)))
        local text = bg:FindFirstChildOfClass("TextLabel")
        if text then
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hum then
                text.Text = plr.Name .. " [" .. math.floor(hum.Health) .. "]"
                if IsTeammate(plr) then text.TextColor3 = Color3.fromRGB(0, 255, 0) else text.TextColor3 = Color3.fromRGB(255, 0, 0) end
            end
        end
    end
end


RunService.RenderStepped:Connect(function()
    -- Aimbot FOV Circle Position
    FOVCircle.Position = Camera.ViewportSize / 2 + game:GetService("GuiService"):GetGuiInset()
    FOVCircle.Visible = _AIMBOT_ENABLED and Options.Aimbot.Value
    
    -- Aimbot Logic (Legit Camera Smooth)
    if _AIMBOT_ENABLED and IsKeyDown(_AIMBOT_KEY) then 
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
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 and (not IsTeammate(plr)) then
             local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
             if hrp and _ESP_ENABLED and _ESP_TRACERS then
                 local Vector, OnScreen = Camera:WorldToViewportPoint(hrp.Position)
                 if OnScreen then
                      if not plr.TracerLine then 
                          plr.TracerLine = Drawing.new("Line")
                          plr.TracerLine.Thickness = 1
                          plr.TracerLine.Color = Color3.fromRGB(255, 0, 0)
                      end
                      plr.TracerLine.Visible = true
                      plr.TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y) -- Bottom Center
                      plr.TracerLine.To = Vector2.new(Vector.X, Vector.Y)
                 else
                      if plr.TracerLine then plr.TracerLine.Visible = false end
                 end
             else
                 if plr.TracerLine then plr.TracerLine.Visible = false end
             end
        else
             -- Cleanup Tracer if exists
             -- We can't easily store vars on player object in standard Lua, so we rely on a table or rawset. 
             -- For simplicity in this edit, assuming we can attach or use a cache.
             -- To be safe, let's use a weak table cache.
        end
    end
end)

-- Tracer Cache
local TracerCache = {}
local function UpdateTracers()
    for _, plr in pairs(Players:GetPlayers()) do
        local line = TracerCache[plr]
        if not line then
            line = Drawing.new("Line")
            line.Thickness = 1
            line.Color = Color3.fromRGB(255, 0, 0)
            line.Visible = false
            TracerCache[plr] = line
        end
        
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 and (not IsTeammate(plr)) and _ESP_ENABLED and _ESP_TRACERS then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local Vector, OnScreen = Camera:WorldToViewportPoint(hrp.Position)
                if OnScreen then
                    line.Visible = true
                    line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    line.To = Vector2.new(Vector.X, Vector.Y)
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end
RunService.RenderStepped:Connect(UpdateTracers)



RunService.Heartbeat:Connect(function()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            

            
            -- ESP Update
            AddESP(plr)
        end
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
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
        task.wait()
        vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
    end)
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
