# nk_bodyguard

NPC bodyguards for FiveM (ESX-friendly, standalone) with an in-game **Bodyguard Center** panel.

![Bodyguard Center](https://img.shields.io/badge/FiveM-resource-blue) ![Lua](https://img.shields.io/badge/Lua-5.4-informational)

## Features

- `/bodyguard [n]` recruits up to 6 armed guards (model + weapon pickers). Admin-only by default.
- **F9** opens the Bodyguard Center (NUI, sidebar layout):
  - **Home** – stats, mode (Follow / Hold / Aggressive / Hold fire), quick orders, recruit, event log.
  - **Squad** – table of guards with per-guard orders: Attack, Follow, Go to, Mark in minimap, Send home, Cancel, Come to me, Hold, Heal, Re-arm, Make driver, Dismiss.
  - **Formation** – Loose / Circle / Wedge / Line / Custom with a drag-and-drop editor (1 square = 1 m) and spacing slider; changes apply on **Apply**.
  - **Vehicle** – seat assignment per guard incl. a **Driver** seat (that guard chauffeurs you to your waypoint), driving styles Calm → Insane, chauffeur / cruise / swap / stop, escort car, air-support helicopter, auto drive-by.
  - **Settings** – invincible, health regen, auto-reinforce, blips, accuracy, panel position / size.
- **Mark & attack** / **Move to position**: aim in-game, **E** confirms, **Esc** cancels. Marked peds are fought until dead, marked vehicles shot until destroyed.
- **Caps Lock** – attack whatever you are aiming at.
- Guards are never teleported: they walk / run / sprint into formation, chase your car and board when it stops.
- Following, boarding and defending are script-driven (the game's ped-group is not used, it caps at two members).

## Install

1. Drop the folder into `resources/` and add `ensure nk_bodyguard` to `server.cfg`.
2. The command is restricted (`Config.AdminOnly = true`): grant `command.bodyguard` (admins with `add_ace group.admin command allow` already have it).
3. Keys can be rebound in *Settings › Key Bindings › FiveM*.

## Config

See `config.lua`: models, weapons, health / armour / accuracy, driving styles (speed, flags, aggressiveness, top-speed boost), escort vehicles, air vehicle, defaults for the toggles.

## Notes

- Tested on FXServer 35245 / game build 3095 with ESX Legacy 1.15.
- `Config.Debug = true` prints squad events to the F8 console.
