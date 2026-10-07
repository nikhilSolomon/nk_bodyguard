-- ESX bridge (client). Deliberately small: the client never touches ESX directly, everything
-- player-related comes from the server. Another framework only needs to provide these event names.
if Config.Framework ~= 'esx' then return end
Bridge = Bridge or {}
Bridge.PlayerLoadedEvent = 'esx:playerLoaded'
Bridge.PlayerLogoutEvent = 'esx:onPlayerLogout'
Bridge.GroupChangedEvent = 'esx:setGroup'
