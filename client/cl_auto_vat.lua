-- cl_auto_vat.lua
-- rsg-economy/client/cl_auto_vat.lua
-- Detect in-game Saturday 15:00, then notify server to auto-collect VAT
-- HARDENED: local throttle to reduce spam

local lastDateKey = nil
local lastFireMs  = 0

local function dbg(msg)
    if Config and Config.Debug then
        print('[rsg-economy][autoVAT] ' .. tostring(msg))
    end
end

CreateThread(function()
    while true do
        local hour      = GetClockHours()         -- 0–23
        local dayOfWeek = GetClockDayOfWeek()     -- 0=Sunday .. 6=Saturday
        local year      = GetClockYear()
        local month     = GetClockMonth()         -- 0–11
        local day       = GetClockDayOfMonth()

        local dateKey = string.format('%04d-%02d-%02d', year, month + 1, day)

        -- Saturday (6) at 15:00
        if dayOfWeek == 6 and hour == 15 then
            local now = GetGameTimer()
            if lastDateKey ~= dateKey and (now - lastFireMs) > 60000 then
                lastDateKey = dateKey
                lastFireMs  = now
                dbg('Triggering server auto VAT collect for ' .. dateKey)
                TriggerServerEvent('rsg-economy:autoVatCollect')
            end
        end

        Wait(60000) -- check every IRL minute
    end
end)
