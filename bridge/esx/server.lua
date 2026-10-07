-- ESX bridge (server). To support another framework, copy this folder, implement the same
-- Bridge functions and point Config.Framework at it. Nothing outside bridge/ talks to ESX.
if Config.Framework ~= 'esx' then return end

local ESX = exports['es_extended']:getSharedObject()

Bridge = Bridge or {}

-- Wrap a framework player in a small, framework-neutral object (nil when not loaded).
function Bridge.GetPlayer(src)
    local x = ESX.GetPlayerFromId(src)
    if not x then return nil end
    return {
        source = src,
        identifier = x.identifier,
        name = x.getName(),
        group = x.getGroup(),
        -- account: 'money' (cash) | 'bank' | 'black_money'
        getBalance = function(account)
            local a = x.getAccount(account)
            return a and (a.money or 0) or 0
        end,
        removeMoney = function(account, amount, reason) x.removeAccountMoney(account, amount, reason) end,
        addMoney = function(account, amount, reason) x.addAccountMoney(account, amount, reason) end,
    }
end

-- Admin groups come from Config.AdminGroups; the ace check is framework-neutral and lives in server.lua
function Bridge.IsAdminGroup(group)
    for _, g in ipairs(Config.AdminGroups) do if g == group then return true end end
    return false
end

-- Server-side notification to one player, routed through the client Notify hook so the
-- user's chosen notification system is used everywhere.
function Bridge.Notify(src, msg, kind)
    TriggerClientEvent('nk_bodyguard:notify', src, msg, kind or 'inform')
end

-- Lifecycle hooks the core subscribes to
function Bridge.OnPlayerLoaded(cb)
    AddEventHandler('esx:playerLoaded', function(src) cb(src) end)
end

function Bridge.OnGroupChanged(cb)
    AddEventHandler('esx:setGroup', function(src) cb(src) end)
end
