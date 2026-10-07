# nk_bodyguard

NPC bodyguards for FiveM (ESX Legacy + oxmysql) with a **Bodyguard Agency** where players hire
contracted guards, and an in-game **Bodyguard Center** panel to command them.

## Features

### Bodyguard Agency (citizens)
- A blip and a manager NPC in Legion Square (next to the ESX default spawn). Walk up, press **E**.
- Four contract tiers, each with its own price, weapon, health, armour, accuracy and outfit choice:
  Rookie, Professional, Elite, Heavy Gunner. Paid from cash, then bank.
- Each hire is a **contract** saved in the `nk_bodyguard_contracts` table. The guard rejoins you after a
  relog or a server restart, and the contract ends for good when the guard is **killed** or **dismissed**. No refunds.
- Paid services from the panel: escort car, air support helicopter, medic (per injured guard).
- **Veterancy**: kills are saved on the contract. *Veteran* at 5 kills (+accuracy), *Legend* at 15 (+accuracy, +armour).
- Named guards (Marcus, Viktor, Dmitri...).

### Admins
- ESX group `admin`/`superadmin` or the `command.bodyguard` ace.
- Free, unlimited recruiting from the panel (temporary, not saved) and `/bodyguard [n|dismiss|panel]`.
- Free hires at the Agency and free services. Admin-only toggles: invincible, health regen, auto-reinforce, accuracy.

### Bodyguard Center (F9)
- **Home**: stats, mode (Follow / Hold / Aggressive / Hold fire), quick orders, recruit or Agency info, event log.
- **Squad**: table with tier and rank badges, per-guard orders: Attack, Follow, Go to, Mark in minimap, Send home,
  Cancel, Come to me, Hold, Medic, Make driver, Dismiss. Ending a contract asks for a second click.
- **Formation**: Loose / Circle / Wedge / Line / Custom with a drag-and-drop editor and an Apply button.
- **Vehicle**: seat assignment. New guards take the next **passenger** seat automatically and the driver seat stays
  yours unless you assign a chauffeur. Driving styles Calm to Insane, chauffeur / cruise / swap / stop, escort car,
  air support, auto drive-by.
- **Settings**: minimap blips, panel position and size, plus the admin tools.

### Behaviour
- **Mark & attack** / **Move to position**: aim in-game, **E** confirms, **Esc** cancels.
- **Caps Lock** attacks whatever you are aiming at.
- Guards are never teleported. Movement runs every 250 ms: they follow on foot, chase your car and board the moment
  it stops, and get out right behind you. The escort car reacts within 200 ms and speeds up to catch up when behind.

## Install

1. Requires `es_extended` and `oxmysql`. Drop the folder into `resources/` and add `ensure nk_bodyguard` after them.
2. The table is created automatically on start (or run `install.sql`).
3. Keys can be rebound in *Settings › Key Bindings › FiveM*.

## Config

`config.lua`: Agency location / NPC / blip, contract limit, payment accounts, tiers, service prices, ranks, names,
admin recruit models and weapons, driving styles, escort vehicles, air vehicle, and the integration section below.

## Integration

The resource is split so you only touch one file per concern:

```
config.lua              everything configurable
client.lua              squad logic (no framework calls)
server.lua              contracts, payments, roles (talks to Bridge only)
bridge/esx/             framework adapter (server: player, money, group, hooks; client: event names)
client/notify.lua       notification hook
client/phone.lua        exports + events for phones / other resources
html/                   the panel (NUI)
assets/                 store screenshots + showcase.html
```

### Framework (ESX for now)
`Config.Framework = 'esx'`. Everything framework-specific lives in `bridge/esx/`. To add another framework,
copy the folder, implement the same `Bridge.*` functions (`GetPlayer`, `IsAdminGroup`, `Notify`,
`OnPlayerLoaded`, `OnGroupChanged`) and the three client event names, add the files to `fxmanifest.lua`
and set `Config.Framework`.

### Notifications
`Config.Notify.Type`: `native` (GTA feed), `esx`, `ox_lib`, `okok`, `mythic` or `custom`.
For `custom`, edit `CustomNotify` in `client/notify.lua`. Every message, client and server, goes through
this one function. Kinds are `inform`, `success`, `error`, `warning`.

### Phone / other resources
```lua
exports['nk_bodyguard']:OpenPanel()     exports['nk_bodyguard']:ClosePanel()
exports['nk_bodyguard']:TogglePanel()   exports['nk_bodyguard']:OpenAgency()
exports['nk_bodyguard']:GetSquad()      exports['nk_bodyguard']:IsAdmin()
-- or TriggerEvent('nk_bodyguard:open' | 'nk_bodyguard:toggle' | 'nk_bodyguard:openAgency')
```
`Config.Phone`: set `Enabled = true` and `OpenEvent` to the event your phone fires; with `Resource = 'lb-phone'`
a "Bodyguards" app is registered automatically. Server side, `exports['nk_bodyguard']:Resync(src)` (or the
`nk_bodyguard:resync` event) re-sends contracts after another resource (e.g. a Tebex delivery) inserts one.

## Store assets

`assets/showcase.html` is a ready-made product page, and `assets/screenshots/` holds the panel screenshots.
They are rendered from the real UI in **demo mode**: open `html/index.html?demo=1&tab=squad&role=citizen`
(or `&shop=1`) in a browser. Demo mode never activates inside FiveM.
