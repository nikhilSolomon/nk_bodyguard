-- Notifications. Pick a system in Config.Notify.Type, or set it to 'custom' and edit
-- CustomNotify below to call your own resource.
-- kind: 'inform' | 'success' | 'error' | 'warning'
-- GTA colour codes (~r~ ~g~ ~y~ ~b~ ~s~) inside msg are stripped for non-native systems.

local function strip(msg) return (tostring(msg):gsub('~[a-z]~', '')) end

local function nativeFeed(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

-- >>> EDIT THIS for Config.Notify.Type = 'custom' <<<
local function CustomNotify(msg, kind)
    -- examples:
    -- exports['my_notify']:Show(strip(msg), kind)
    -- TriggerEvent('my_notify:show', { text = strip(msg), type = kind })
    nativeFeed(msg)
end

local systems = {
    native = function(msg) nativeFeed(msg) end,
    esx    = function(msg, kind) TriggerEvent('esx:showNotification', strip(msg), kind) end,
    ox_lib = function(msg, kind)
        local t = (kind == 'warning') and 'warning' or ((kind == 'error') and 'error' or ((kind == 'success') and 'success' or 'inform'))
        if lib and lib.notify then lib.notify({ title = Config.Notify.Title, description = strip(msg), type = t })
        else exports.ox_lib:notify({ title = Config.Notify.Title, description = strip(msg), type = t }) end
    end,
    okok   = function(msg, kind) exports['okokNotify']:Alert(Config.Notify.Title, strip(msg), 5000, kind) end,
    mythic = function(msg, kind) exports['mythic_notify']:DoHudText(kind, strip(msg)) end,
    custom = CustomNotify,
}

function Notify(msg, kind)
    kind = kind or 'inform'
    local fn = systems[Config.Notify.Type] or systems.native
    local ok, err = pcall(fn, msg, kind)
    if not ok then
        nativeFeed(msg)   -- a broken notification resource must never break the squad script
        if Config.Debug then print('[nk_bodyguard] notify failed: ' .. tostring(err)) end
    end
end

RegisterNetEvent('nk_bodyguard:notify', function(msg, kind) Notify(msg, kind) end)
