# Sunpetal Kingdom — Cursor Build Context

> Read this before every prompt session. This is the single source of truth for what we are building and how.

---

## Engine & Stack

- **Engine:** Godot 4.2.2 (stable), located at `C:/Users/shurt/Desktop/Godot_v4.2.2-stable_win64.exe`
- **Language:** GDScript (all scripts `.gd`)
- **Editor:** Cursor + godot-tools extension (LSP on port 6005)
- **Assets:** Kenney.nl 3D kits (36 owned — listed below)
- **Distribution target:** itch.io → Steam (solo/single-player only)
- **GitHub:** `https://github.com/architectwuji-hash/sun-petal-kingdom`

---

## What This Game Is

Sunpetal Kingdom is a solo open-world fantasy action-RPG set in a reimagined Ocala, Florida. The world is an archipelago of islands inspired by real Marion County cities and landmarks. Players grow flowers that grant unique powers (called Ocali), explore the world, fight enemies, recruit companions, and build up their strength over time — in the vein of One Piece / Naruto / Dragon Ball, but family-friendly.

**Core loop:** Explore → fight enemies → gain XP/power → eat flowers → unlock new abilities → access new areas

---

## World Structure

- **Setting:** Archipelago of islands. Ocala is the central island (capital). The four incorporated Marion County cities (Belleview, Dunnellon, McIntosh, Reddick) sit at the four corners of the map. Real smaller communities (Anthony, Citra, Weirsdale, Summerfield, Moss Bluff, etc.) are scattered as small village islands. The Ocala National Forest is broken into multiple large islands.
- **Player starts:** A small village in the Ocala National Forest islands — NOT in the Ocala capital.
- **Map size:** Roughly 30–60 islands total. Islands vary widely in size and shape (gameplay-first, not mimicking real geography).
- **Day/night cycle:** 1 day = 6 real-time minutes (3 min day, 3 min night). 1 month = 30 in-game days. 1 season = 3 months.

---

## Power System (Ocali)

### How it works
- Plants/flowers grant powers called **Ocali**. A player only retains a flower's power while that flower is alive and growing in their garden. If the plant dies or is stolen, the power is lost until replanted.
- Player equips up to **4 powers** at once (loadout), freely chosen across all flowers they've grown.
- **No cooldowns.** Powers cost Ocali (resource meter). Base melee attack does NOT cost Ocali.
- **Ocali meter:** Starts at 750. Does NOT auto-regen. Restored by eating a Sunflower (+1000 flat per use).
- **Accuracy:** Base melee = 100% auto-aim. Flower power accuracy starts low, builds up through repeated use, maxes at 100% after 10,000 mastery points.

### Plant categories
| Category | Role |
|----------|------|
| **Flowers** | Main unique powers (16 flowers + Animal = 17 total) |
| **Trees** | Major late-game powers, earned through trials |
| **Herbs** | Healing items (combinable); work on player AND animals equally |
| **Shrubs/Berries (Food)** | Low-potency player restore (same mechanic as Herbs, much weaker) |
| **Grasses** | Pet/animal food (same role as Food, but for tamed animals) |
| **Sunflower** | Ocali refill only (+1000 flat). Not a power flower. |

### The 16 Flowers + Animal (with their 4 powers each)
All native to Florida/Marion County:

| Flower | Powers |
|--------|--------|
| Frogfruit | Extreme jumping, indefinite swimming, tongue attack, Contact Toxin |
| Garberia | Fire attacks, heal-from-fire→XP, root/regrowth respawn, sticky inventory |
| Coreopsis | Tick debuff, bird attack summon, self-seeding seasonal leveling, bloom clock |
| Spiderwort | Poison detection, root-lock self, sap trap, pollinator swarm |
| Blazing Star | Whisper vine, petal storm, reflect/mirror, cactus needle spray |
| Black-Eyed Susan | Tremor sense, weakness sensing, fungal network, night vision |
| Scarlet Sage | Purifying pulse, Emergency Heal, Regen Aura, Sage Smoke |
| Stoke's Aster | Skin hardening, gilded petal armor, elemental absorption, auto-flinch/dodge |
| Pinxter Azalea | Silence field, symbiosis/parasite, blightskin, Toxic Bloom Burst |
| Oak-leaf Hydrangea | Doppelganger swap, Illusion Decoy, adaptive camouflage, Chromatic Ward |
| Orange Milkweed | Size Shift, molting flare, Chrysalis Shell, Wing Emergence |
| Pink Swamp Milkweed | Weightless float/glide, life-link/bonding, nectar lure, water-sitting regen |
| Dune Sunflower | Rootbeacon, seed-storage, spore link, bioluminescence |
| Sunshine Mimosa | Freeze/play dead, mimicry, invisibility, cloning |
| Florida Anise | Pollen cloud, wilt touch, gravity manipulation, root-reading |
| Animal | Animal transformation, windrider, Bloomguard familiar, shapeshifting |
| *(Flight flower — TBD, given by hermit)* | Flight |

Each flower also has a **base attack** (melee-type, named after the flower, deals 100% of player's power level on hit).

### 6 Native Trees (earned through trials, major powers)
Live Oak, Southern Magnolia, Longleaf Pine, Eastern Red Cedar, Cabbage Palm, Dwarf Palmetto.

---

## Combat

- **Controls (planned):** Space = Melee, F = Jump, Shift = Run, E = Interact, I = Inventory, M = Map, C/V/B/N = 4 power slots
- **Melee attack:** Toggle auto-attack (when ON, auto-hits enemies in range; when ON, player cannot run)
- **Running:** Gated by stamina. Stamina grows through USE (running more = higher capacity). Also scales with player power level.
- **Defense:** Only from specific flower powers (e.g. gilded petal armor). No dedicated block/dodge button.
- **Targeting:** Auto-aim accuracy stat. Base attacks = 100% accuracy. Flower powers build accuracy through use.
- **Permadeath:** If player dies with no respawn plant grown in garden → game over, start over. Each respawn plant grown = 1 respawn at that plant's location. Plants are consumed on use.

### Damage formula
- Base melee (no flower): 10% of player's power level
- Base attack (flower eaten): 100% of player's power level
- Flower powers: 100% of player's power level (spend Ocali)
- Defense: blocks damage up to defender's Ocali level; excess passes through as the difference

### XP formula
- XP gained from defeating an enemy = that enemy's power level
- Player's max HP = their total XP/power level
- Power level also determines: speed, accuracy, stamina capacity, ranged attack range

---

## Story — Chapter 1: "The Weight of a Soul"

9 missions introducing every core mechanic through story:

1. **Survive** — find food, attacked by wild animal, make it home
2. **The Angel's Offer** — angel offers a soul-capturing sword, tasks player to kill the Duskhorn first
3. **The Master in the Woods** — Ocali master encounter; learn Ocali Blast or get beaten to 1% first
4. **Souls** — kill bugs, learn soul absorption, meet Gobokuro at Temple Altar (converts souls to stats, 1 soul per stat)
5. **The Rival** (timed 90s) — rival kills Ocali master; kill rival = money + unique item; fail = rival escapes stronger
6. **The Duskhorn** — kill the named animal with new abilities
7. **The Sword** — angel transforms Duskhorn into soul-capturing sword
8. **The Road to the First Sky City** — grind arc north, ruined villages, second Temple Altar, first floating island glimpse
9. **Beneath the Sky** — reach Sky Gate City; old Sun Army fighter teaches Cloning after soul count check

---

## Map Zones (Chapter 1, south → north)
- Starting Village (center, campfire, safe zone)
- Forest of Trials (low-level bugs, first grind)
- Gobokuro's Temple (west, first altar)
- Resource Caves (west, ore/crystals)
- Swamp Zone (east, poison enemies, rare crafting)
- Ruined Village (mid-road, medium enemies, lore)
- Battlefield Grounds (north, high-level wave enemies)
- Sky Gate City (far north, NPC city, shops, Cloning master, base of floating islands)

**Floating Islands (above mainland):**
- Island 1 (lowest/largest) — green, small settlement, mini boss, jump upgrade
- Island 2 (middle) — rocky/purple, second altar, dodge master NPC
- Island 3 (highest/smallest) — Gobokuro's domain, storm clouds, endgame Ch. 1

---

## Rival System

Rivals are autonomous NPCs that level up over real time, pursue their own goals, and can be fought or befriended. They have memory of past encounters.

**Confirmed starting rivals (each tied to a Marion County city):**
- **Bramble** (Reddick) — loner, wants to become unbeatable so no one controls him
- **Coral** (Dunnellon) — glory-seeker, races to famous quests, will betray for personal glory
- **Marrow** (McIntosh) — scholarly, wants to learn every flower type, safest ally
- **Thorne** (Belleview) — evil archetype, wants to conquer his home then expand; recruits and betrays
- **Wisp** (Forest, same origin as player) — anxious foil who wants to keep up with the player; likely ally

Rivals gain XP and power autonomously. Defeating a rival grants XP equal to their level. Rivals may drop unique items. Rivals can interact with and have relationships among themselves (emergent, not scripted).

---

## Village Simulation

Each village has an independent living economy:
- **Population ratio** (men/women) drives natural growth rate
- **Resources** are limited and refresh on timers (herbs/food: 1x/in-game day; trees: 1 real week)
- **Village health score** (0–100): above 70 = thriving; 40–70 = stable; below 40 = at-risk; below 20 = crisis
- **Animal takeover** triggers when population drops below 25% of peak OR below 15 residents (whichever is higher)
- **Trade route disruption** when resource stock stays below 20% capacity for 3+ in-game days
- **Tax system:** villages tax income → fund defense and improvements
- NPCs have jobs, can be hired by the player, can migrate between islands

---

## Animals / Wildlife

- Sourced from **Kenney Cube Pets** (24 species, all used)
- Pack-based, species-appropriate, biome-appropriate placement
- Animals fight each other autonomously once populations hit threshold
- Wild animals eat herbs/food, competing with villagers for resources
- Players can **tame** animals whose power level is lower than the player's
- Tamed pets gain XP/level from their own fights, can die permanently
- Tamed animals auto-fight when enemy is nearby; at high player power, can roam autonomously (same island only)

---

## Owned Kenney.nl 3D Kits (36 total)
Blaster Kit, Blocky Characters, Brick Kit, Building Kit, Car Kit, Castle Kit, City Kit (Commercial/Industrial/Suburban), Cube Pets (24 species), Factory Kit, Fantasy Town Kit, Food Kit, Furniture Kit, Graveyard Kit, Hexagon Kit, Holiday Kit, Mini Arena, Mini Characters (26), Mini Dungeon, Mini Forest, Mini Market, Modular Buildings (preferred house: `building-sample-house-a/b/c`), Modular Cave Kit, Modular Dungeon Kit, Modular Space Kit, Nature Kit (329 assets — master terrain/tree kit), Pirate Kit (72), Platformer Kit, Retro Fantasy Kit, Retro Urban Kit, Space Kit, Space Station Kit, Survival Kit, Tower Defense Kit, Watercraft Pack (46)

---

## Project Folder Structure

```
sun petal kingdom godot/
├── project.godot          ← Godot 4.2 project file (do not hand-edit)
├── CONTEXT.md             ← THIS FILE — read before every session
├── .cursorrules           ← Cursor AI coding rules
├── .vscode/settings.json  ← godot-tools extension config
├── scenes/                ← .tscn scene files
├── scripts/               ← .gd GDScript files
├── assets/
│   ├── textures/
│   ├── audio/
│   └── fonts/
├── ui/                    ← UI scenes and themes
└── addons/                ← Godot plugins
```

---

## Build State

**Nothing is built yet in Godot.** This is a clean scaffold. Prior builds of this game were:
- A browser game (Three.js / Cloudflare D1) — **abandoned**
- A Roblox Studio build — **abandoned**

The Godot build starts from scratch. We build scene by scene, script by script, following the design above.

---

## Development Rules

1. **One thing at a time.** Each Cursor prompt should do exactly one well-defined task.
2. **Prescriptive prompts only.** Vague/open-ended prompts produce bad results. Always specify exact numbers, node names, and expected behavior.
3. **All scripts in `/scripts/`.** One `.gd` file per scene/system.
4. **No hardcoded magic numbers.** Use constants or exported variables.
5. **Test every feature before moving to the next.** Open Godot and run the scene.
6. **Git commit after every working feature.** Message format: `feat: [what it does]`
