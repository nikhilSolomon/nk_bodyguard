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
admin recruit models and weapons, driving styles, escort vehicles, air vehicle.
