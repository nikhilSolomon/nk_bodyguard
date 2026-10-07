fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nk_bodyguard'
description 'NPC bodyguards: Bodyguard Agency contracts, squad control panel, formations, chauffeur, escort, air support'
author 'Nikhil'
version '5.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'es_extended',
    'oxmysql',
}
