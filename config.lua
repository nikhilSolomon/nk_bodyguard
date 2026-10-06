Config = {}

-- Chat / F8 command. Usage:
--   /bodyguard          spawn one guard (up to MaxGuards)
--   /bodyguard 3        spawn three
--   /bodyguard dismiss  remove all your guards
--   /bodyguard panel    open the squad panel
Config.Command = 'bodyguard'
Config.AdminOnly = true          -- true = needs the "command.bodyguard" ace (admins have "command" allow)

-- Keys (players can rebind in Settings > Key Bindings > FiveM)
Config.PanelKey = 'F9'           -- open / close the squad control panel
Config.AttackKey = 'CAPITAL'     -- Caps Lock: order guards to attack whatever you are aiming at

Config.MaxGuards = 6

-- Recruit options shown in the panel. First entry of each list is the default; 'random' picks any.
Config.Models = {
    { id = 'blackops1', model = 's_m_y_blackops_01', label = 'Blackops' },
    { id = 'blackops2', model = 's_m_y_blackops_02', label = 'Blackops II' },
    { id = 'highsec',   model = 's_m_m_highsec_01',  label = 'Suit (HighSec)' },
    { id = 'swat',      model = 's_m_y_swat_01',     label = 'SWAT' },
    { id = 'marine',    model = 's_m_y_marine_03',   label = 'Marine' },
    { id = 'merc',      model = 'mp_m_securoguard_01', label = 'Securoguard' },
}
Config.Weapons = {
    { id = 'carbine',  name = 'WEAPON_CARBINERIFLE',   label = 'Carbine Rifle' },
    { id = 'spcarb',   name = 'WEAPON_SPECIALCARBINE', label = 'Special Carbine' },
    { id = 'asmg',     name = 'WEAPON_ASSAULTSMG',     label = 'Assault SMG' },
    { id = 'shotgun',  name = 'WEAPON_PUMPSHOTGUN',    label = 'Pump Shotgun' },
    { id = 'combatmg', name = 'WEAPON_COMBATMG',       label = 'Combat MG' },
    { id = 'sniper',   name = 'WEAPON_HEAVYSNIPER',    label = 'Heavy Sniper' },
    { id = 'rpg',      name = 'WEAPON_RPG',            label = 'RPG' },
    { id = 'minigun',  name = 'WEAPON_MINIGUN',        label = 'Minigun' },
}

Config.Health = 600              -- 200 is a normal ped
Config.Armour = 200
Config.Accuracy = 85             -- 0-100
Config.Invincible = false        -- default; can be toggled live in Settings

Config.WarpDistance = 70.0       -- on foot: a guard this far behind is moved next to you
Config.LostDistance = 140.0      -- while you drive: a guard this far behind is moved to the road behind your car (never into a seat)
Config.Blip = true               -- show guards on the minimap
Config.Debug = true              -- print squad events to the F8 console

-- Targeting for the Attack hotkey / Drive-by button
Config.TargetRange = 250.0
Config.TargetConeDegrees = 20.0

-- Driving (chauffeur / cruise / escort). Selected in the panel.
-- speed in m/s (x3.6 = km/h). boost = % added to the vehicle's top speed while a guard drives it.
-- aggro = driver aggressiveness 0..1. style = CVehicleDriveFlags bitmask.
Config.DriveStyles = {
    calm     = { label = 'Calm',     speed = 20.0,  style = 786603,     aggro = 0.0, boost = 0   },
    normal   = { label = 'Normal',   speed = 32.0,  style = 786603,     aggro = 0.2, boost = 0   },
    rushed   = { label = 'Rushed',   speed = 50.0,  style = 1074528293, aggro = 0.7, boost = 15  },
    reckless = { label = 'Reckless', speed = 75.0,  style = 787236,     aggro = 1.0, boost = 40  },
    insane   = { label = 'Insane',   speed = 120.0, style = 1835812,    aggro = 1.0, boost = 80  },
}
Config.DefaultDriveStyle = 'normal'
Config.ArriveDistance = 8.0

-- Escort car: guards not riding with you get their own vehicle and shadow yours.
Config.EscortVehicles = {
    { id = 'granger',   model = 'granger',   label = 'Granger' },
    { id = 'insurgent', model = 'insurgent2', label = 'Insurgent' },
    { id = 'kuruma',    model = 'kuruma2',   label = 'Armored Kuruma' },
    { id = 'baller',    model = 'baller5',   label = 'Baller LE' },
}
Config.EscortDistance = 12.0

-- Air support: a helicopter with a guard pilot (and gunners if spare) shadows you from above.
Config.AirVehicle = 'buzzard'    -- armed Buzzard; 'buzzard2' = unarmed, 'maverick' = civilian
Config.AirHeight = 45.0          -- metres above you
Config.AirSpeed = 60.0

-- Auto drive-by: passengers fire on hostiles within this range without being told to.
Config.AutoDriveByRange = 80.0

-- Aggressive mode: how far guards look for hostiles
Config.AggroRange = 60.0

-- Settings defaults (all toggleable live in the panel)
Config.AutoReinforce = false     -- recruit a replacement when a guard dies
Config.ReinforceDelay = 6000     -- ms
Config.HealthRegen = false       -- guards slowly regenerate when not fighting
Config.RegenPerTick = 6          -- hp every 2 s
