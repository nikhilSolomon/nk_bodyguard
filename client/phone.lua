-- Phone / third-party integration. The core exposes exports and events so a phone app, a job
-- menu or any other resource can open the Bodyguard Center or read the squad.
--
--   exports['nk_bodyguard']:OpenPanel()        open the Bodyguard Center (same as F9)
--   exports['nk_bodyguard']:ClosePanel()
--   exports['nk_bodyguard']:TogglePanel()
--   exports['nk_bodyguard']:OpenAgency()       open the Agency hiring screen from anywhere
--   exports['nk_bodyguard']:GetSquad()         { {name, tier, rank, kills, health, armour, state, contract, ped}, ... }
--   exports['nk_bodyguard']:IsAdmin()
--
-- Events (TriggerEvent from any client script):
--   'nk_bodyguard:open'  'nk_bodyguard:close'  'nk_bodyguard:toggle'  'nk_bodyguard:openAgency'
--
-- The BG_* functions are set by client.lua.

exports('OpenPanel',   function() if BG_OpenPanel then BG_OpenPanel() end end)
exports('ClosePanel',  function() if BG_ClosePanel then BG_ClosePanel() end end)
exports('TogglePanel', function() if BG_TogglePanel then BG_TogglePanel() end end)
exports('OpenAgency',  function() if BG_OpenAgency then BG_OpenAgency() end end)
exports('GetSquad',    function() return BG_GetSquad and BG_GetSquad() or {} end)
exports('IsAdmin',     function() return BG_IsAdmin and BG_IsAdmin() or false end)

RegisterNetEvent('nk_bodyguard:open',       function() if BG_OpenPanel then BG_OpenPanel() end end)
RegisterNetEvent('nk_bodyguard:close',      function() if BG_ClosePanel then BG_ClosePanel() end end)
RegisterNetEvent('nk_bodyguard:toggle',     function() if BG_TogglePanel then BG_TogglePanel() end end)
RegisterNetEvent('nk_bodyguard:openAgency', function() if BG_OpenAgency then BG_OpenAgency() end end)

-- Optional phone hook (Config.Phone). Any phone can simply TriggerEvent(Config.Phone.OpenEvent).
CreateThread(function()
    if not Config.Phone or not Config.Phone.Enabled then return end
    local ev = Config.Phone.OpenEvent
    if ev and ev ~= '' and ev ~= 'nk_bodyguard:toggle' then
        RegisterNetEvent(ev, function() if BG_TogglePanel then BG_TogglePanel() end end)
    end
    -- lb-phone: register a "Bodyguards" app that toggles the panel when tapped
    if Config.Phone.Resource == 'lb-phone' and GetResourceState('lb-phone') == 'started' then
        Wait(2000)
        local ok, err = pcall(function()
            exports['lb-phone']:AddCustomApp({
                identifier = 'nk_bodyguard', name = 'Bodyguards', description = 'Command your security detail',
                developer = 'nk', defaultApp = false, size = 1024,
                ui = GetCurrentResourceName() .. '/html/index.html',
                icon = Config.Phone.Icon ~= '' and Config.Phone.Icon or nil,
                onUse = function() if BG_TogglePanel then BG_TogglePanel() end end,
            })
        end)
        if not ok and Config.Debug then print('[nk_bodyguard] lb-phone app registration failed: ' .. tostring(err)) end
    end
end)
