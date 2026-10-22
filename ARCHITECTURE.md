# Architecture

LÖVE 11.4+ runs the application. The game uses Lua 5.1-compatible modules without external runtime dependencies. The simulation and content modules also run in plain Lua.

| Module | Responsibility |
| --- | --- |
| `main.lua`, `conf.lua` | Engine callbacks, virtual resolution, input transformation, window settings |
| `src/game.lua` | Scene transitions, exploration, NPC interactions, inventory, progression, save lifecycle |
| `src/render/screens.lua` | Title, starter selection, overworld, battle, journal, shop, ending |
| `src/render/ui.lua` | Colors, fonts, hit areas, panels, health bars, physical scissor conversion |
| `src/render/art.lua` | Original creature designs, terrain, buildings, characters, title landscape |
| `src/data/creatures.lua` | Species, base stats, evolution, learnsets, techniques, element colors |
| `src/data/world.lua` | Deterministic map construction, encounters, NPCs, gates, wardens, dialogue |
| `src/systems/creature.lua` | Creature instances, stats, shared experience, learning, evolution |
| `src/systems/battle.lua` | Pure turn resolver, enemy choices, elemental matches, resources, capture |
| `src/systems/save.lua` | Safe codec, bounded parsing, checksum, primary/backup file rotation |
| `src/systems/audio.lua` | Procedural notes and SFX, music motifs, source playback, mute |
| `tests/` | Deterministic headless unit and campaign checks |
| `scripts/smoke.lua` | Real LÖVE rendering and interaction smoke run |

The renderer uses a 1280×800 virtual canvas, proportionally scaled and letterboxed. World maps use 32-pixel tiles with camera following and interpolated tile movement. Mouse coordinates and scissor rectangles account for window scaling.

Persistent state is a plain table: player position, party, storage, supplies, money, seals, defeated NPCs, creature discoveries, visited regions, steps, time, starter, and completion. Battle state is temporary. A checkpoint is saved before combat; rewards and catches are committed together on the results transition. The save parser never evaluates source code.

Battle functions accept an injected uniform random function. Tests cover exact state changes without relying on engine timing. Campaign simulations use normal local encounters, actual capture turns, shared experience, evolving teams, supplies, shops, and all four wardens. They check that both explorer and direct routes can complete the campaign; they do not measure human play time.

To add content, define a species and learnset in the creature data, add it to a regional encounter table, and choose a supported artwork shape. The field guide builds from the species table automatically. World tests ensure every creature is obtainable and each gated warden is reachable in the right order.
