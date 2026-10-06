-- Server-side command registration: chat "/bodyguard" and F8 "bodyguard" both reach here,
-- even with the client console in production mode. Ace check: "command.bodyguard".
RegisterCommand(Config.Command, function(source, args)
    if source == 0 then
        print('[nk_bodyguard] this command must be run by a player')
        return
    end
    TriggerClientEvent('nk_bodyguard:client:command', source, args)
end, Config.AdminOnly)
