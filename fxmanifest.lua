fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nk_bodyguard'
description 'NPC bodyguards: Bodyguard Agency contracts, squad control panel, formations, chauffeur, escort, air support'
author 'Nikhil'
version '5.2.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_script 'config.lua'

client_scripts {
    'bridge/esx/client.lua',
    'client/notify.lua',
    'client.lua',
    'client/phone.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/esx/server.lua',
    'server.lua',
}

dependencies {
    'es_extended',
    'oxmysql',
}
