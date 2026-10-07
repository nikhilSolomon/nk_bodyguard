-- nk_bodyguard v5 : Bodyguard Agency contracts + squad control panel
local guards = {}            -- { ped, name, model, weapon, blip, modelHash, kills, hold, contract, tier, rank, ... }
local isAdmin = false        -- set by the server (ESX admin group / command.bodyguard ace)
local shopOpen = false
local respawnQueue = {}      -- contracted guards that vanished without dying: { at=, c= }
local mode = 'follow'        -- follow | hold | aggressive | passive
local formation = 0
local driveStyle = Config.DefaultDriveStyle
local autoDriveBy = false
local panelOpen = false
local chauffeur = nil        -- { guard, veh, dest, kind }
local escort = nil           -- { veh, driver, blip, following, styleKey }
local air = nil              -- { veh, pilot, blip }
local GUARD_REL = joaat('NK_BODYGUARD')
local PLAYER_REL = joaat('PLAYER')
local eventLog = {}
local reinforceQueue = {}    -- timestamps when replacements are due
local focus = nil            -- marked target being attacked: { ent=, kind='ped'|'veh', scope=, at= }

local settings = {
    recruitModel  = 'random',
    recruitWeapon = 'random',
    escortVehicle = Config.EscortVehicles[1].id,
    spacing       = 1.8,
    accuracy      = Config.Accuracy,
    invincible    = Config.Invincible,
    regen         = Config.HealthRegen,
    reinforce     = Config.AutoReinforce,
    blips         = Config.Blip,
    pos           = 'center',
    scale         = 1,
    customOffsets = {},     -- [slot] = { x =, y = }  (formation 4)
    seats         = {},     -- ["-1"|"0"|"1"...] = guard name
}

AddRelationshipGroup('NK_BODYGUARD')
SetRelationshipBetweenGroups(0, GUARD_REL, PLAYER_REL)
SetRelationshipBetweenGroups(0, PLAYER_REL, GUARD_REL)

---------------------------------------------------------------------------
-- utils
---------------------------------------------------------------------------
local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function dbg(fmt, ...)
    if Config.Debug then print(('[nk_bodyguard] ' .. fmt):format(...)) end
end

local function logEvent(kind, fmt, ...)
    local msg = fmt:format(...)
    eventLog[#eventLog + 1] = { t = GetCloudTimeAsInt() * 1000, msg = msg, kind = kind }
    if #eventLog > 12 then table.remove(eventLog, 1) end
    dbg('%s', msg)
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 200 do Wait(25); t = t + 1 end
    return HasModelLoaded(hash)
end

local function pick(tbl) return tbl[math.random(#tbl)] end
local function findById(tbl, id) for _, v in ipairs(tbl) do if v.id == id then return v end end return nil end
local function tierById(id) for _, t in ipairs(Config.Tiers) do if t.id == id then return t end end return nil end

local function money(n)
    local s = tostring(math.floor(n or 0))
    return '$' .. s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

-- request / reply with the server (must be called from a thread)
local pending, reqSeq = {}, 0
local function request(kind, ...)
    reqSeq = reqSeq + 1
    local id = reqSeq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('nk_bodyguard:' .. kind, id, ...)
    SetTimeout(10000, function()
        if pending[id] then pending[id] = nil; p:resolve({ false, 'The agency did not answer', {} }) end
    end)
    local r = Citizen.Await(p)
    return r[1], r[2], r[3] or {}
end

RegisterNetEvent('nk_bodyguard:reply', function(id, ok, msg, extra)
    local p = pending[id]
    if p then pending[id] = nil; p:resolve({ ok, msg, extra }) end
end)

local function isSamePed(g)
    if not g or not DoesEntityExist(g.ped) then return false end
    if GetEntityType(g.ped) ~= 1 then return false end
    if g.modelHash and GetEntityModel(g.ped) ~= g.modelHash then return false end
    return (GetPedRelationshipGroupHash(g.ped) - GUARD_REL) % 4294967296 == 0
end
local function alive(g) return isSamePed(g) and not IsEntityDead(g.ped) end
local function eachAlive(fn) for i, g in ipairs(guards) do if alive(g) then fn(g, i) end end end
local function style() return Config.DriveStyles[driveStyle] or Config.DriveStyles.normal end

local function myVehicle()
    local me = PlayerPedId()
    if IsPedInAnyVehicle(me, false) then return GetVehiclePedIsIn(me, false) end
    return 0
end

local function camForward()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cosx = math.cos(rx)
    return vector3(-math.sin(rz) * cosx, math.cos(rz) * cosx, math.sin(rx))
end

local function isGuard(ent)
    for _, g in ipairs(guards) do if g.ped == ent then return true end end
    return false
end

local function guardByPed(ped)
    for _, g in ipairs(guards) do if g.ped == ped then return g end end
    return nil
end

local function isOurs(ent)
    if ent == PlayerPedId() or isGuard(ent) then return true end
    if escort and ent == escort.veh then return true end
    if air and ent == air.veh then return true end
    local v = myVehicle()
    return v ~= 0 and ent == v
end

local function aimedTarget()
    local ok, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if ok and ent ~= 0 and DoesEntityExist(ent) and not isOurs(ent) then return ent end
    local camPos, fwd = GetGameplayCamCoord(), camForward()
    local cosLimit = math.cos(math.rad(Config.TargetConeDegrees))
    local best, bestDot = 0, -1
    local function consider(e)
        if isOurs(e) or IsEntityDead(e) then return end
        local d = GetEntityCoords(e) - camPos
        local dist = #d
        if dist < 1.0 or dist > Config.TargetRange then return end
        local dot = (d.x * fwd.x + d.y * fwd.y + d.z * fwd.z) / dist
        if dot > cosLimit and dot > bestDot then best, bestDot = e, dot end
    end
    for _, p in ipairs(GetGamePool('CPed')) do consider(p) end
    for _, v in ipairs(GetGamePool('CVehicle')) do consider(v) end
    return best
end

local function resolvePedTarget(target)
    if target == 0 or not DoesEntityExist(target) then return 0 end
    if GetEntityType(target) == 2 then
        local drv = GetPedInVehicleSeat(target, -1)
        if drv == 0 then return 0 end
        target = drv
    end
    if GetEntityType(target) ~= 1 or IsEntityDead(target) or isOurs(target) then return 0 end
    return target
end

local function isDriverPed(ped)
    if chauffeur and chauffeur.guard == ped then return true end
    if escort and escort.driver == ped then return true end
    if air and air.pilot == ped then return true end
    return false
end

local function inAirVehicle(ped) return air and IsPedInVehicle(ped, air.veh, false) end
local function inEscortVehicle(ped) return escort and IsPedInVehicle(ped, escort.veh, false) end

---------------------------------------------------------------------------
-- behaviour
---------------------------------------------------------------------------
local FOLLOW_TASK = joaat('SCRIPT_TASK_FOLLOW_TO_OFFSET_OF_ENTITY')
local COMBAT_TASK = joaat('SCRIPT_TASK_COMBAT')

local function inCombat(ped)
    local s = GetScriptTaskStatus(ped, COMBAT_TASK)
    return s == 0 or s == 1 or IsPedInCombat(ped, 0) or IsPedShooting(ped)
end

local function applyMode(g)
    local p = g.ped
    if not alive(g) or isDriverPed(p) or inEscortVehicle(p) or inAirVehicle(p) then return end
    ClearPedTasks(p)
    g.followKey, g.lastTarget, g.goActive = nil, nil, false
    if g.hold and g.holdPos then                 -- walking to an ordered position: the loop drives it
        g.holdArrived, g.goAt = false, 0
        return
    end
    local effective = g.hold and 'hold' or mode
    if effective == 'passive' then
        SetBlockingOfNonTemporaryEvents(p, true)
        SetPedCombatAttributes(p, 46, false)
    elseif effective == 'hold' then
        SetBlockingOfNonTemporaryEvents(p, false)
        SetPedCombatAttributes(p, 46, true)
        local c = GetEntityCoords(p)
        TaskStandGuard(p, c.x, c.y, c.z, GetEntityHeading(p), 'WORLD_HUMAN_GUARD_STAND')
    else
        SetBlockingOfNonTemporaryEvents(p, false)
        SetPedCombatAttributes(p, 46, true)
    end
end

local function setMode(m)
    mode = m
    for _, g in ipairs(guards) do g.hold = nil end
    eachAlive(applyMode)
    logEvent('hot', 'Mode: %s', m:upper())
end

local function setFormation(f)
    formation = f
    for _, g in ipairs(guards) do g.followKey = nil; g.lastTarget = nil end
end

local function presetOffset(i, f)
    local sp = settings.spacing
    local side = (i % 2 == 1) and -1 or 1
    local rank = math.ceil(i / 2)
    if f == 1 then
        local a = math.rad((i - 1) * (360 / math.max(4, #guards)))
        return math.sin(a) * sp * 1.4, math.cos(a) * sp * 1.4
    elseif f == 2 then
        return side * sp * rank, -sp * rank
    elseif f == 3 then
        return side * sp * rank, 0.0
    end
    return side * sp * 0.8, -sp * rank
end

local function formationOffset(i)
    if formation == 4 then
        local o = settings.customOffsets[i] or settings.customOffsets[tostring(i)]
        if o and o.x and o.y then return o.x + 0.0, o.y + 0.0 end
        return presetOffset(i, 0)
    end
    local sp = settings.spacing
    local side = (i % 2 == 1) and -1 or 1
    local rank = math.ceil(i / 2)
    if formation == 1 then
        local a = math.rad((i - 1) * (360 / math.max(4, #guards)))
        return math.sin(a) * sp * 1.4, math.cos(a) * sp * 1.4
    elseif formation == 2 then
        return side * sp * rank, -sp * rank
    elseif formation == 3 then
        return side * sp * rank, 0.0
    end
    return side * sp * 0.8, -sp * rank
end

-- seat helpers: settings.seats["-1"] = driver, ["0"] = front passenger, ["1"]... rear
local function seatOfGuard(g)
    for k, name in pairs(settings.seats) do
        if name == g.name then return tonumber(k) end
    end
    return nil
end

local function designatedDriver()
    local name = settings.seats['-1']
    if not name or name == '' then return nil end
    for _, g in ipairs(guards) do if g.name == name and alive(g) then return g end end
    return nil
end

-- New guards take the next free PASSENGER seat (front, rear L, rear R, ...). The driver seat
-- is never auto-assigned: you drive unless you pick a chauffeur on the Vehicle page.
local function assignDefaultSeat(g)
    if seatOfGuard(g) then return end
    for s = 0, 4 do
        local k = tostring(s)
        if not settings.seats[k] or settings.seats[k] == '' then settings.seats[k] = g.name; return end
    end
end

local function clearSeat(g)
    for k, n in pairs(settings.seats) do if n == g.name then settings.seats[k] = nil end end
end

-- names
local function nameInUse(n)
    for _, g in ipairs(guards) do if g.name == n then return true end end
    return false
end

local function uniqueName(base)
    if not nameInUse(base) then return base end
    for i = 2, 9 do local n = ('%s %d'):format(base, i); if not nameInUse(n) then return n end end
    return ('%s %d'):format(base, math.random(10, 99))
end

local function randomName()
    local pool = {}
    for _, n in ipairs(Config.Names) do if not nameInUse(n) then pool[#pool + 1] = n end end
    if #pool == 0 then return uniqueName('Guard') end
    return pool[math.random(#pool)]
end

-- veterancy
local function rankOf(kills)
    local r = Config.Ranks[1]
    for _, x in ipairs(Config.Ranks) do if (kills or 0) >= x.kills then r = x end end
    return r
end

local function applyRank(g)
    local r = rankOf(g.kills)
    g.rank = r.label
    g.maxArmour = (g.baseArmour or Config.Armour) + (r.armour or 0)
    if DoesEntityExist(g.ped) then
        SetPedAccuracy(g.ped, math.min(100, (g.baseAccuracy or settings.accuracy) + (r.accuracy or 0)))
    end
end

-- Formation slots are WORLD positions built from the direction I'm moving (not the way I'm
-- looking), so guards don't orbit me when I turn my head. Each guard walks/runs/sprints to its
-- slot with a navmesh task and simply stands when it's there and I'm not moving.
local lastMoveHeading = nil
local lastMoveSpeed = 0.0

local function updateMoveHeading()
    local me = PlayerPedId()
    local v = GetEntityVelocity(me)
    lastMoveSpeed = math.sqrt(v.x * v.x + v.y * v.y)
    if lastMoveSpeed > 0.8 then
        lastMoveHeading = math.deg(math.atan(-v.x, v.y))
    elseif not lastMoveHeading then
        lastMoveHeading = GetEntityHeading(me)
    end
end

local function slotWorldPos(i, origin, heading)
    local ox, oy = formationOffset(i)
    local r = math.rad(heading)
    local fwd = vector3(-math.sin(r), math.cos(r), 0.0)
    local right = vector3(math.cos(r), math.sin(r), 0.0)
    return origin + right * ox + fwd * oy
end

local function stopGo(g)
    if g.goActive then
        ClearPedTasks(g.ped)
        g.goActive = false
        g.lastTarget = nil
    end
end

local function follow(g, i)
    local me = PlayerPedId()
    local target = slotWorldPos(i, GetEntityCoords(me), lastMoveHeading or GetEntityHeading(me))
    local gpos = GetEntityCoords(g.ped)
    local d = #(target - gpos)
    local now = GetGameTimer()
    local iMove = lastMoveSpeed > 0.8

    if not iMove then
        -- I'm standing still: settle precisely onto the slot, then face my direction
        if d <= 0.6 then
            if g.goActive then
                ClearPedTasks(g.ped)
                TaskAchieveHeading(g.ped, lastMoveHeading or GetEntityHeading(me), 800)
                g.goActive, g.lastTarget = false, target
            end
            return
        end
        if (g.goAt or 0) + 1500 < now or not g.lastTarget or #(target - g.lastTarget) > 0.5 then
            g.lastTarget, g.goAt, g.goActive = target, now, true
            if d < 5.0 then
                TaskGoStraightToCoord(g.ped, target.x, target.y, target.z, 1.0, -1, lastMoveHeading or GetEntityHeading(me), 0.15)
            else
                TaskFollowNavMeshToCoord(g.ped, target.x, target.y, target.z, d > 20.0 and 3.0 or 2.0, -1, 0.3, 0, 0.0)
            end
        end
        return
    end
    local retask = not g.lastTarget or #(target - g.lastTarget) > 1.5 or (g.goAt or 0) + 2500 < now
    if not retask then return end
    g.lastTarget, g.goAt, g.goActive = target, now, true
    -- pace: match me, but sprint when far behind. No teleports, ever.
    local speed = 1.0
    if d > 25.0 or lastMoveSpeed > 6.0 then speed = 3.0
    elseif d > 6.0 or lastMoveSpeed > 2.6 then speed = 2.0 end
    TaskFollowNavMeshToCoord(g.ped, target.x, target.y, target.z, speed, -1, 0.5, 0, 0.0)
end

---------------------------------------------------------------------------
-- spawn / dismiss
---------------------------------------------------------------------------
local function ensureBlip(g)
    if settings.blips then
        if g.blip == 0 or not DoesBlipExist(g.blip) then
            g.blip = AddBlipForEntity(g.ped)
            SetBlipSprite(g.blip, 1); SetBlipColour(g.blip, 3); SetBlipScale(g.blip, 0.7); SetBlipAsShortRange(g.blip, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(g.name); EndTextCommandSetBlipName(g.blip)
        end
    elseif g.blip ~= 0 and DoesBlipExist(g.blip) then
        RemoveBlip(g.blip); g.blip = 0
    end
end

local function giveWeapon(g, w)
    local wh = joaat(w.name)
    RemoveAllPedWeapons(g.ped, true)
    GiveWeaponToPed(g.ped, wh, 9999, false, true)
    SetPedInfiniteAmmo(g.ped, true, wh)
    SetCurrentPedWeapon(g.ped, wh, true)
    g.weapon = w.label
end

-- opts (all optional): model, modelLabel, weapon, weaponLabel, health, armour, accuracy, name,
-- contract, kills, tierId, tierLabel, at (vector4). No opts = admin recruit from the panel pickers.
local function spawnGuard(opts)
    opts = opts or {}
    local me = PlayerPedId()
    local modelName, modelLabel, w
    if opts.model then
        modelName, modelLabel = opts.model, opts.modelLabel or 'Guard'
        w = { name = opts.weapon, label = opts.weaponLabel or opts.weapon:gsub('^WEAPON_', '') }
    else
        local m = findById(Config.Models, settings.recruitModel) or pick(Config.Models)
        w = findById(Config.Weapons, settings.recruitWeapon) or pick(Config.Weapons)
        modelName, modelLabel = m.model, m.label
    end
    local model = joaat(modelName)
    if not loadModel(model) then notify('~r~Bodyguard model failed to load'); return false end

    local pos, heading
    if opts.at then
        pos, heading = vector3(opts.at.x, opts.at.y, opts.at.z), opts.at.w or GetEntityHeading(me)
        local ok, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 2.0, false)
        if ok then pos = vector3(pos.x, pos.y, gz) end
    else
        pos, heading = GetOffsetFromEntityInWorldCoords(me, math.random(-2, 2) + 0.0, -2.0, 0.0), GetEntityHeading(me)
    end
    local ped = CreatePed(4, model, pos.x, pos.y, pos.z, heading, true, true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return false end

    local health = opts.health or Config.Health
    local armour = opts.armour or Config.Armour
    local accuracy = opts.accuracy or settings.accuracy

    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, GUARD_REL)
    SetPedCanBeTargetted(ped, true)
    SetPedMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, armour)
    SetEntityInvincible(ped, isAdmin and settings.invincible or false)
    SetPedSuffersCriticalHits(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedAccuracy(ped, accuracy)
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAttributes(ped, 1, true)
    SetPedCombatAttributes(ped, 2, true)
    SetPedCombatAttributes(ped, 3, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanSwitchWeapon(ped, true)
    SetCanAttackFriendly(ped, false, false)
    SetPedKeepTask(ped, true)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.0)

    local g = {
        ped = ped, name = opts.name and uniqueName(opts.name) or randomName(),
        model = modelLabel, weapon = w.label, blip = 0, modelHash = GetEntityModel(ped),
        kills = opts.kills or 0, contract = opts.contract, tierId = opts.tierId, tier = opts.tierLabel or 'Admin',
        modelName = modelName, weaponName = w.name,
        maxHealth = health, baseArmour = armour, maxArmour = armour, baseAccuracy = accuracy,
    }
    giveWeapon(g, w)
    guards[#guards + 1] = g
    applyRank(g)
    assignDefaultSeat(g)
    ensureBlip(g)
    applyMode(g)
    if g.contract then
        logEvent('', '%s on duty (%s, %s)', g.name, g.tier, w.label)
    else
        logEvent('', '%s recruited (%s, %s)', g.name, modelLabel, w.label)
    end
    return g
end

-- Guards left over from a previous start of this resource (still tagged with our relationship
-- group) are removed; contracted guards are re-created from the database instead.
local function cleanupLeftovers()
    local removed = 0
    for _, p in ipairs(GetGamePool('CPed')) do
        local sameRel = (GetPedRelationshipGroupHash(p) - GUARD_REL) % 4294967296 == 0
        if p ~= PlayerPedId() and sameRel and not isGuard(p) and NetworkGetEntityOwner(p) == PlayerId() then
            SetEntityAsMissionEntity(p, true, true)
            DeleteEntity(p)
            removed = removed + 1
        end
    end
    if removed > 0 then dbg('removed %d leftover guard ped(s)', removed) end
end

---------------------------------------------------------------------------
-- contracts (Agency hires persisted on the server)
---------------------------------------------------------------------------
local function contractGuard(id)
    for _, g in ipairs(guards) do if g.contract == id then return g end end
    return nil
end

local function spawnContract(c, at)
    if contractGuard(c.id) then return contractGuard(c.id) end
    local t = tierById(c.tier) or Config.Tiers[1]
    if not at then
        local me = PlayerPedId()
        local p = GetOffsetFromEntityInWorldCoords(me, math.random(-3, 3) + 0.0, -5.0 - math.random() * 3.0, 0.0)
        at = vector4(p.x, p.y, p.z, GetEntityHeading(me))
    end
    return spawnGuard({
        model = c.model, modelLabel = t.label, weapon = c.weapon, weaponLabel = t.weaponLabel,
        health = t.health, armour = t.armour, accuracy = t.accuracy,
        name = c.name, contract = c.id, kills = c.kills or 0, tierId = t.id, tierLabel = t.label, at = at,
    })
end

local function contractCount()
    local n = 0
    for _, g in ipairs(guards) do if g.contract then n = n + 1 end end
    return n
end

local function endContract(g, reason)
    if g.contract then TriggerServerEvent('nk_bodyguard:contractEnd', g.contract, reason) end
end

local stopEscort, stopAir -- forward

local function hardDelete(ped)
    if not DoesEntityExist(ped) then return end
    RemovePedFromGroup(ped)
    ClearPedTasksImmediately(ped)
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
    if DoesEntityExist(ped) then DeletePed(ped) end
    if DoesEntityExist(ped) then SetEntityAsNoLongerNeeded(ped) end
end

-- endIt = true: the contract is terminated (dismissed). false: only the ped is removed
-- (resource restart, logout) and the contract comes back next time.
local function removeGuard(g, why, endIt)
    dbg('removing %s (ped %d): %s', g.name, g.ped, why or 'dismissed')
    if endIt then endContract(g, 'dismissed'); clearSeat(g) end
    if g.blip ~= 0 and DoesBlipExist(g.blip) then RemoveBlip(g.blip) end
    if isSamePed(g) then hardDelete(g.ped) elseif DoesEntityExist(g.ped) then RemovePedFromGroup(g.ped) end
    if chauffeur and chauffeur.guard == g.ped then chauffeur = nil end
    if escort and escort.driver == g.ped then stopEscort(true) end
    if air and air.pilot == g.ped then stopAir(true) end
end

local function dismissAll(why, endIt)
    stopEscort(true); stopAir(true)
    for _, g in ipairs(guards) do removeGuard(g, why, endIt) end
    guards = {}
    reinforceQueue = {}
    respawnQueue = {}
    if endIt then logEvent('bad', 'Squad dismissed, contracts terminated') end
end

---------------------------------------------------------------------------
-- orders
---------------------------------------------------------------------------
local function driveBy(ped, target)
    TaskDriveBy(ped, target, 0, 0.0, 0.0, 0.0, 300.0, 100, true, `FIRING_PATTERN_FULL_AUTO`)
end

local function orderAttack(target, announce)
    target = resolvePedTarget(target)
    if target == 0 then
        if announce then notify('~y~No target in your sights') end
        return
    end
    local n = 0
    eachAlive(function(g)
        if isDriverPed(g.ped) or mode == 'passive' then return end
        if IsPedInAnyVehicle(g.ped, false) then driveBy(g.ped, target) else TaskCombatPed(g.ped, target, 0, 16) end
        g.followKey = nil
        n = n + 1
    end)
    if announce then notify('Squad: ATTACK') end
    if n > 0 then logEvent('hot', 'Attack order: %d guard(s) engaging', n) end
end

local function orderDriveBy()
    local target = resolvePedTarget(aimedTarget())
    if target == 0 then notify('~y~Aim at a target first'); return end
    local n = 0
    eachAlive(function(g)
        if IsPedInAnyVehicle(g.ped, false) and not isDriverPed(g.ped) then driveBy(g.ped, target); n = n + 1 end
    end)
    notify(n > 0 and ('Drive-by: %d guard(s) firing'):format(n) or '~y~No guards riding as passengers')
end

local function orderCover()
    local me = PlayerPedId()
    eachAlive(function(g)
        if isDriverPed(g.ped) or IsPedInAnyVehicle(g.ped, false) then return end
        g.hold = true
        TaskStayInCover(g.ped)
        g.followKey = nil
    end)
    logEvent('hot', 'Squad taking cover')
end

local function orderCeasefire()
    focus = nil
    eachAlive(function(g)
        if isDriverPed(g.ped) then return end
        ClearPedTasks(g.ped)
        g.followKey, g.lastTarget, g.goActive = nil, nil, false
        g.hold, g.holdPos = nil, nil
    end)
    logEvent('', 'Cease fire')
end

local function orderGotoWaypoint()
    local wp = GetFirstBlipInfoId(8)
    if not DoesBlipExist(wp) then notify('~y~Set a waypoint on the map first'); return end
    local dest = GetBlipInfoIdCoord(wp)
    local i = 0
    eachAlive(function(g)
        if isDriverPed(g.ped) or IsPedInAnyVehicle(g.ped, false) then return end
        i = i + 1
        g.hold = true
        local ox, oy = formationOffset(i)
        TaskGoToCoordAnyMeans(g.ped, dest.x + ox, dest.y + oy, dest.z, 3.0, 0, false, 786603, 0.0)
        g.followKey = nil
    end)
    logEvent('hot', 'Squad moving to waypoint')
end

local function orderEnter()
    local veh = myVehicle()
    if veh == 0 then notify('~y~Get in a vehicle first'); return end
    eachAlive(function(g)
        if not IsPedInVehicle(g.ped, veh, false) and not isDriverPed(g.ped) then TaskEnterVehicle(g.ped, veh, 8000, -2, 2.0, 1, 0) end
    end)
    logEvent('', 'Squad: mount up')
end

local function orderExit()
    eachAlive(function(g) if IsPedInAnyVehicle(g.ped, false) then TaskLeaveAnyVehicle(g.ped, 0, 0) end end)
    chauffeur = nil
    stopEscort(true); stopAir(true)
    logEvent('', 'Squad: dismount')
end

-- "Come to me": no teleport. Drop whatever they're doing and sprint back into formation.
local function warpGuard(g, i)
    g.hold, g.holdPos, g.lastTarget, g.goActive = nil, nil, nil, false
    if IsPedInAnyVehicle(g.ped, false) and not isDriverPed(g.ped) then TaskLeaveAnyVehicle(g.ped, 0, 0) end
    ClearPedTasks(g.ped)
    local me = PlayerPedId()
    local target = slotWorldPos(i, GetEntityCoords(me), lastMoveHeading or GetEntityHeading(me))
    TaskFollowNavMeshToCoord(g.ped, target.x, target.y, target.z, 3.0, -1, 1.0, 0, 0.0)
    g.goActive, g.goAt, g.lastTarget = true, GetGameTimer(), target
end

local function orderWarp()
    local i = 0
    eachAlive(function(g) if not isDriverPed(g.ped) then i = i + 1; warpGuard(g, i) end end)
    chauffeur = nil
    stopEscort(true); stopAir(true)
    logEvent('', 'Squad rallying to you')
end

local function healGuard(g)
    SetEntityHealth(g.ped, GetEntityMaxHealth(g.ped))
    SetPedArmour(g.ped, g.maxArmour or Config.Armour)
    ClearPedBloodDamage(g.ped)
end

local function injured(g)
    return GetEntityHealth(g.ped) < GetEntityMaxHealth(g.ped) or GetPedArmour(g.ped) < (g.maxArmour or Config.Armour)
end

local function orderHeal()
    eachAlive(healGuard)
    logEvent('', 'Squad healed')
end

-- Citizens pay for services; admins get them free. fn runs only after a successful payment.
local function withPayment(service, qty, fn)
    if isAdmin then fn(); return end
    CreateThread(function()
        local ok, msg = request('pay', service, qty)
        if ok then
            if msg ~= '' then notify('~g~' .. msg) end
            fn()
        else
            notify('~r~' .. msg)
        end
    end)
end

---------------------------------------------------------------------------
-- marking modes: "Mark & attack" / "Move to position" (squad-wide or one guard)
---------------------------------------------------------------------------
local marking = nil     -- { kind = 'attack'|'move', scope = guardIndex|nil, outlined = ent }

local function scopeGuards(scope, fn)
    if scope then
        local g = guards[scope]
        if g and alive(g) then fn(g, scope) end
    else
        eachAlive(fn)
    end
end

---------------------------------------------------------------------------
-- focus: keep attacking a marked ped until dead / a marked vehicle until wrecked
---------------------------------------------------------------------------
local SHOOT_TASK = joaat('SCRIPT_TASK_SHOOT_AT_ENTITY')
local GOTO_ENT_TASK = joaat('SCRIPT_TASK_GO_TO_ENTITY')

local function focusDone()
    if not focus then return true end
    if not DoesEntityExist(focus.ent) then return true end
    if focus.kind == 'ped' then return IsEntityDead(focus.ent) end
    return IsEntityDead(focus.ent) or GetVehicleEngineHealth(focus.ent) <= 0.0
end

local function pressFocus(g)
    local p = g.ped
    if focus.kind == 'ped' then
        if IsPedInAnyVehicle(p, false) then driveBy(p, focus.ent) else TaskCombatPed(p, focus.ent, 0, 16) end
    else
        if IsPedInAnyVehicle(p, false) then
            TaskDriveBy(p, 0, focus.ent, 0.0, 0.0, 0.0, 300.0, 100, true, `FIRING_PATTERN_FULL_AUTO`)
        else
            local d = #(GetEntityCoords(p) - GetEntityCoords(focus.ent))
            if d > 35.0 then
                TaskGoToEntity(p, focus.ent, -1, 25.0, 3.0, 1073741824, 0)
            else
                TaskShootAtEntity(p, focus.ent, -1, `FIRING_PATTERN_FULL_AUTO`)
            end
        end
    end
    g.lastTarget, g.goActive = nil, false
end

local function focusing(g)
    if not focus then return false end
    if focus.scope then return guards[focus.scope] == g end
    return true
end

local function focusTick()
    if not focus then return end
    if focusDone() then
        logEvent('hot', focus.kind == 'ped' and 'Target down' or 'Target vehicle destroyed')
        focus = nil
        return
    end
    local now = GetGameTimer()
    if now - (focus.at or 0) < 1000 then return end
    focus.at = now
    scopeGuards(focus.scope, function(g)
        if isDriverPed(g.ped) then return end
        local busy
        if focus.kind == 'ped' then
            busy = IsPedInCombat(g.ped, focus.ent)
        else
            local s1, s2 = GetScriptTaskStatus(g.ped, SHOOT_TASK), GetScriptTaskStatus(g.ped, GOTO_ENT_TASK)
            busy = (s1 == 0 or s1 == 1) or (s2 == 0 or s2 == 1)
            if busy and (s2 == 0 or s2 == 1) and #(GetEntityCoords(g.ped) - GetEntityCoords(focus.ent)) < 30.0 then busy = false end
        end
        if not busy then pressFocus(g) end
    end)
end

local function orderMoveTo(coords, scope)
    local n = 0
    scopeGuards(scope, function(g, i)
        if isDriverPed(g.ped) then return end
        if IsPedInAnyVehicle(g.ped, false) then TaskLeaveAnyVehicle(g.ped, 0, 0) end
        n = n + 1
        -- squad move: spread around the point in the current formation; single guard: exact spot
        local dest = scope and coords or slotWorldPos(n, coords, lastMoveHeading or GetEntityHeading(PlayerPedId()))
        g.hold, g.holdPos, g.holdArrived, g.goAt, g.lastTarget, g.goActive = true, dest, false, 0, nil, false
        ClearPedTasks(g.ped)
    end)
    logEvent('hot', '%s moving to position', scope and guards[scope].name or ('Squad (%d)'):format(n))
end

-- a marked entity: any ped (incl. drivers) or any vehicle that is not ours
local function markTarget(ent)
    if ent == 0 or not DoesEntityExist(ent) or isOurs(ent) or IsEntityDead(ent) then return 0, nil end
    local t = GetEntityType(ent)
    if t == 1 then return ent, 'ped' end
    if t == 2 then return ent, 'veh' end
    return 0, nil
end

local function orderAttackScoped(ent, scope)
    local target, kind = markTarget(ent)
    if target == 0 then notify('~y~That is not a valid target'); return end
    focus = { ent = target, kind = kind, scope = scope, at = 0 }
    local n = 0
    scopeGuards(scope, function(g)
        if isDriverPed(g.ped) then return end
        g.hold, g.holdPos = nil, nil
        ClearPedTasks(g.ped)
        n = n + 1
    end)
    focusTick()
    local what = kind == 'ped' and 'target' or 'vehicle'
    logEvent('hot', '%s attacking marked %s until it is %s', scope and guards[scope].name or ('Squad (%d)'):format(n), what, kind == 'ped' and 'dead' or 'destroyed')
end

local function clearOutline()
    if marking and marking.outlined and DoesEntityExist(marking.outlined) then SetEntityDrawOutline(marking.outlined, false) end
    if marking then marking.outlined = nil end
end

local function stopMarking(silent)
    clearOutline()
    marking = nil
    if not silent then notify('Marking cancelled') end
end

local function startMarking(kind, scope)
    if #guards == 0 then notify('~y~No guards'); return end
    marking = { kind = kind, scope = scope }
    local who = scope and guards[scope] and guards[scope].name or 'Squad'
    notify(kind == 'attack' and ('%s: aim at a target, press E'):format(who) or ('%s: aim at the ground, press E'):format(who))
end

-- Aim probe from the camera. Anything that is "ours" (me, my vehicle, my guards, escort, heli)
-- is skipped by re-casting from just past the hit, so marking works from inside a vehicle too.
local function camRay()
    local fwd = camForward()
    local start = GetGameplayCamCoord()
    local ignore = PlayerPedId()
    for _ = 1, 4 do
        local dest = start + fwd * 250.0
        local ray = StartExpensiveSynchronousShapeTestLosProbe(start.x, start.y, start.z, dest.x, dest.y, dest.z, -1, ignore, 7)
        local _, hit, endCoords, _, ent = GetShapeTestResult(ray)
        if hit ~= 1 then return 0, dest, 0 end
        if ent ~= 0 and isOurs(ent) then
            start = endCoords + fwd * 1.5
            ignore = ent
        else
            return hit, endCoords, ent
        end
    end
    return 0, start, 0
end


CreateThread(function()
    while true do
        if not marking then
            Wait(200)
        else
            Wait(0)
            local hit, pos, ent = camRay()
            local valid = false
            -- screen-centre reticle so you always see where the probe is going
            DrawRect(0.5, 0.5, 0.0025, 0.004, 255, 255, 255, 180)
            if marking.kind == 'attack' then
                local t, kind = markTarget(ent)
                if t ~= 0 then
                    valid = true
                    if marking.outlined ~= t then clearOutline(); marking.outlined = t; SetEntityDrawOutline(t, true); SetEntityDrawOutlineColor(255, 60, 60, 255) end
                    local p = GetEntityCoords(t)
                    local zoff = kind == 'veh' and 2.2 or 1.4
                    DrawMarker(0, p.x, p.y, p.z + zoff, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.6, 0.6, 0.6, 255, 60, 60, 220, true, true, 2, false, nil, nil, false)
                    DrawMarker(25, pos.x, pos.y, pos.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 60, 60, 160, false, false, 2, false, nil, nil, false)
                else
                    clearOutline()
                    if hit == 1 then DrawMarker(25, pos.x, pos.y, pos.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8, 255, 255, 255, 110, false, false, 2, false, nil, nil, false) end
                end
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(valid and ('~r~%s marked~s~. Press ~INPUT_PICKUP~ to attack until %s, ~INPUT_FRONTEND_CANCEL~ to cancel'):format(kind == 'veh' and 'Vehicle' or 'Target', kind == 'veh' and 'destroyed' or 'dead') or 'Aim at a ped or vehicle. ~INPUT_FRONTEND_CANCEL~ to cancel')
                EndTextCommandDisplayHelp(0, false, false, -1)
            else
                if hit == 1 and pos then
                    valid = true
                    DrawMarker(1, pos.x, pos.y, pos.z - 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 1.2, 40, 220, 90, 110, false, false, 2, false, nil, nil, false)
                end
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(valid and 'Press ~INPUT_PICKUP~ to send them here, ~INPUT_FRONTEND_CANCEL~ to cancel' or 'Aim at the ground. ~INPUT_FRONTEND_CANCEL~ to cancel')
                EndTextCommandDisplayHelp(0, false, false, -1)
            end

            if IsControlJustPressed(0, 38) and valid then          -- E
                if marking.kind == 'attack' then orderAttackScoped(ent, marking.scope) else orderMoveTo(pos, marking.scope) end
                stopMarking(true)
            elseif IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) or IsControlJustPressed(0, 202) then
                stopMarking(false)
            end
        end
    end
end)

local function sendHome(g, idx)
    logEvent('', '%s sent home%s', g.name, g.contract and ', contract ended' or '')
    endContract(g, 'dismissed')
    clearSeat(g)
    if g.blip ~= 0 and DoesBlipExist(g.blip) then RemoveBlip(g.blip) end
    if DoesEntityExist(g.ped) then
        SetPedRelationshipGroupHash(g.ped, joaat('CIVMALE'))   -- no longer ours; adopt won't pick it up
        ClearPedTasks(g.ped)
        SetBlockingOfNonTemporaryEvents(g.ped, false)
        TaskWanderStandard(g.ped, 10.0, 10)
        SetEntityAsMissionEntity(g.ped, false, true)
        SetPedAsNoLongerNeeded(g.ped)
    end
    if chauffeur and chauffeur.guard == g.ped then chauffeur = nil end
    table.remove(guards, idx)
end

---------------------------------------------------------------------------
-- driving tuning / chauffeur
---------------------------------------------------------------------------
local function applyDriveTuning(driverPed, veh)
    local s = style()
    if DoesEntityExist(driverPed) then
        SetDriverAbility(driverPed, 1.0)
        SetDriverAggressiveness(driverPed, s.aggro or 0.0)
        SetDriveTaskDrivingStyle(driverPed, s.style)
        SetDriveTaskMaxCruiseSpeed(driverPed, s.speed)
    end
    if DoesEntityExist(veh) then
        ModifyVehicleTopSpeed(veh, (s.boost or 0) + 0.0)
        SetVehicleEnginePowerMultiplier(veh, (s.boost or 0) > 0 and (s.boost / 2.0) or 0.0)
    end
end

local function resetDriveTuning(veh)
    if DoesEntityExist(veh) then
        ModifyVehicleTopSpeed(veh, 0.0)
        SetVehicleEnginePowerMultiplier(veh, 0.0)
    end
end

local function pickDriver(veh, exclude)
    local driver
    eachAlive(function(g) if not driver and g.ped ~= exclude and IsPedInVehicle(g.ped, veh, false) and not isDriverPed(g.ped) then driver = g end end)
    if not driver then eachAlive(function(g) if not driver and g.ped ~= exclude and not isDriverPed(g.ped) then driver = g end end) end
    return driver
end

local function takeWheel(driver, veh)
    local me = PlayerPedId()
    if GetPedInVehicleSeat(veh, -1) == me then
        local moved = false
        for seat = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            if IsVehicleSeatFree(veh, seat) then SetPedIntoVehicle(me, veh, seat); moved = true; break end
        end
        if not moved then notify('~y~No free passenger seat'); return false end
    end
    local cur = GetPedInVehicleSeat(veh, -1)
    if cur ~= 0 and cur ~= driver.ped then
        for seat = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
            if IsVehicleSeatFree(veh, seat) then SetPedIntoVehicle(cur, veh, seat); break end
        end
    end
    SetBlockingOfNonTemporaryEvents(driver.ped, true)
    SetPedIntoVehicle(driver.ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    applyDriveTuning(driver.ped, veh)
    return true
end

local function startChauffeur(kind, chosen)
    local veh = myVehicle()
    if veh == 0 then notify('~y~Sit in the vehicle you want driven'); return end
    local dest
    if kind == 'waypoint' then
        local wp = GetFirstBlipInfoId(8)
        if not DoesBlipExist(wp) then notify('~y~Set a waypoint on the map first'); return end
        dest = GetBlipInfoIdCoord(wp)
    elseif kind == 'keep' and chauffeur then
        dest, kind = chauffeur.dest, chauffeur.kind
    end
    local driver = chosen or pickDriver(veh, chauffeur and chauffeur.guard or nil)
    if not driver then notify('~y~No guards available'); return end
    if chauffeur and chauffeur.guard ~= driver.ped and DoesEntityExist(chauffeur.guard) then
        SetBlockingOfNonTemporaryEvents(chauffeur.guard, false)
    end
    if not takeWheel(driver, veh) then return end
    local s = style()
    if kind == 'waypoint' and dest then
        TaskVehicleDriveToCoordLongrange(driver.ped, veh, dest.x, dest.y, dest.z, s.speed, s.style, Config.ArriveDistance)
    elseif kind == 'wait' then
        ClearPedTasks(driver.ped)                    -- sits at the wheel until a waypoint is set
    else
        kind = 'cruise'
        TaskVehicleDriveWander(driver.ped, veh, s.speed, s.style)
    end
    chauffeur = { guard = driver.ped, veh = veh, dest = dest, kind = kind }
    logEvent('hot', '%s at the wheel (%s, %s)', driver.name, kind == 'wait' and 'waiting for waypoint' or kind, s.label)
end

local function stopChauffeur(silent)
    if not chauffeur then return end
    local g = chauffeur.guard
    if DoesEntityExist(g) and DoesEntityExist(chauffeur.veh) then
        TaskVehicleTempAction(g, chauffeur.veh, 27, 2500)
        resetDriveTuning(chauffeur.veh)
        Wait(300)
        SetBlockingOfNonTemporaryEvents(g, false)
    end
    chauffeur = nil
    local gg = guardByPed(g); if gg then applyMode(gg) end
    if not silent then logEvent('', 'Chauffeur stopped') end
end

local function retaskChauffeur()
    if not chauffeur then return end
    local s = style()
    applyDriveTuning(chauffeur.guard, chauffeur.veh)
    if chauffeur.kind == 'waypoint' and chauffeur.dest then
        TaskVehicleDriveToCoordLongrange(chauffeur.guard, chauffeur.veh, chauffeur.dest.x, chauffeur.dest.y, chauffeur.dest.z, s.speed, s.style, Config.ArriveDistance)
    elseif chauffeur.kind == 'wait' then
        TaskVehicleTempAction(chauffeur.guard, chauffeur.veh, 27, 1000)
    else
        TaskVehicleDriveWander(chauffeur.guard, chauffeur.veh, s.speed, s.style)
    end
end

---------------------------------------------------------------------------
-- escort car
---------------------------------------------------------------------------
-- Runs every 200 ms (own thread). Reacts immediately when I get in or out of a vehicle, re-kicks
-- a stalled follow at once, and switches to a catch-up pace when the escort has fallen behind.
-- The escort car is never teleported.
local function escortTask()
    if not escort or not DoesEntityExist(escort.veh) or not DoesEntityExist(escort.driver) then return end
    local me = PlayerPedId()
    local target = myVehicle()
    if target == 0 then target = me end
    local s = style()
    local now = GetGameTimer()
    local d = #(GetEntityCoords(escort.veh) - GetEntityCoords(me))
    local far = d > 60.0
    local stalled = false
    if (escort.kickAt or 0) + 1000 < now and GetEntitySpeed(escort.veh) < 0.8 and d > Config.EscortDistance + 4.0 then
        stalled = true; escort.kickAt = now
    end
    if target ~= escort.following or escort.styleKey ~= driveStyle or stalled or far ~= escort.far then
        escort.following, escort.styleKey, escort.far = target, driveStyle, far
        applyDriveTuning(escort.driver, escort.veh)
        if target == me then
            -- on foot: crawl along at walking-escort pace, or hurry if it's far behind
            local spd = far and math.max(s.speed, 30.0) or math.min(s.speed, 18.0)
            TaskVehicleFollow(escort.driver, escort.veh, me, spd, s.style, math.max(5.0, Config.EscortDistance * 0.6))
        else
            local spd = far and math.max(s.speed, 45.0) or s.speed
            local gap = (s.aggro or 0) >= 0.7 and Config.EscortDistance * 0.6 or Config.EscortDistance
            TaskVehicleEscort(escort.driver, escort.veh, target, -1, spd, s.style, gap, 0, 20.0)
        end
    end
end

local function spareGuards()
    local free = {}
    local myVeh = myVehicle()
    eachAlive(function(g)
        if not isDriverPed(g.ped) and not inEscortVehicle(g.ped) and not inAirVehicle(g.ped)
            and not (myVeh ~= 0 and IsPedInVehicle(g.ped, myVeh, false)) then free[#free + 1] = g end
    end)
    return free
end

local function canStartEscort()
    if escort then return false, 'Escort already active' end
    if #spareGuards() == 0 then return false, 'All guards are busy or riding with you' end
    return true
end

local function startEscort()
    local okStart, why = canStartEscort()
    if not okStart then notify('~y~' .. why); return end
    local me = PlayerPedId()
    local free = spareGuards()
    local v = findById(Config.EscortVehicles, settings.escortVehicle) or Config.EscortVehicles[1]
    local model = joaat(v.model)
    if not loadModel(model) then notify('~r~Escort vehicle model failed to load'); return end
    local pos = GetOffsetFromEntityInWorldCoords(me, 0.0, -10.0, 0.0)
    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, GetEntityHeading(me), true, true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(veh) then notify('~r~Could not spawn escort vehicle'); return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleColours(veh, 0, 0)

    local driver = free[1]
    SetBlockingOfNonTemporaryEvents(driver.ped, true)
    SetPedIntoVehicle(driver.ped, veh, -1)
    local seat = 0
    for i = 2, #free do
        if seat > GetVehicleMaxNumberOfPassengers(veh) - 1 then break end
        SetPedIntoVehicle(free[i].ped, veh, seat)
        seat = seat + 1
    end
    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225); SetBlipColour(blip, 3); SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Escort'); EndTextCommandSetBlipName(blip)
    escort = { veh = veh, driver = driver.ped, blip = blip, following = 0 }
    escortTask()
    logEvent('hot', 'Escort %s active with %d guard(s)', v.label, math.min(#free, seat + 1))
end

stopEscort = function(silent)
    if not escort then return end
    if DoesBlipExist(escort.blip) then RemoveBlip(escort.blip) end
    local veh, drv = escort.veh, escort.driver
    if DoesEntityExist(veh) then
        for _, g in ipairs(guards) do
            if DoesEntityExist(g.ped) and IsPedInVehicle(g.ped, veh, false) then TaskLeaveVehicle(g.ped, veh, 16) end
        end
        resetDriveTuning(veh)
    end
    escort = nil
    CreateThread(function()
        Wait(1200)
        if DoesEntityExist(veh) then SetEntityAsMissionEntity(veh, true, true); DeleteEntity(veh) end
        if DoesEntityExist(drv) then SetBlockingOfNonTemporaryEvents(drv, false) end
        eachAlive(applyMode)
    end)
    if not silent then logEvent('', 'Escort dismissed') end
end

---------------------------------------------------------------------------
-- air support
---------------------------------------------------------------------------
local function airTask()
    if not air or not DoesEntityExist(air.veh) or not DoesEntityExist(air.pilot) then return end
    local me = PlayerPedId()
    -- mission 7 = follow the ped, keep AirHeight above; re-issued every few seconds by the loop
    TaskHeliMission(air.pilot, air.veh, 0, me, 0.0, 0.0, 0.0, 7, Config.AirSpeed, 25.0, -1.0, math.floor(Config.AirHeight), math.floor(Config.AirHeight * 0.6), -1.0, 0)
end

local function canStartAir()
    if air then return false, 'Air support already active' end
    if #spareGuards() == 0 then return false, 'All guards are busy or riding with you' end
    return true
end

local function startAir()
    local okStart, why = canStartAir()
    if not okStart then notify('~y~' .. why); return end
    local me = PlayerPedId()
    local free = spareGuards()
    local model = joaat(Config.AirVehicle)
    if not loadModel(model) then notify('~r~Helicopter model failed to load'); return end
    local base = GetEntityCoords(me)
    local veh = CreateVehicle(model, base.x - 10.0, base.y - 10.0, base.z + Config.AirHeight, GetEntityHeading(me), true, true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(veh) then notify('~r~Could not spawn helicopter'); return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetHeliBladesFullSpeed(veh)
    SetVehicleForwardSpeed(veh, 5.0)

    local pilot = free[1]
    SetBlockingOfNonTemporaryEvents(pilot.ped, true)
    SetPedIntoVehicle(pilot.ped, veh, -1)
    local seat = 0
    for i = 2, #free do
        if seat > GetVehicleMaxNumberOfPassengers(veh) - 1 then break end
        SetPedIntoVehicle(free[i].ped, veh, seat)
        seat = seat + 1
    end
    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 422); SetBlipColour(blip, 3); SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName('Air support'); EndTextCommandSetBlipName(blip)
    air = { veh = veh, pilot = pilot.ped, blip = blip }
    airTask()
    logEvent('hot', 'Air support up: %s flying, %d gunner(s)', pilot.name, seat)
end

stopAir = function(silent)
    if not air then return end
    if DoesBlipExist(air.blip) then RemoveBlip(air.blip) end
    local veh, pilot = air.veh, air.pilot
    air = nil
    if DoesEntityExist(veh) then
        -- land near me, then everyone out and the heli is removed
        local me = GetEntityCoords(PlayerPedId())
        if DoesEntityExist(pilot) then
            TaskHeliMission(pilot, veh, 0, 0, me.x + 12.0, me.y + 12.0, me.z, 19, 30.0, 10.0, -1.0, 0, 0, -1.0, 32) -- 19 = land and wait
        end
        CreateThread(function()
            local t = 0
            while t < 15000 and DoesEntityExist(veh) and not IsVehicleOnAllWheels(veh) do Wait(250); t = t + 250 end
            for _, g in ipairs(guards) do
                if DoesEntityExist(g.ped) and IsPedInVehicle(g.ped, veh, false) then TaskLeaveVehicle(g.ped, veh, 16) end
            end
            Wait(1000)
            if DoesEntityExist(veh) then SetEntityAsMissionEntity(veh, true, true); DeleteEntity(veh) end
            if DoesEntityExist(pilot) then SetBlockingOfNonTemporaryEvents(pilot, false) end
            eachAlive(applyMode)
        end)
    end
    if not silent then logEvent('', 'Air support dismissed') end
end

---------------------------------------------------------------------------
-- hostiles / auto drive-by
---------------------------------------------------------------------------
local function findHostile(me, myVeh)
    local myPos = GetEntityCoords(me)
    local best, bestDist = 0, Config.AutoDriveByRange
    for _, p in ipairs(GetGamePool('CPed')) do
        if not isOurs(p) and not IsEntityDead(p) then
            local d = #(GetEntityCoords(p) - myPos)
            if d < bestDist then
                local hostile = IsPedInCombat(p, me)
                    or HasEntityBeenDamagedByEntity(me, p, 1)
                    or (myVeh ~= 0 and HasEntityBeenDamagedByEntity(myVeh, p, 1))
                    or (escort and HasEntityBeenDamagedByEntity(escort.veh, p, 1))
                    or (air and HasEntityBeenDamagedByEntity(air.veh, p, 1))
                    or (mode == 'aggressive' and IsPedShooting(p))
                if hostile then best, bestDist = p, d end
            end
        end
    end
    return best
end

local function autoDriveByTick()
    if not autoDriveBy or mode == 'passive' then return end
    local me = PlayerPedId()
    local myVeh = myVehicle()
    local target = findHostile(me, myVeh)
    if target == 0 then return end
    eachAlive(function(g)
        if IsPedInAnyVehicle(g.ped, false) and not isDriverPed(g.ped) and not IsPedShooting(g.ped) then driveBy(g.ped, target) end
    end)
    ClearEntityLastDamageEntity(me)
    if myVeh ~= 0 then ClearEntityLastDamageEntity(myVeh) end
end

-- attack whoever the player damages; count guard kills
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or #guards == 0 then return end
    local victim, attacker, fatal = args[1], args[2], args[6]
    local me = PlayerPedId()
    if (fatal == 1 or fatal == true) and DoesEntityExist(victim) and IsEntityDead(victim) then
        local g = guardByPed(attacker)
        if g and victim ~= me and not isGuard(victim) and GetEntityType(victim) == 1 then
            local before = rankOf(g.kills).label
            g.kills = (g.kills or 0) + 1
            applyRank(g)
            if g.contract then TriggerServerEvent('nk_bodyguard:kill', g.contract) end
            logEvent('hot', '%s scored a kill (%d)', g.name, g.kills)
            if g.rank ~= before then
                logEvent('hot', '%s promoted to %s', g.name, g.rank)
                notify(('~b~%s~s~ promoted to ~y~%s'):format(g.name, g.rank))
            end
        end
    end
    if mode == 'passive' then return end
    local veh = myVehicle()
    if attacker == me or (veh ~= 0 and attacker == veh) then orderAttack(victim, false) end
end)

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
local function guardState(g)
    local p = g.ped
    if not alive(g) then return 'Dead' end
    if chauffeur and chauffeur.guard == p then return 'Driving' end
    if escort and escort.driver == p then return 'Escorting' end
    if air and air.pilot == p then return 'Flying' end
    if IsPedShooting(p) then return 'Firing' end
    if mode ~= 'passive' and inCombat(p) then return 'Fighting' end
    if inAirVehicle(p) then return 'Gunner' end
    if inEscortVehicle(p) then return 'Escort car' end
    if IsPedInAnyVehicle(p, false) then return 'In vehicle' end
    if g.hold then return 'Holding' end
    if mode == 'hold' then return 'Holding' end
    if mode == 'passive' then return 'Hold fire' end
    if mode == 'aggressive' then return 'Hunting' end
    return 'Following'
end

local function driveStatusText()
    local parts = {}
    if chauffeur then
        local g = guardByPed(chauffeur.guard)
        local name = g and g.name or 'Guard'
        if chauffeur.kind == 'waypoint' and chauffeur.dest then
            parts[#parts + 1] = ('%s → waypoint, %d m'):format(name, math.floor(#(GetEntityCoords(chauffeur.veh) - chauffeur.dest)))
        else
            parts[#parts + 1] = ('%s cruising'):format(name)
        end
    end
    local me = GetEntityCoords(PlayerPedId())
    if escort and DoesEntityExist(escort.veh) then parts[#parts + 1] = ('Escort %d m'):format(math.floor(#(GetEntityCoords(escort.veh) - me))) end
    if air and DoesEntityExist(air.veh) then parts[#parts + 1] = ('Heli %d m'):format(math.floor(#(GetEntityCoords(air.veh) - me))) end
    return table.concat(parts, ' · ')
end

local function styleInfoText()
    local s = style()
    return ('<b>%s</b>: %d km/h target%s. Applies to chauffeur, cruise and escort; switching re-tasks the driver instantly.')
        :format(s.label, math.floor(s.speed * 3.6), (s.boost or 0) > 0 and (', +%d%% top speed'):format(s.boost) or '')
end

-- Settings as the panel should see them. customOffsets is keyed 1..n in Lua, which JSON
-- would turn into a 0-based array and shift every slot by one in the preview; send it as an
-- object keyed by slot name instead.
local function uiSettings()
    local out = {}
    for k, v in pairs(settings) do out[k] = v end
    local co = {}
    for i, o in pairs(settings.customOffsets) do co[tostring(i)] = { x = o.x, y = o.y } end
    out.customOffsets = co
    -- an empty Lua table would encode as [] ; make sure the panel always gets an object
    if next(co) == nil then out.customOffsets = json.decode('{}') end
    if next(settings.seats) == nil then out.seats = json.decode('{}') end
    return out
end

local function pushUpdate()
    local me = GetEntityCoords(PlayerPedId())
    local data = {}
    for i, g in ipairs(guards) do
        local exists = DoesEntityExist(g.ped)
        data[#data + 1] = {
            index = i, name = g.name, model = g.model, weapon = g.weapon, kills = g.kills or 0,
            tier = g.tier, rank = g.rank, contract = g.contract ~= nil,
            tierColor = (tierById(g.tierId) or {}).color,
            health = exists and math.max(0, GetEntityHealth(g.ped) - 100) or 0,
            maxHealth = math.max(1, (g.maxHealth or Config.Health) - 100),
            armour = exists and GetPedArmour(g.ped) or 0,
            maxArmour = math.max(1, g.maxArmour or Config.Armour),
            distance = exists and math.floor(#(GetEntityCoords(g.ped) - me)) or 0,
            state = guardState(g), dead = not alive(g),
        }
    end
    local models, weapons, evs = {}, {}, {}
    for _, m in ipairs(Config.Models) do models[#models + 1] = { id = m.id, label = m.label } end
    for _, w in ipairs(Config.Weapons) do weapons[#weapons + 1] = { id = w.id, label = w.label } end
    for _, v in ipairs(Config.EscortVehicles) do evs[#evs + 1] = { id = v.id, label = v.label } end
    SendNUIMessage({
        type = 'update', guards = data, max = Config.MaxGuards, mode = mode, formation = formation,
        driveStyle = driveStyle, autoDriveBy = autoDriveBy, escort = escort ~= nil, air = air ~= nil,
        driveStatus = driveStatusText(), styleInfo = styleInfoText(), log = eventLog,
        settings = uiSettings(), options = { models = models, weapons = weapons, escortVehicles = evs },
        admin = isAdmin,
        agency = {
            name = Config.Agency.Name, active = contractCount(), max = Config.Agency.MaxContracts,
            prices = { escort = Config.Services.escort, air = Config.Services.air, heal = Config.Services.healPerGuard },
        },
    })
end

local function openPanel()
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open' })
    pushUpdate()
end

local function closePanel()
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterNUICallback('action', function(data, cb)
    local a = data.action
    if a == 'close' then closePanel()
    elseif (a == 'spawn' or a == 'spawnfill') and not isAdmin then
        notify('~y~Hire guards in person at the ' .. Config.Agency.Name)
    elseif a == 'spawn' then
        if #guards >= Config.MaxGuards then notify(('~y~Limit reached (%d)'):format(Config.MaxGuards)) else spawnGuard() end
    elseif a == 'spawnfill' then
        while #guards < Config.MaxGuards do if not spawnGuard() then break end; Wait(80) end
    elseif a == 'dismissall' then dismissAll('panel', true)
    elseif a == 'agencygps' then
        local p = Config.Agency.Ped.coords
        SetNewWaypoint(p.x, p.y)
        notify('GPS set to the ' .. Config.Agency.Name)
    elseif a == 'attack' then closePanel(); orderAttack(aimedTarget(), true)
    elseif a == 'markattack' then closePanel(); startMarking('attack', nil)
    elseif a == 'markmove' then closePanel(); startMarking('move', nil)
    elseif a == 'driveby' then closePanel(); orderDriveBy()
    elseif a == 'cover' then orderCover()
    elseif a == 'ceasefire' then orderCeasefire()
    elseif a == 'gotowp' then orderGotoWaypoint()
    elseif a == 'chauffeur' then closePanel(); startChauffeur('waypoint')
    elseif a == 'cruise' then closePanel(); startChauffeur('cruise')
    elseif a == 'swapdriver' then if chauffeur then startChauffeur('keep') else notify('~y~Nobody is driving') end
    elseif a == 'stopdrive' then stopChauffeur(false)
    elseif a == 'escort' then
        if escort then stopEscort(false)
        else
            local okStart, why = canStartEscort()
            if okStart then withPayment('escort', 1, startEscort) else notify('~y~' .. why) end
        end
    elseif a == 'air' then
        if air then stopAir(false)
        else
            local okStart, why = canStartAir()
            if okStart then withPayment('air', 1, startAir) else notify('~y~' .. why) end
        end
    elseif a == 'enter' then orderEnter()
    elseif a == 'exit' then orderExit()
    elseif a == 'warp' then orderWarp()
    elseif a == 'heal' then
        local hurt = {}
        eachAlive(function(g) if injured(g) then hurt[#hurt + 1] = g end end)
        if #hurt == 0 then notify('Nobody needs a medic')
        else
            withPayment('healPerGuard', #hurt, function()
                for _, g in ipairs(hurt) do if alive(g) then healGuard(g) end end
                logEvent('', 'Medic patched up %d guard(s)', #hurt)
            end)
        end
    elseif a == 'formreset' then
        -- seed custom slots from the current preset so the editor starts from a sensible shape
        local base = formation == 4 and 0 or formation
        local out = {}
        for i = 1, Config.MaxGuards do local x, y = presetOffset(i, base); out[i] = { x = x, y = y } end
        settings.customOffsets = out; formation = 4
        for _, g in ipairs(guards) do g.followKey = nil end
    elseif a == 'formmirror' then
        for i, o in pairs(settings.customOffsets) do settings.customOffsets[i] = { x = -o.x, y = o.y } end
        formation = 4
        for _, g in ipairs(guards) do g.followKey = nil end
    end
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('guard', function(data, cb)
    local g = guards[data.index]
    if g and alive(g) then
        local a = data.action
        if a == 'heal' then
            if not injured(g) then notify(('%s is not hurt'):format(g.name))
            else withPayment('healPerGuard', 1, function() if alive(g) then healGuard(g); logEvent('', '%s healed', g.name) end end) end
        elseif a == 'warp' then warpGuard(g, data.index); logEvent('', '%s coming to you', g.name)
        elseif a == 'weapon' then
            if not isAdmin then notify('~y~Contract guards keep the weapon of their tier')
            else
                local w = findById(Config.Weapons, settings.recruitWeapon) or pick(Config.Weapons)
                giveWeapon(g, w); g.weaponName = w.name; logEvent('', '%s re-armed with %s', g.name, w.label)
            end
        elseif a == 'driver' then closePanel(); startChauffeur(chauffeur and 'keep' or 'cruise', g)
        elseif a == 'hold' then g.hold = true; g.holdPos = nil; applyMode(g); logEvent('', '%s holding position', g.name)
        elseif a == 'follow' then g.hold = nil; g.holdPos = nil; g.lastTarget = nil; applyMode(g); logEvent('', '%s following', g.name)
        elseif a == 'markattack' then closePanel(); startMarking('attack', data.index)
        elseif a == 'goto' then closePanel(); startMarking('move', data.index)
        elseif a == 'minimap' then
            ensureBlip(g)
            if g.blip ~= 0 then SetBlipFlashes(g.blip, true); SetBlipFlashTimer(g.blip, 8000) end
            notify(('%s is flashing on your minimap'):format(g.name))
        elseif a == 'cancel' then
            g.hold = nil; g.holdPos = nil; g.lastTarget = nil; g.goActive = false
            if focus and (focus.scope == data.index or focus.scope == nil) then focus = nil end
            ClearPedTasks(g.ped)
            logEvent('', '%s: actions cancelled', g.name)
        elseif a == 'sendhome' then sendHome(g, data.index)
        elseif a == 'dismiss' then
            removeGuard(g, 'panel', true); table.remove(guards, data.index)
            logEvent('', '%s dismissed%s', g.name, g.contract and ', contract ended' or '')
        end
    end
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('mode', function(data, cb)
    if data.mode == 'follow' or data.mode == 'hold' or data.mode == 'aggressive' or data.mode == 'passive' then setMode(data.mode) end
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('formation', function(data, cb)
    setFormation(tonumber(data.formation) or 0)
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('drivestyle', function(data, cb)
    if Config.DriveStyles[data.style] then
        driveStyle = data.style
        retaskChauffeur()
        if escort then escortTask() end
        logEvent('', 'Driving style: %s', style().label)
    end
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('toggle', function(data, cb)
    local v = data.value and true or false
    if not isAdmin and (data.name == 'invincible' or data.name == 'regen' or data.name == 'reinforce') then
        notify('~y~That setting is admin only')
        pushUpdate(); cb('ok'); return
    end
    if data.name == 'autodriveby' then autoDriveBy = v; logEvent('', 'Auto drive-by %s', v and 'ON' or 'OFF')
    elseif data.name == 'invincible' then
        settings.invincible = v
        eachAlive(function(g) SetEntityInvincible(g.ped, v) end)
        logEvent('', 'Invincible %s', v and 'ON' or 'OFF')
    elseif data.name == 'regen' then settings.regen = v
    elseif data.name == 'reinforce' then settings.reinforce = v; logEvent('', 'Auto-reinforce %s', v and 'ON' or 'OFF')
    elseif data.name == 'blips' then settings.blips = v; eachAlive(ensureBlip)
    end
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('customformation', function(data, cb)
    local out = {}
    if type(data.offsets) == 'table' then
        for k, o in pairs(data.offsets) do
            local i = tonumber(k)
            if i and type(o) == 'table' and tonumber(o.x) and tonumber(o.y) then out[i] = { x = tonumber(o.x), y = tonumber(o.y) } end
        end
    end
    settings.customOffsets = out
    formation = 4
    for _, g in ipairs(guards) do g.followKey = nil; g.lastTarget = nil end
    logEvent('', 'Custom formation applied')
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('seat', function(data, cb)
    local seat = tostring(tonumber(data.seat) or 0)
    local name = data.guard
    -- one guard per seat, one seat per guard
    for k, n in pairs(settings.seats) do if n == name then settings.seats[k] = nil end end
    if name and name ~= '' then settings.seats[seat] = name else settings.seats[seat] = nil end
    if seat == '-1' then
        if chauffeur and (not name or name == '') then stopChauffeur(false) end
        logEvent('', 'Driver seat: %s', (name and name ~= '') and name or 'nobody')
    end
    pushUpdate(); cb('ok')
end)

RegisterNUICallback('setting', function(data, cb)
    local n, v = data.name, data.value
    if n == 'recruitModel' or n == 'recruitWeapon' or n == 'escortVehicle' or n == 'pos' then settings[n] = v
    elseif n == 'scale' then settings.scale = tonumber(v) or 1
    elseif n == 'spacing' then settings.spacing = math.max(1.0, math.min(5.0, tonumber(v) or 1.8)); for _, g in ipairs(guards) do g.followKey = nil end
    elseif n == 'accuracy' and isAdmin then
        settings.accuracy = math.max(10, math.min(100, math.floor(tonumber(v) or 85)))
        -- the slider tunes admin recruits; contract guards keep their tier's accuracy
        eachAlive(function(g) if not g.contract then g.baseAccuracy = settings.accuracy; applyRank(g) end end)
    end
    pushUpdate(); cb('ok')
end)

RegisterCommand('+bg_panel', function() if panelOpen then closePanel() else openPanel() end end, false)
RegisterCommand('-bg_panel', function() end, false)
RegisterKeyMapping('+bg_panel', 'Bodyguards: open squad panel', 'keyboard', Config.PanelKey)
RegisterCommand('+bg_attack', function() if #guards > 0 then orderAttack(aimedTarget(), true) end end, false)
RegisterCommand('-bg_attack', function() end, false)
RegisterKeyMapping('+bg_attack', 'Bodyguards: attack my target', 'keyboard', Config.AttackKey)

---------------------------------------------------------------------------
-- Bodyguard Agency: blip, manager NPC, hiring screen
---------------------------------------------------------------------------
local agencyPed = 0
local hiring = false

local function shopData(extra)
    extra = extra or {}
    local tiers = {}
    for _, t in ipairs(Config.Tiers) do
        local outfits = {}
        for _, o in ipairs(t.outfits) do outfits[#outfits + 1] = o.label end
        tiers[#tiers + 1] = {
            id = t.id, label = t.label, color = t.color, price = t.price, desc = t.desc, weapon = t.weaponLabel,
            health = t.health, armour = t.armour, accuracy = t.accuracy, outfits = outfits,
        }
    end
    return {
        name = Config.Agency.Name, admin = isAdmin, balance = extra.balance or 0,
        active = extra.active or contractCount(),
        max = isAdmin and Config.MaxGuards or Config.Agency.MaxContracts,
        squad = #guards, squadMax = Config.MaxGuards,
        tiers = tiers,
        services = { escort = Config.Services.escort, air = Config.Services.air, heal = Config.Services.healPerGuard },
    }
end

local function closeShop()
    shopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'shop', open = false })
end

local function openShop()
    if panelOpen then closePanel() end
    shopOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'shop', open = true, data = shopData() })
    CreateThread(function()
        local ok, _, extra = request('balance')
        if ok then
            if extra.admin ~= nil then isAdmin = extra.admin end
            if shopOpen then SendNUIMessage({ type = 'shop', open = true, data = shopData(extra) }) end
        end
    end)
end

RegisterNUICallback('shopclose', function(_, cb) closeShop(); cb('ok') end)

RegisterNUICallback('hire', function(data, cb)
    cb('ok')
    if hiring then return end
    if #guards >= Config.MaxGuards then
        notify(('~y~You can only lead %d guards at once'):format(Config.MaxGuards)); return
    end
    hiring = true
    CreateThread(function()
        local ok, msg, extra = request('hire', data.tier, tonumber(data.outfit) or 1)
        if ok and extra.contract then
            spawnContract(extra.contract, Config.Agency.SpawnPoint)
            notify('~g~' .. msg .. '~s~. They are on their way to you.')
            logEvent('hot', '%s', msg)
        else
            notify('~r~' .. msg)
        end
        if shopOpen then SendNUIMessage({ type = 'shop', open = true, data = shopData(extra) }) end
        hiring = false
    end)
end)

local function spawnManager()
    local p = Config.Agency.Ped
    local hash = joaat(p.model)
    if not loadModel(hash) then return end
    local c = p.coords
    local z = c.z
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    if ok then z = gz end
    agencyPed = CreatePed(4, hash, c.x, c.y, z, c.w, false, false)     -- local only, not networked
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(agencyPed, true)
    FreezeEntityPosition(agencyPed, true)
    SetBlockingOfNonTemporaryEvents(agencyPed, true)
    SetPedCanRagdoll(agencyPed, false)
    SetPedFleeAttributes(agencyPed, 0, false)
    if p.scenario then TaskStartScenarioInPlace(agencyPed, p.scenario, 0, true) end
end

CreateThread(function()
    if not Config.Agency.Enabled then return end
    local c = Config.Agency.Ped.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.Agency.Blip.sprite)
    SetBlipColour(blip, Config.Agency.Blip.colour)
    SetBlipScale(blip, Config.Agency.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(Config.Agency.Name); EndTextCommandSetBlipName(blip)

    local here = vector3(c.x, c.y, c.z)
    while true do
        local wait = 1000
        local d = #(GetEntityCoords(PlayerPedId()) - here)
        if d < 80.0 and not DoesEntityExist(agencyPed) then spawnManager()
        elseif d > 110.0 and DoesEntityExist(agencyPed) then DeleteEntity(agencyPed); agencyPed = 0 end
        if d < 12.0 then
            wait = 0
            if d < Config.Agency.InteractDistance and not shopOpen and not panelOpen and not IsPedInAnyVehicle(PlayerPedId(), false) then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to hire bodyguards')
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustReleased(0, 38) then openShop() end
            end
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if panelOpen or shopOpen then
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 202)
                or IsDisabledControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 56) then
                if shopOpen then closeShop() else closePanel() end
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

---------------------------------------------------------------------------
-- housekeeping loop
---------------------------------------------------------------------------
local function purgeGroup(group)
    local kicked = 0
    local me = PlayerPedId()
    for _, p in ipairs(GetGamePool('CPed')) do
        if p ~= me and IsPedGroupMember(p, group) then
            RemovePedFromGroup(p)
            if not isGuard(p) then ClearPedTasks(p); SetPedAsNoLongerNeeded(p) end
            kicked = kicked + 1
        end
    end
    if kicked > 0 then dbg('purged %d member(s) from group %d', kicked, group) end
end

---------------------------------------------------------------------------
-- movement thread (250 ms): following on foot, boarding my car, getting out after me.
-- Fast enough that guards react the moment I start walking, get in or get out.
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(250)
        if #guards > 0 then
            updateMoveHeading()
            local myVeh = myVehicle()
            local now = GetGameTimer()
            local slot = 0
            for _, g in ipairs(guards) do
                if alive(g) then
                    slot = slot + 1
                    local special = isDriverPed(g.ped) or inEscortVehicle(g.ped) or inAirVehicle(g.ped)
                    local guardInVeh = IsPedInAnyVehicle(g.ped, false)
                    local following = not g.hold and (mode == 'follow' or mode == 'aggressive' or mode == 'passive')
                    if following and not special then
                        if myVeh == 0 and not guardInVeh then
                            g.sitAt = nil
                            if not focusing(g) then
                                local fighting = mode ~= 'passive' and inCombat(g.ped)
                                if not fighting then follow(g, slot) else g.lastTarget = nil; g.goActive = false end
                            end
                        elseif myVeh ~= 0 and not guardInVeh then
                            -- Natural boarding: never teleported into a seat. Chase the car while
                            -- it moves, get in (assigned seat first) the moment it stops.
                            local moving = GetEntitySpeed(myVeh) > 3.0
                            if moving or not AreAnyVehicleSeatsFree(myVeh) then
                                if g.followKey ~= 'chase' then
                                    g.followKey, g.lastTarget, g.goActive = 'chase', nil, false
                                    TaskFollowToOffsetOfEntity(g.ped, myVeh, 0.0, -3.5, 0.0, 3.0, -1, 2.5, true)
                                end
                            elseif (g.enterAt or 0) + 4000 < now then
                                g.enterAt, g.followKey, g.lastTarget, g.goActive = now, nil, nil, false
                                local want = seatOfGuard(g)
                                local seat = -2
                                if want and want >= 0 and IsVehicleSeatFree(myVeh, want) then seat = want end
                                TaskEnterVehicle(g.ped, myVeh, 12000, seat, 2.0, 1, 0)
                            end
                        elseif myVeh == 0 and guardInVeh and not chauffeur then
                            -- I got out: they get out right behind me
                            g.sitAt = g.sitAt or now
                            if now - g.sitAt > 350 then
                                local v = GetVehiclePedIsIn(g.ped, false)
                                if GetPedInVehicleSeat(v, -1) == g.ped and GetEntitySpeed(v) > 3.0 then
                                    TaskVehicleTempAction(g.ped, v, 27, 1500)
                                elseif (g.exitAt or 0) + 2500 < now then
                                    g.exitAt, g.lastTarget, g.goActive = now, nil, false
                                    TaskLeaveVehicle(g.ped, v, 256)
                                end
                            end
                        else
                            g.sitAt = nil
                        end
                    end
                end
            end
        end
    end
end)

-- escort upkeep (200 ms): reacts immediately to me getting in / out / moving off
CreateThread(function()
    while true do
        if escort then Wait(200); escortTask() else Wait(500) end
    end
end)

CreateThread(function()
    local tick = 0
    while true do
        Wait(500)
        tick = tick + 1
        local me = PlayerPedId()
        local myPos = GetEntityCoords(me)
        local now = GetGameTimer()

        if #guards > 0 then
            local keep = {}
            local myVeh = myVehicle()
            for _, g in ipairs(guards) do
                local exists = isSamePed(g)
                local dead = exists and IsEntityDead(g.ped)
                if exists and not dead then
                    keep[#keep + 1] = g
                    local special = isDriverPed(g.ped) or inEscortVehicle(g.ped) or inAirVehicle(g.ped)
                    local guardInVeh = IsPedInAnyVehicle(g.ped, false)

                    -- (following, boarding and dismounting run in the fast movement thread below)

                    -- guard sent to a position (Move to / per-guard Go to): walk there, then hold
                    if g.hold and g.holdPos and not special and not guardInVeh and not inCombat(g.ped) and not focusing(g) then
                        local hd = #(GetEntityCoords(g.ped) - g.holdPos)
                        if hd > 2.5 and (g.goAt or 0) + 3000 < now then
                            g.goAt = now
                            TaskFollowNavMeshToCoord(g.ped, g.holdPos.x, g.holdPos.y, g.holdPos.z, hd > 20.0 and 3.0 or 2.0, -1, 1.0, 0, 0.0)
                        elseif hd <= 2.5 and not g.holdArrived then
                            g.holdArrived = true
                            TaskStandGuard(g.ped, g.holdPos.x, g.holdPos.y, g.holdPos.z, GetEntityHeading(g.ped), 'WORLD_HUMAN_GUARD_STAND')
                        end
                    end

                    if mode == 'aggressive' and not special and not guardInVeh and tick % 6 == 0 and not inCombat(g.ped) then
                        TaskCombatHatedTargetsAroundPed(g.ped, Config.AggroRange, 0)
                        g.followKey = nil
                    end

                    if settings.regen and tick % 4 == 0 and not inCombat(g.ped) then
                        local h, mh = GetEntityHealth(g.ped), GetEntityMaxHealth(g.ped)
                        if h < mh then SetEntityHealth(g.ped, math.min(mh, h + Config.RegenPerTick)) end
                    end
                else
                    local why = dead and 'dead' or (DoesEntityExist(g.ped) and 'handle reused by another ped' or 'entity gone')
                    if g.contract and dead then
                        -- killed in action: the contract is over for good
                        endContract(g, 'killed')
                        clearSeat(g)
                        logEvent('bad', '%s was killed in action. Contract ended.', g.name)
                        notify(('~r~%s was killed in action.~s~ Contract ended.'):format(g.name))
                    elseif g.contract then
                        -- vanished without dying (despawned / handle taken): bring them back
                        respawnQueue[#respawnQueue + 1] = { at = now + 2000, c = {
                            id = g.contract, name = g.name, tier = g.tierId, model = g.modelName, weapon = g.weaponName, kills = g.kills } }
                        logEvent('', '%s lost contact, rejoining', g.name)
                    else
                        logEvent('bad', '%s lost (%s)', g.name, why)
                        clearSeat(g)
                        if isAdmin and settings.reinforce then reinforceQueue[#reinforceQueue + 1] = now + Config.ReinforceDelay end
                    end
                    if g.blip ~= 0 and DoesBlipExist(g.blip) then RemoveBlip(g.blip) end
                    if DoesEntityExist(g.ped) then RemovePedFromGroup(g.ped); if exists then SetPedAsNoLongerNeeded(g.ped) end end
                    if chauffeur and chauffeur.guard == g.ped then chauffeur = nil end
                    if escort and escort.driver == g.ped then stopEscort(true) end
                    if air and air.pilot == g.ped then stopAir(true) end
                end
            end
            guards = keep

            -- designated driver (Vehicle page, Driver seat): takes the wheel whenever I'm driving
            local dd = designatedDriver()
            if dd and myVeh ~= 0 and not chauffeur and GetPedInVehicleSeat(myVeh, -1) == me
                and (IsPedInVehicle(dd.ped, myVeh, false) or #(GetEntityCoords(dd.ped) - myPos) < 30.0) then
                local wp = GetFirstBlipInfoId(8)
                startChauffeur(DoesBlipExist(wp) and 'waypoint' or 'wait', dd)
            end

            if chauffeur then
                local isDD = dd and chauffeur.guard == dd.ped
                if not DoesEntityExist(chauffeur.veh) or not IsPedInVehicle(chauffeur.guard, chauffeur.veh, false) then
                    chauffeur = nil
                elseif myVeh == 0 then
                    -- I got out: hand the car back so the driver follows me on foot
                    chauffeur.leftAt = chauffeur.leftAt or now
                    if now - chauffeur.leftAt > 2500 then stopChauffeur(true) end
                else
                    chauffeur.leftAt = nil
                    local wp = GetFirstBlipInfoId(8)
                    local hasWp = DoesBlipExist(wp)
                    if chauffeur.kind == 'wait' and hasWp then
                        chauffeur.kind = 'waypoint'; chauffeur.dest = GetBlipInfoIdCoord(wp); retaskChauffeur()
                        logEvent('hot', 'Waypoint set, driver moving')
                    elseif chauffeur.kind == 'waypoint' then
                        if hasWp then
                            local d = GetBlipInfoIdCoord(wp)
                            if #(d - chauffeur.dest) > 5.0 then chauffeur.dest = d; retaskChauffeur() end
                        end
                        if #(GetEntityCoords(chauffeur.veh) - chauffeur.dest) < Config.ArriveDistance + 2.0 then
                            logEvent('hot', 'Arrived at waypoint')
                            if isDD then chauffeur.kind = 'wait'; chauffeur.dest = nil; retaskChauffeur() else stopChauffeur(true) end
                        end
                    end
                end
            end

            if escort then
                if not DoesEntityExist(escort.veh) or IsEntityDead(escort.veh) or not DoesEntityExist(escort.driver) or IsEntityDead(escort.driver) then
                    stopEscort(true)
                end
            end

            if air then
                if not DoesEntityExist(air.veh) or IsEntityDead(air.veh) or not DoesEntityExist(air.pilot) or IsEntityDead(air.pilot) then
                    stopAir(true)
                elseif tick % 6 == 0 then
                    airTask()
                end
            end

            if tick % 3 == 0 then autoDriveByTick() end
            focusTick()

            if tick % 2 == 0 and mode ~= 'passive' and not focus then
                local hostile = findHostile(me, myVehicle())
                if hostile ~= 0 then
                    eachAlive(function(g)
                        if not isDriverPed(g.ped) and not IsPedInAnyVehicle(g.ped, false) and not inCombat(g.ped) then
                            TaskCombatPed(g.ped, hostile, 0, 16); g.followKey = nil
                        end
                    end)
                    ClearEntityLastDamageEntity(me)
                end
            end
        end

        -- contracted guards that vanished without dying come back near you
        if #respawnQueue > 0 then
            local later = {}
            for _, r in ipairs(respawnQueue) do
                if r.at <= now then spawnContract(r.c) else later[#later + 1] = r end
            end
            respawnQueue = later
        end

        -- reinforcements (admin recruits only)
        if #reinforceQueue > 0 and isAdmin and settings.reinforce then
            local due = {}
            for _, t in ipairs(reinforceQueue) do
                if t <= now then
                    if #guards < Config.MaxGuards then spawnGuard(); logEvent('hot', 'Reinforcement arrived') end
                else
                    due[#due + 1] = t
                end
            end
            reinforceQueue = due
        end

        if tick % 10 == 0 then purgeGroup(GetPlayerGroup(PlayerId())) end
        if panelOpen then pushUpdate() end
    end
end)

---------------------------------------------------------------------------
-- server-forwarded chat command
---------------------------------------------------------------------------
RegisterNetEvent('nk_bodyguard:client:command', function(args)
    local a = args[1] and args[1]:lower() or nil
    if a == 'dismiss' or a == 'remove' or a == 'off' then dismissAll('command', true); return end
    if a == 'panel' or a == 'menu' or a == 'ui' then openPanel(); return end
    local n = tonumber(a) or 1
    local spawned = 0
    for _ = 1, n do
        if #guards >= Config.MaxGuards then break end
        if spawnGuard() then spawned = spawned + 1 end
        Wait(100)
    end
    if spawned > 0 then
        notify(('Bodyguard: %d spawned (%d/%d). Press %s for the squad panel'):format(spawned, #guards, Config.MaxGuards, Config.PanelKey))
    else
        notify(('~y~Bodyguard limit reached (%d)'):format(Config.MaxGuards))
    end
end)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Bodyguards: spawn [n], "dismiss", or "panel"', {
    { name = 'count | dismiss | panel', help = 'number of guards to add, "dismiss", or "panel"' },
})

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        if panelOpen then SetNuiFocus(false, false) end
        if escort and DoesEntityExist(escort.veh) then SetEntityAsMissionEntity(escort.veh, true, true); DeleteEntity(escort.veh) end
        if air and DoesEntityExist(air.veh) then SetEntityAsMissionEntity(air.veh, true, true); DeleteEntity(air.veh) end
        for _, g in ipairs(guards) do if DoesEntityExist(g.ped) then RemovePedFromGroup(g.ped) end end
        dismissAll('resource stop')
    end
end)

---------------------------------------------------------------------------
-- role + contracts from the server
---------------------------------------------------------------------------
local contractsSyncing = false
RegisterNetEvent('nk_bodyguard:init', function(d)
    isAdmin = d.admin and true or false
    if not d.loaded or contractsSyncing then return end
    contractsSyncing = true
    CreateThread(function()
        local n = 0
        for _, c in ipairs(d.contracts or {}) do
            if not contractGuard(c.id) and #guards < Config.MaxGuards then
                if spawnContract(c) then n = n + 1 end
                Wait(150)
            end
        end
        if n > 0 then notify(('~b~%d bodyguard(s)~s~ reporting for duty'):format(n)) end
        contractsSyncing = false
    end)
end)

-- character logout / switch (multicharacter): remove the peds, keep the contracts
RegisterNetEvent('esx:onPlayerLogout', function()
    if panelOpen then closePanel() end
    if shopOpen then closeShop() end
    dismissAll('logout', false)
end)

CreateThread(function()
    Wait(1500)
    cleanupLeftovers()
    purgeGroup(GetPlayerGroup(PlayerId()))
    TriggerServerEvent('nk_bodyguard:hello')
end)
