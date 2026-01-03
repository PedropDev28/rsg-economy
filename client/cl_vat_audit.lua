-- cl_vat_audit.lua
--========================================================--
-- Client VAT Audit Panel (ox_lib) - HARDENED
--========================================================--

local function fmtMoney(val)
    return ("$%.2f"):format(tonumber(val) or 0)
end

local function safeStr(s, maxLen)
    s = tostring(s or '')
    maxLen = maxLen or 180
    if #s > maxLen then
        return s:sub(1, maxLen - 3) .. '...'
    end
    return s
end

RegisterNetEvent('rsg-economy:vatAuditOpen', function(data)
    data = data or {}
    local region      = data.region or 'unknown'
    local businesses  = data.businesses or {}

    if not lib or not lib.registerContext then
        print('[rsg-economy] ox_lib context not available on client.')
        return
    end

    local opts = {}

    for _, biz in ipairs(businesses) do
        local net = tonumber(biz.net or 0) or 0

        local state
        if net > 0.01 then
            state = ('OWES %s'):format(fmtMoney(net))
        elseif net < -0.01 then
            state = ('REFUND %s'):format(fmtMoney(-net))
        else
            state = 'Settled'
        end

        local desc = ('Output: %s | Input: %s | Settled: %s | %s'):format(
            fmtMoney(biz.output),
            fmtMoney(biz.input),
            fmtMoney(biz.settled),
            state
        )

        opts[#opts+1] = {
            title       = biz.business_name or ('Business #' .. tostring(biz.business_id)),
            description = safeStr(desc, 200),
            icon        = (net > 0.01 and 'triangle-exclamation')
                       or (net < -0.01 and 'circle-arrow-left')
                       or 'circle-check',
            arrow       = true,
            event       = 'rsg-economy:vatAuditDetail',
            args        = {
                business_id   = biz.business_id,
                business_name = biz.business_name,
                region        = region
            }
        }
    end

    lib.registerContext({
        id = 'vat_audit_main',
        title = ('VAT Audit — %s'):format(region),
        canClose = true,
        options = opts
    })

    lib.showContext('vat_audit_main')
end)

RegisterNetEvent('rsg-economy:vatAuditDetail', function(args)
    args = args or {}
    local business_id   = tonumber(args.business_id or 0) or 0
    local business_name = args.business_name or ('Business #' .. tostring(business_id))
    local region        = args.region or 'unknown'

    if business_id <= 0 then
        return print('[rsg-economy] vatAuditDetail: invalid business_id')
    end

    local ledger = {}
    if lib and lib.callback and lib.callback.await then
        ledger = lib.callback.await('rsg-economy:getVatLedger', false, business_id, region) or {}
    else
        print('[rsg-economy] ox_lib callback not available on client.')
        ledger = {}
    end

    local opts = {}

    if #ledger == 0 then
        opts[#opts+1] = {
            title = 'No VAT ledger entries.',
            description = 'This business has no recorded INPUT/OUTPUT/SETTLEMENT entries yet.',
            disabled = true
        }
    else
        for _, row in ipairs(ledger) do
            local dir = tostring(row.direction or '?')
            local tag = (dir == 'OUTPUT' and 'Sale')
                     or (dir == 'INPUT' and 'Expense')
                     or (dir == 'SETTLEMENT' and 'Settle')
                     or dir

            local title = ('[%s] %s'):format(tag, fmtMoney(row.tax_amount or 0))

            local created = safeStr(row.created_at or '', 32)
            local desc = ('Base: %s | Rate: %.2f%%\n%s\n%s'):format(
                fmtMoney(row.base_amount or 0),
                tonumber(row.tax_rate or 0) or 0,
                safeStr(row.ref_text or '', 90),
                created
            )

            opts[#opts+1] = { title = title, description = desc, disabled = true }
        end
    end

    local id = 'vat_audit_detail_' .. tostring(business_id)

    lib.registerContext({
        id = id,
        title = ('VAT Ledger — %s (%s)'):format(business_name, region),
        menu  = 'vat_audit_main',
        canClose = true,
        options = opts
    })

    lib.showContext(id)
end)
