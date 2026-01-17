local Webhook_URL = "https://discord.com/api/webhooks/1462005180118601772/mPmggBSvvppiwCfLkN-3BBgV0CqMPDHsqA8qllgyzpJVewuAgxf_5orxitLXiu4BQykw" 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

local request_func = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

local function Notify(title, text)
    StarterGui:SetCore("SendNotification", {
        Title = title;
        Text = text;
        Duration = 5;
    })
end

Notify("Galaxy Checker", "Đang lấy dữ liệu tài khoản...")

local DataFolder = LocalPlayer:WaitForChild("Data", 20) 
local StatsFolder = LocalPlayer:WaitForChild("leaderstats", 20)

if not DataFolder or not StatsFolder then
    Notify("Lỗi", "Không tìm thấy dữ liệu Blox Fruit! (Có thể chưa vào game)")
    return
end

local Level = DataFolder:WaitForChild("Level").Value
local Beli = DataFolder:WaitForChild("Beli").Value
local Fragments = DataFolder:WaitForChild("Fragments").Value
local DevilFruit = DataFolder:WaitForChild("DemonFruit").Value 
local Bounty = StatsFolder:WaitForChild("Bounty/Honor").Value

if DevilFruit == "" or DevilFruit == nil then 
    DevilFruit = "Không có (None)" 
end

local payload = {
    ["username"] = "Blox Fruit Tracker",
    ["avatar_url"] = "https://tr.rbxcdn.com/e5f4df29c29995573752c0350d757530/150/150/Image/Jpeg",
    ["embeds"] = {
        {
            ["title"] = "📊 THÔNG TIN TÀI KHOẢN: " .. LocalPlayer.Name,
            ["color"] = 65535, -- Màu xanh cyan
            ["footer"] = {
                ["text"] = "Check lúc: " .. os.date("%H:%M:%S - %d/%m/%Y")
            },
            ["fields"] = {
                {
                    ["name"] = "👤 Level",
                    ["value"] = "```" .. tostring(Level) .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "💵 Tiền (Beli)",
                    ["value"] = "```" .. tostring(Beli) .. "$```",
                    ["inline"] = true
                },
                {
                    ["name"] = "🟣 Fragments",
                    ["value"] = "```" .. tostring(Fragments) .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "☠️ Bounty/Honor",
                    ["value"] = "```" .. tostring(Bounty) .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "🍎 Trái Ác Quỷ",
                    ["value"] = "**" .. tostring(DevilFruit) .. "**",
                    ["inline"] = false
                }
            }
        }
    }
}

if request_func then
    request_func({
        Url = Webhook_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode(payload)
    })
    Notify("Thành Công", "Đã gửi thông tin về Webhook!")
    print("✅ Đã gửi Webhook thành công.")
else
    Notify("Thất Bại", "Executor không hỗ trợ gửi HTTP Request.")
    warn("❌ Executor của bạn không có hàm request/http_request.")
end

