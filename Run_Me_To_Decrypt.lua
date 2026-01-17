--[[
    Blox Fruits Account Checker (With Error Reporter)
    Tác dụng: Check acc, nếu lỗi thì báo về Webhook ngay lập tức.
]]

-- !!! DÁN LINK WEBHOOK CỦA BẠN VÀO DÒNG DƯỚI !!!
local Webhook_URL = "https://webhook.lewisakura.moe/api/webhooks/1462005180118601772/mPmggBSvvppiwCfLkN-3BBgV0CqMPDHsqA8qllgyzpJVewuAgxf_5orxitLXiu4BQykw" 

-- Dịch vụ
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Hàm gửi request (Tương thích mọi Executor)
local request_func = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- Hàm thông báo trong game (An toàn)
local function Notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title;
            Text = text;
            Duration = 5;
        })
    end)
end

-- Hàm gửi Webhook chung
local function SendToDiscord(payload)
    if request_func then
        request_func({
            Url = Webhook_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    else
        warn("❌ Executor không hỗ trợ gửi HTTP Request.")
    end
end

-- ==========================================
-- PHẦN CHÍNH: LOGIC LẤY THÔNG TIN (ĐƯỢC BẢO VỆ)
-- ==========================================
local function MainTask()
    Notify("Galaxy Checker", "Đang lấy dữ liệu...")

    -- 1. Chờ dữ liệu load (Thêm timeout để không treo máy)
    local DataFolder = LocalPlayer:WaitForChild("Data", 30) 
    local StatsFolder = LocalPlayer:WaitForChild("leaderstats", 30)

    if not DataFolder or not StatsFolder then
        error("Time Out: Không tìm thấy folder Data sau 30s (Có thể do mạng lag hoặc chưa vào game).")
    end

    -- 2. Lấy chỉ số
    local Level = DataFolder:WaitForChild("Level").Value
    local Beli = DataFolder:WaitForChild("Beli").Value
    local Fragments = DataFolder:WaitForChild("Fragments").Value
    local DevilFruit = DataFolder:WaitForChild("DemonFruit").Value
    local Bounty = StatsFolder:WaitForChild("Bounty/Honor").Value

    if DevilFruit == "" or DevilFruit == nil then DevilFruit = "Không có (None)" end

    -- 3. Gửi thông tin thành công (Màu Xanh)
    local success_payload = {
        ["username"] = "Blox Fruit Tracker",
        ["avatar_url"] = "https://tr.rbxcdn.com/e5f4df29c29995573752c0350d757530/150/150/Image/Jpeg",
        ["embeds"] = {
            {
                ["title"] = "✅ CHECK THÀNH CÔNG: " .. LocalPlayer.Name,
                ["color"] = 65280, -- Màu xanh lá (Green)
                ["fields"] = {
                    { ["name"] = "👤 Level", ["value"] = "```" .. Level .. "```", ["inline"] = true },
                    { ["name"] = "💵 Beli", ["value"] = "```" .. Beli .. "$```", ["inline"] = true },
                    { ["name"] = "🟣 Fragments", ["value"] = "```" .. Fragments .. "```", ["inline"] = true },
                    { ["name"] = "☠️ Bounty", ["value"] = "```" .. Bounty .. "```", ["inline"] = true },
                    { ["name"] = "🍎 Trái Ác Quỷ", ["value"] = "**" .. DevilFruit .. "**", ["inline"] = false }
                },
                ["footer"] = { ["text"] = "Galaxy Script • Safe & Secure" }
            }
        }
    }
    SendToDiscord(success_payload)
    Notify("Thành Công", "Đã gửi thông tin về Discord!")
    print("✅ Đã gửi Webhook thành công.")
end

-- ==========================================
-- TRÌNH XỬ LÝ LỖI (BÁC SĨ)
-- ==========================================
-- Chạy hàm MainTask trong chế độ an toàn (xpcall)
xpcall(MainTask, function(ErrorMessage)
    -- Nếu có lỗi xảy ra, đoạn này sẽ chạy:
    warn("🚨 SCRIPT GẶP LỖI: " .. tostring(ErrorMessage))
    Notify("Thất Bại", "Có lỗi xảy ra! Đang báo cáo về Discord...")

    -- Gửi báo cáo lỗi (Màu Đỏ)
    local error_payload = {
        ["username"] = "Script Error Logger",
        ["embeds"] = {
            {
                ["title"] = "🚨 BÁO CÁO LỖI (SCRIPT CRASHED)",
                ["description"] = "Script đã gặp lỗi khi chạy trên máy của: **" .. LocalPlayer.Name .. "**",
                ["color"] = 16711680, -- Màu đỏ (Red)
                ["fields"] = {
                    {
                        ["name"] = "Chi tiết lỗi:",
                        ["value"] = "```lua\n" .. tostring(ErrorMessage) .. "\n```",
                        ["inline"] = false
                    },
                    {
                        ["name"] = "Thời gian:",
                        ["value"] = os.date("%H:%M:%S - %d/%m/%Y"),
                        ["inline"] = false
                    }
                }
            }
        }
    }
    SendToDiscord(error_payload)
end)

