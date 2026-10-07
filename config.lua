Config = {}

-- Chat / F8 command. Usage:
--   /bodyguard          spawn one guard (up to MaxGuards)
--   /bodyguard 3        spawn three
--   /bodyguard dismiss  remove all your guards
--   /bodyguard panel    open the squad panel
Config.Command = 'bodyguard'
Config.AdminOnly = true          -- true = needs the "command.bodyguard" ace (admins have "command" allow)

---------------------------------------------------------------------------
-- ROLES
--  Admins (ESX group below, or anyone with the "command.bodyguard" ace): free, unlimited
--  recruiting from the F9 panel, every toggle, free services.
--  Citizens: hire guards at the Agency; each hire is a CONTRACT saved in the database that
--  lasts until the guard is killed or dismissed (no refunds). Escort / air / medic cost money.
---------------------------------------------------------------------------
Config.AdminGroups = { 'admin', 'superadmin' }

Config.Agency = {
    Enabled = true,
    Name = 'Bodyguard Agency',
    -- Manager NPC you talk to (Legion Square, next to the ESX default spawn). z is snapped to the ground.
    Ped = { model = 's_m_m_highsec_02', coords = vector4(226.6, -869.8, 30.49, 160.0), scenario = 'WORLD_HUMAN_CLIPBOARD' },
    -- New hires appear here and walk over to you.
    SpawnPoint = vector4(229.6, -872.4, 30.49, 160.0),
    Blip = { sprite = 280, colour = 3, scale = 0.9 },
    InteractDistance = 2.2,
    MaxContracts = 4,                 -- active contracts per character (admins: Config.MaxGuards)
    Accounts = { 'money', 'bank' },   -- pay from cash first, then bank (whole amount from one account)
}

-- Contract tiers sold at the Agency. price in $, health 200 = normal ped, accuracy 0-100.
Config.Tiers = {
    {
        id = 'rookie', label = 'Rookie', color = '#94a3b8', price = 2500,
        desc = 'Private security. Cheap, keeps trouble at arm\'s length.',
        weapon = 'WEAPON_PISTOL50', weaponLabel = 'Pistol .50',
        health = 300, armour = 50, accuracy = 45,
        outfits = { { model = 's_m_m_security_01', label = 'Security' }, { model = 'mp_m_securoguard_01', label = 'Securoguard' } },
    },
    {
        id = 'pro', label = 'Professional', color = '#3b82f6', price = 7500,
        desc = 'Trained close-protection officer in a sharp suit.',
        weapon = 'WEAPON_SMG', weaponLabel = 'SMG',
        health = 450, armour = 100, accuracy = 65,
        outfits = { { model = 's_m_m_highsec_01', label = 'Suit' }, { model = 's_m_m_highsec_02', label = 'Suit II' } },
    },
    {
        id = 'elite', label = 'Elite', color = '#8b5cf6', price = 15000,
        desc = 'Ex-special forces operator. Professional, hard to put down.',
        weapon = 'WEAPON_CARBINERIFLE', weaponLabel = 'Carbine Rifle',
        health = 600, armour = 200, accuracy = 80,
        outfits = { { model = 's_m_y_blackops_01', label = 'Black Ops' }, { model = 's_m_y_blackops_02', label = 'Black Ops II' } },
    },
    {
        id = 'heavy', label = 'Heavy Gunner', color = '#ef4444', price = 25000,
        desc = 'Armoured tactical unit with a light machine gun.',
        weapon = 'WEAPON_COMBATMG', weaponLabel = 'Combat MG',
        health = 800, armour = 200, accuracy = 70,
        outfits = { { model = 's_m_y_swat_01', label = 'SWAT' } },
    },
}

-- Paid services for citizens (admins: free). Ordered from the F9 panel.
Config.Services = {
    escort = 2500,        -- spawn an escort car crewed by your spare guards
    air = 10000,          -- call in an armed helicopter
    healPerGuard = 750,   -- medic: full health + armour, per injured guard
}

-- Veterancy: kills are saved on the contract. Bonuses add to the tier's accuracy / armour.
Config.Ranks = {
    { kills = 0,  label = 'Recruit' },
    { kills = 5,  label = 'Veteran', accuracy = 8 },
    { kills = 15, label = 'Legend',  accuracy = 15, armour = 100 },
}

-- Names handed out to new guards (contracts and admin recruits)
Config.Names = {
    'Marcus', 'Viktor', 'Dmitri', 'Logan', 'Jack', 'Rico', 'Tommy', 'Andre', 'Kenji', 'Nikolai',
    'Sergio', 'Malik', 'Dante', 'Hugo', 'Omar', 'Felix', 'Ivan', 'Carlos', 'Reese', 'Boris',
}

-- Keys (players can rebind in Settings > Key Bindings > FiveM)
Config.PanelKey = 'F9'           -- open / close the squad control panel
Config.AttackKey = 'CAPITAL'     -- Caps Lock: order guards to attack whatever you are aiming at

Config.MaxGuards = 6             -- hard cap on guards following one player (admin recruits + contracts)

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
