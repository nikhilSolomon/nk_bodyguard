fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nk_bodyguard'
description 'NPC bodyguards with a squad control panel: follow, hold, aggressive, hold fire, drive-by, chauffeur'
author 'Nikhil'
version '2.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
