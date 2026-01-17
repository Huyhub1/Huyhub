--[[
    :star2: GALAXY WEBHOOK DECODER
    Tác dụng: Giải mã Script và báo cáo thẳng về Discord của bạn.a
]]

-- CẤU HÌNH (Đã điền Webhook của bạn)
local MY_WEBHOOK = "https://discord.com/api/webhooks/1461646067014828065/48YsBKd2kA9XdiE-PcC1BDhyFs0OIJj1pBG2ds_fN_HzA3QOusHvHh0R8XrCOOh-giGd"

local collected_data = {}
local is_running = true
local HttpService = game:GetService("HttpService")

-- Thêm tiêu đề
table.insert(collected_data, ":detective: **GALAXY DECODE REPORT**")
table.insert(collected_data, ":clock3: Thời gian: `" .. tostring(os.date()) .. "`")
table.insert(collected_data, "-------------------------------------------------")

print("\n\n")
warn(":rocket: GALAXY ĐANG CHẠY... KẾT QUẢ SẼ ĐƯỢC GỬI VỀ DISCORD SAU 15 GIÂY.")

-- =============================================================================
-- 1. CONSTANT DUMPER (Bắt chuỗi giải mã)
-- =============================================================================
local oldInsert = table.insert
hookfunction(table.insert, function(t, v, ...)
    if is_running and type(v) == "string" and #v > 3 then
        if not string.find(v, "lkz") and not string.match(v, "^%d+$") then
            -- Nếu phát hiện link Webhook lạ -> BÁO ĐỘNG NGAY
            if (string.find(v, "http") or string.find(v, "webhook")) and v ~= MY_WEBHOOK then
                table.insert(collected_data, ":rotating_light: **PHÁT HIỆN WEBHOOK ĐỘC HẠI:**\n`" .. v .. "`")
                warn(":rotating_light: BẮT ĐƯỢC WEBHOOK: " .. v)
            else
                table.insert(collected_data, ":unlock: `[STR]` " .. v)
            end
        end
    end
    return oldInsert(t, v, ...)
end)

-- =============================================================================
-- 2. SMART BLOCKER (Chặn địch, Thả ta)
-- =============================================================================
local req = getgenv().request or getgenv().http_request or getgenv().syn.request
if req then
    hookfunction(req, function(options)
        -- Nếu URL là Webhook của BẠN -> Cho phép đi qua
        if options.Url == MY_WEBHOOK then
            return req(options)
        end

        -- Nếu URL là Discord/Webhook khác -> CHẶN NGAY
        if options.Url and string.find(options.Url, "discord") then
            table.insert(collected_data, ":shield: **ĐÃ CHẶN GỬI DỮ LIỆU ĐẾN:**\n`" .. options.Url .. "`")
            warn(":shield: BLOCKED REQUEST: " .. options.Url)
            return {StatusCode = 403, Body = "Blocked by Galaxy"}
        end
        return req(options)
    end)
end

-- =============================================================================
-- 3. AUTO-REPORT (Gửi báo cáo sau 15 giây)
-- =============================================================================
task.delay(15, function()
    is_running = false
    warn(":hourglass_flowing_sand: ĐANG TỔNG HỢP VÀ GỬI BÁO CÁO...")
    
    local final_content = table.concat(collected_data, "\n")
    
    -- Chia nhỏ tin nhắn (Discord giới hạn 2000 ký tự)
    local chunks = {}
    for i = 1, #final_content, 1900 do
        table.insert(chunks, string.sub(final_content, i, i + 1900))
    end
    
    -- Gửi từng phần
    for i, chunk in ipairs(chunks) do
        local payload = HttpService:JSONEncode({
            ["content"] = (i == 1 and "**[BẮT ĐẦU BÁO CÁO]**\n" or "") .. chunk
        })
        
        request({
            Url = MY_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
        task.wait(1) -- Nghỉ 1 giây để tránh bị Discord rate limit
    end
    
    warn(":white_check_mark: ĐÃ GỬI TẤT CẢ VỀ WEBHOOK THÀNH CÔNG!")
    
    -- Gửi thông báo kết thúc
    request({
        Url = MY_WEBHOOK,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({["content"] = ":white_check_mark: **[KẾT THÚC BÁO CÁO]**"})
    })
end)
