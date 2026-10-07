-- nk_bodyguard server: roles, Agency contracts (oxmysql), paid services, chat command
ESX = exports['es_extended']:getSharedObject()

---------------------------------------------------------------------------
-- schema
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `nk_bodyguard_contracts` (
            `id`         INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(80) NOT NULL,
            `name`       VARCHAR(40) NOT NULL,
            `tier`       VARCHAR(20) NOT NULL,
            `model`      VARCHAR(60) NOT NULL,
            `weapon`     VARCHAR(60) NOT NULL,
            `kills`      INT NOT NULL DEFAULT 0,
            `price`      INT NOT NULL DEFAULT 0,
            `status`     VARCHAR(12) NOT NULL DEFAULT 'active',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `ended_at`   TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_owner_status` (`identifier`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function isAdmin(src)
    if IsPlayerAceAllowed(src, 'command.' .. Config.Command) then return true end
    local x = ESX.GetPlayerFromId(src)
    if x then
        local grp = x.getGroup()
        for _, g in ipairs(Config.AdminGroups) do if g == grp then return true end end
    end
    return false
end

local function money(n)
    local s = tostring(math.floor(n or 0))
    return '$' .. s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

local function balance(x)
    local total = 0
    for _, acc in ipairs(Config.Agency.Accounts) do
        local a = x.getAccount(acc)
        if a then total = total + (a.money or 0) end
    end
    return total
end

-- Takes the whole amount from the first configured account that can cover it.
local function charge(x, amount, reason)
    if amount <= 0 then return true end
    for _, acc in ipairs(Config.Agency.Accounts) do
        local a = x.getAccount(acc)
        if a and (a.money or 0) >= amount then
            x.removeAccountMoney(acc, amount, reason)
            return true
        end
    end
    return false
end

local function refund(x, amount, reason)
    if amount > 0 then x.addAccountMoney(Config.Agency.Accounts[1], amount, reason) end
end

local function tierById(id)
    for _, t in ipairs(Config.Tiers) do if t.id == id then return t end end
    return nil
end

local function activeContracts(identifier)
    return MySQL.query.await(
        'SELECT `id`, `name`, `tier`, `model`, `weapon`, `kills` FROM `nk_bodyguard_contracts` WHERE `identifier` = ? AND `status` = ? ORDER BY `id`',
        { identifier, 'active' }) or {}
end

local function freeName(used)
    local pool = {}
    for _, n in ipairs(Config.Names) do if not used[n] then pool[#pool + 1] = n end end
    if #pool > 0 then return pool[math.random(#pool)] end
    for i = 1, 99 do local n = ('Guard %d'):format(i); if not used[n] then return n end end
    return 'Guard'
end

local function reply(src, reqId, ok, msg, extra)
    TriggerClientEvent('nk_bodyguard:reply', src, reqId, ok, msg, extra or {})
end

local function sendInit(src)
    local x = ESX.GetPlayerFromId(src)
    TriggerClientEvent('nk_bodyguard:init', src, {
        admin = isAdmin(src),
        loaded = x ~= nil,
        contracts = x and activeContracts(x.identifier) or {},
        balance = x and balance(x) or 0,
    })
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
-- client (re)started or character loaded: send role + active contracts
RegisterNetEvent('nk_bodyguard:hello', function() sendInit(source) end)
AddEventHandler('esx:playerLoaded', function(src) SetTimeout(1500, function() sendInit(src) end) end)

RegisterNetEvent('nk_bodyguard:balance', function(reqId)
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not x then return reply(src, reqId, false, 'Character not loaded') end
    reply(src, reqId, true, '', { balance = balance(x), active = #activeContracts(x.identifier), admin = isAdmin(src) })
end)

-- hire a guard at the Agency
RegisterNetEvent('nk_bodyguard:hire', function(reqId, tierId, outfitIdx)
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not x then return reply(src, reqId, false, 'Character not loaded') end
    local tier = tierById(tierId)
    if not tier then return reply(src, reqId, false, 'Unknown contract') end

    local admin = isAdmin(src)
    local active = activeContracts(x.identifier)
    local limit = admin and Config.MaxGuards or Config.Agency.MaxContracts
    if #active >= limit then return reply(src, reqId, false, ('Contract limit reached (%d)'):format(limit)) end

    local price = admin and 0 or tier.price
    if not charge(x, price, 'Bodyguard contract: ' .. tier.label) then
        return reply(src, reqId, false, ('Insufficient funds: %s needed'):format(money(price)))
    end

    local outfit = tier.outfits[tonumber(outfitIdx) or 1] or tier.outfits[1]
    local used = {}
    for _, c in ipairs(active) do used[c.name] = true end
    local name = freeName(used)

    local id = MySQL.insert.await(
        'INSERT INTO `nk_bodyguard_contracts` (`identifier`, `name`, `tier`, `model`, `weapon`, `price`) VALUES (?, ?, ?, ?, ?, ?)',
        { x.identifier, name, tier.id, outfit.model, tier.weapon, price })
    if not id then
        refund(x, price, 'Bodyguard contract refund')
        return reply(src, reqId, false, 'Agency database error, you were refunded')
    end

    reply(src, reqId, true, ('%s signed (%s)%s'):format(name, tier.label, price > 0 and (' for ' .. money(price)) or ''), {
        contract = { id = id, name = name, tier = tier.id, model = outfit.model, weapon = tier.weapon, kills = 0 },
        balance = balance(x), active = #active + 1,
    })
end)

-- pay for a service (escort / air / healPerGuard)
RegisterNetEvent('nk_bodyguard:pay', function(reqId, service, qty)
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not x then return reply(src, reqId, false, 'Character not loaded') end
    local unit = Config.Services[service]
    if not unit then return reply(src, reqId, false, 'Unknown service') end
    qty = math.max(1, math.min(Config.MaxGuards, math.floor(tonumber(qty) or 1)))
    local price = isAdmin(src) and 0 or unit * qty
    if not charge(x, price, 'Bodyguard service: ' .. service) then
        return reply(src, reqId, false, ('Insufficient funds: %s needed'):format(money(price)))
    end
    reply(src, reqId, true, price > 0 and ('Paid %s'):format(money(price)) or '', { balance = balance(x), price = price })
end)

-- guard killed / dismissed / sent home: contract is over
RegisterNetEvent('nk_bodyguard:contractEnd', function(id, reason)
    local x = ESX.GetPlayerFromId(source)
    if not x then return end
    reason = (reason == 'killed') and 'killed' or 'dismissed'
    MySQL.update('UPDATE `nk_bodyguard_contracts` SET `status` = ?, `ended_at` = NOW() WHERE `id` = ? AND `identifier` = ? AND `status` = ?',
        { reason, tonumber(id), x.identifier, 'active' })
end)

-- veterancy: a contracted guard scored a kill
RegisterNetEvent('nk_bodyguard:kill', function(id)
    local x = ESX.GetPlayerFromId(source)
    if not x then return end
    MySQL.update('UPDATE `nk_bodyguard_contracts` SET `kills` = `kills` + 1 WHERE `id` = ? AND `identifier` = ? AND `status` = ?',
        { tonumber(id), x.identifier, 'active' })
end)

---------------------------------------------------------------------------
-- chat command (admins): chat "/bodyguard" and F8 "bodyguard" both reach here,
-- even with the client console in production mode. Ace check: "command.bodyguard".
---------------------------------------------------------------------------
RegisterCommand(Config.Command, function(source, args)
    if source == 0 then
        print('[nk_bodyguard] this command must be run by a player')
        return
    end
    TriggerClientEvent('nk_bodyguard:client:command', source, args)
end, Config.AdminOnly)
