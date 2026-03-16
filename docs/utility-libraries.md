# Utility Libraries (FunLib/)

## Overview

FunLib/ contains the shared utility code imported by all bot scripts. Two maintenance domains exist:

- **Hand-written Lua:** `jmz_func.lua`, `aba_skill.lua`, `aba_item.lua`, `aba_chat.lua`, `aba_minion.lua`, `aba_ward_utility.lua`, `aba_buff.lua`, `aba_matchups.lua`, `localization.lua`, `custom_loader.lua`, `version.lua`
- **TypeScriptToLua generated:** `utils.lua`, `aba_role.lua`, `aba_site.lua`, `aba_defend.lua`, `aba_push.lua`, `global_cache.lua` — **do not edit directly**; fix in `ts_libs/` sources

### Dependency Graph

```
jmz_func.lua (J) ← imported by everything
  ├── aba_site.lua (J.Site) — map awareness, positions
  ├── aba_item.lua (J.Item) — item management
  ├── aba_buff.lua (J.Buff) — modifier name lists
  ├── aba_role.lua (J.Role) — position/role assignment
  ├── aba_skill.lua (J.Skill) — ability upgrades
  ├── aba_chat.lua (J.Chat) — chat/communication
  ├── utils.lua (J.Utils) — TS runtime + validation
  └── custom_loader.lua (J.Customize) — config loading

aba_push.lua / aba_defend.lua
  ├── jmz_func.lua
  ├── utils.lua
  └── global_cache.lua (TTL caches)

aba_minion.lua
  └── minion_lib/*.lua (7 sub-modules)
```

---

## jmz_func.lua — Master Library (~6552 lines)

The universal `J` namespace. ~400+ functions organized into functional categories.

### Action Guards

| Function | Purpose |
|----------|---------|
| `J.CanNotUseAction(bot)` | Stunned, channeling, invulnerable, Force Staff, Tinker Rearm |
| `J.CanNotUseAbility(bot)` | Superset: also silenced, hexed, Doomed |
| `J.IsTryingtoUseAbility(bot)` | Mid-cast or channeling |
| `J.HasQueuedAction(bot)` | `NumQueuedActions() > 0` (only works for `GetBot()`) |

### Unit Validation

| Function | Purpose |
|----------|---------|
| `J.IsValid(target)` | Not nil, not null, visible, alive, **not building** |
| `J.IsValidTarget(target)` | Delegates to `J.Utils.IsValidHero` |
| `J.IsValidHero(target)` | Wrapper around Utils |
| `J.IsValidBuilding(target)` | Building-specific validation |
| `J.IsSuspiciousIllusion(target)` | Sophisticated illusion detection via modifiers + level comparison. Caches result on unit handle. |

### Proximity Queries

| Function | Purpose |
|----------|---------|
| `J.GetAlliesNearLoc(loc, radius)` | Iterates team players, returns alive within radius |
| `J.GetEnemiesNearLoc(loc, radius)` | Iterates enemy heroes, filters illusions/clones |
| `J.GetAnyEnemiesNearLoc(loc, radius)` | Includes illusions/clones |
| `J.GetIllusionsNearLoc(loc, radius)` | Returns only illusions |
| `J.GetAroundTargetEnemyHeroCount(target, radius)` | Count enemies near a target |
| `J.GetNearbyAroundLocationUnitCount(enemy, hero, radius, loc)` | Combined hero/creep counter |

**Performance note:** All caching logic is commented out. Every call iterates the full unit list. With 5 bots × multiple modes × multiple abilities per frame, this is the single largest performance concern. The `global_cache.lua` system was added for TS modules but `jmz_func.lua` calls remain uncached.

### State Queries

| Function | Purpose |
|----------|---------|
| `J.GetHP(unit)` | Health fraction 0.0–1.0. Uses `OriginalGetHealth()` for allies (FretBots-adjusted) |
| `J.GetMP(bot)` | Mana fraction. Returns HP ratio for Huskar |
| `J.GetEffectiveHP(bot)` | Includes Medusa Mana Shield |
| `J.IsEarlyGame()` | `< 15:00` (8:00 turbo) |
| `J.IsMidGame()` | 15:00–30:00 (8:00–18:00 turbo) |
| `J.IsLateGame()` | `> 30:00` (18:00 turbo) |
| `J.IsInLaningPhase()` | Delegates to utils |
| `J.IsCore(bot)` | `GetPosition(bot) <= 3` |
| `J.GetPosition(bot)` | Delegates to `J.Role.GetPosition()` |
| `J.GetAverageLevel(enemy)` | Iterates all players. Uncached |
| `J.GetInventoryNetworth()` | Returns `(ally_nw, enemy_nw)` |
| `J.DoesTeamHaveAegis()` | Checks if any ally has Aegis |
| `J.GetDistance(s, t)` | Wrapper with unit/location type detection |

### Combat Helpers

| Function | Purpose |
|----------|---------|
| `J.WillKillTarget(target, dmg, type, delay)` | Kill prediction accounting for regen and ally attacks |
| `J.WillMagicKillTarget(bot, target, dmg, delay)` | Magic damage with SpellAmp, MagicResist, Mana Shield, Bristleback, TA Refraction |
| `J.CanCastAbilityOnTarget(target, ignoreMI)` | Cast validity: visible, not MI, not invulnerable, no forbidden modifier |
| `J.CanCastAbility(ability)` | Ability readiness: not passive/hidden, trained, castable |
| `J.CanCastOnTargetAdvanced(target)` | AM spell shield, Linken's, Lotus Orb, Aeon Disk checks |
| `J.HasForbiddenModifier(target)` | Checks immunity modifiers. **Has hidden "mercy rule"**: refuses to target players with 6+ deaths and KDA ≤ 0.3 |
| `J.GetProperTarget(bot)` | Best current attack target |
| `J.IsAllyCanKill(target)` | Whether nearby allies will finish the target |
| `J.GetCorrectLoc(target, delay)` | Predictive targeting weighted by movement stability |
| `J.ShouldEscape(bot)` | HP < 16%, recently damaged, 2+ enemies nearby |

### Item Helpers

| Function | Purpose |
|----------|---------|
| `J.HasItem(bot, name)` | Item in main inventory (slots 0–5) |
| `J.GetComboItem(bot, name)` | Returns item object if in main slot |
| `J.CanBlinkDagger(bot)` | Checks all blink variants, stores in `bot.Blink` |
| `J.CanBlackKingBar(bot)` | BKB readiness, stores in `bot.BlackKingBar` |
| `J.HasPowerTreads(bot)` | Checks all four variants |

### Other Notable Functions

| Function | Purpose |
|----------|---------|
| `J.SetUserHeroInit(...)` | Loads per-hero customization from `Customize/hero/` |
| `J.CheckBotIdleState()` | Idle detection: if stuck > 3s, clears actions, sends to lane |
| `J.IsModeTurbo()` | Game mode 23 check |

### Module-Level State

- `tAllyIDList`, `tAllyHeroList`, `tAllyHumanList` — Populated once at require time. **Never updated** — stale after disconnects/reconnects.
- `RadiantFountain`, `DireFountain` — Hardcoded Vector coordinates.
- `RadiantTormentorLoc`, `DireTormentorLoc` — Hardcoded.
- `fKeepManaPercent = 0.39` — Mana conservation threshold.

---

## aba_role.lua — Position/Role System (TS-generated)

Manages position assignment (1–5) for bots and enemies.

### Key Functions

- `GetPosition(bot)` — Checks `bot.assignedRole` → `HeroPositions[id]` → CM inference → static `RoleAssignment` table
- `GetPositionForCM(bot)` — Infers from assigned lane + hero traits
- `UpdateInvisEnemyStatus(bot)` — Sets `invisEnemyExist` flag. Two-phase: name check, then item scan after 10 min. **Flag never resets once set.**
- `IsCarry`, `IsDisabler`, `IsDurable`, etc. — Delegates to `HeroRolesMap`

### Key State

- `RoleAssignment` — Static cyclic position assignment (1–5) for up to 15 slots
- `HeroPositions` — Written by FretBots/RoleDetermination, read here
- `invisEnemyExist`, `supportExist`, `aegisHero` — Module-level flags

---

## aba_skill.lua — Ability Upgrade Engine

### Key Functions

- `GetAbilityList(bot)` — Scans slots 0–10, returns ability names. Handles `generic_hidden`, innate, ultimate detection
- `GetSkillList(abilities, build, talents, talentBuild)` — Constructs level 1–30 leveling order. Special cases for Meepo (hardcoded) and Invoker (21-entry builds)
- `GetRandomBuild(buildList)` — Random entry from build array
- `GetTalentBuild(talentTree)` — Converts weight pairs to index list
- `IsHeroInEnemyTeam(hero)` — Enemy team hero check

### Static Data

- `sAllyUnitAbilityIndex` — Abilities targeting allies (incomplete — missing oracle, abaddon)
- `sProjectileAbilityIndex`, `sStunProjectileAbilityIndex` — Projectile ability whitelists

---

## aba_item.lua — Item Management

### Key Data

- `Item.sBasicItems` — ~80 basic components
- `Item.sSeniorItems` — Mid-tier combined items (has duplicate `item_rod_of_atos`)
- `Item.sTopItems` — Late-game items
- `Item.tEarlyItem`, `tEarlyConsumableItem`, `tEarlyBoots` — Early game classification
- `Item.sSellList` — Flat array alternating sell/replace pairs (fragile)
- `Item.sCanNotSwitchItems` — Items that shouldn't be swapped between slots

### Key Functions

- `Item.GetComponentList(itemName)` — First-level components via engine `GetItemComponents()`
- Component tables `Item['item_*']` — ~100+ entries called at module load time
- `Item.GetRoleItemsBuyList(bot)` — Returns role string for hero config lookup

---

## aba_push.lua — Push/Siege System (TS-generated)

### Key Functions

- `GetPushDesire(bot, lane)` — Entry point with validity checks
- `GetPushDesireHelper(bot, lane)` — Core: networth advantage, alive counts, enemy proximity, ping targets
- `PushThink(bot, lane)` — Per-frame: retreat from tower, attack ancient, clear creeps, highground targeting
- `WhichLaneToPush(bot, lane)` — Scores lanes by team distance (cores 5×), enemy presence, TP arrivals, building tier
- `SelectOrStickHGTarget(bot, lane, loc)` — Anti-thrash: locks target for 1.2s, requires +0.25 score margin to switch

### Caching

Uses `gameStateCache`, `locationStateCache`, `unitStateCache` (TTL 0.5s) and `botStateCache` (TTL 0.2s).

### Critical Bugs

- `lastAction`, `lastThinkTime`, `fNextMovementTime` are **module-level** — shared across all 5 bots instead of per-bot
- `locationStateCache.enemyFountain` set to **ally fountain** (`GetTeamFountain()` instead of `GetEnemyFountain()`)

---

## aba_defend.lua — Defense System (TS-generated)

Provides `GetDefendDesire(bot, lane)` and `DefendThink(bot, lane)`. Handles threat assessment, TP coordination (avoids 5 bots TPing to same tower), shrine usage.

---

## aba_site.lua — Map Awareness (~63KB, TS-generated)

Lane front queries, tower state checks, distance calculations, Roshan/Tormentor locations. Provides the `J.Site` sub-API.

---

## aba_buff.lua — Modifier Constants (TS-generated)

Pure data file. Named modifier-name lists:

| Table | Purpose |
|-------|---------|
| `creep_is_immune` | Creep untargetable modifiers |
| `enemy_is_immune` | Enemy targeting prevention (missing Omnislash) |
| `enemy_is_undead` | Borrowed Time, Shallow Grave, False Promise |
| `enemy_not_illusion` | Real-hero-only modifiers (BKB, Satanic) |
| `enemy_is_illusion` | Illusion indicators |
| `hero_is_taunted` | Forced-attack modifiers |
| `hero_is_healing` | Active healing modifiers |
| `hero_not_invisible` | Invis-breaking/detection modifiers |

---

## aba_ward_utility.lua — Ward Placement

### Key Functions

- `GetAvailabeObserverWardSpots(bot)` — Filtered by game time, tower states, existing wards, enemy sentries
- `GetPossibleSentryWardSpots(bot)` — Near existing/dewarded observer spots
- `GetClosestObserverWardSpot(bot, spots)` — Nearest spot
- `IsOtherWardClose(loc, wardName, radius, team, checkLifespan)` — Duplicate ward prevention
- `GetGameStartWardSpots()` — Randomized mid ward pick from 3 candidates

### Static Data

Large hardcoded tables: `WardLocationsBeforeAllyTowerFall__Radiant/Dire`, `WardLocationsAfterEnemyTowerFall__Radiant/Dire`, `WardLocationsEarlyGame__Radiant/Dire`. Nested by tower → array of `{location, plant_time_obs, plant_time_sentry}`.

**Bug:** Multiple duplicate table keys silently drop ward spots (e.g., `[4]` in `TOWER_MID_1` for Dire appears twice).

---

## aba_chat.lua — Chat System

### Key Functions

- `Chat.GetReplyString(string, allChat)` — Keyword-matched reply, taunt detection, random response. Chinese locale only for taunts.
- `Chat.GetRepeatString(string)` — Parroting: strips pronouns, flips question particles
- `Chat.GetLocalName(bot)` — **Bug:** Returns raw internal name, not localized
- `Chat.GetItemCnName(rawName)` — Chinese item name lookup
- `Chat.AllowTrashTalk(allChat)` — Gates on `Customize.Allow_Trash_Talk`

### Static Data

- `tItemNameList` — ~200 item info objects
- `tHeroNameList` — ~130 hero entries (missing some newer heroes)

---

## aba_minion.lua — Summon/Illusion AI

Dispatcher routing each minion type to specialized sub-modules in `minion_lib/`:
- `illusions` — Generic illusion attack
- `vengeful_spirit` — VS Aghanim illusion
- `attacking_wards` — Venomancer wards, Necro warriors
- `primal_split` — Brewmaster spirits
- `familiars` — Visage (marked **broken since 7.37+**)
- `minion_with_skill` — Units with abilities (Warlock golems, LD bear)
- `jugg` — Healing Ward

**Bug:** Uses direct `require` for Customize, bypassing user override mechanism.

---

## aba_matchups.lua — Hero Matchup Data (~82KB)

Per-hero matchup scores for hero selection. Per-enemy values range ~-4 to +4, summed across enemies. ~16,000 entries. Used by `ScoreCandidatesForTeam()` in hero selection.

---

## localization.lua — Multi-Language Strings

Four locales: en, zh, ru, ja. Key functions:
- `X.Get(key)` — Lookup with `en` fallback
- `X.GetLocale()` — Current locale
- `X.Supported(key)` — Locale existence check

**Bug:** Setting locale mutates the shared `Customize` table as a side effect.

---

## custom_loader.lua — Config Loading

Singleton. Tries `game/Customize/general` (user override) → `Customize/general.lua` (workshop). Result memoized. **No nil guard** — if both paths fail, nil propagates to all consumers.

---

## utils.lua — TS Runtime + Validation (TS-generated)

Two layers:
1. **TS runtime shims** (~650 lines): ES6 class infrastructure, `Error` hierarchy, `Symbol` — mostly dead code in Dota 2 context
2. **Game utilities**: `IsValidUnit`, `IsValidHero`, `IsValidBuilding`, `NumHumanBotPlayersInTeam`, `AbilityBehaviorHasFlag`

---

## version.lua

```lua
____exports.number = "0.7.40 - 2026/03/03"
____exports.recentChangeLogs = {"GLHF"}
```

---

## Caching Architecture

Three inconsistent mechanisms:

| System | Where Used | TTL | Status |
|--------|-----------|-----|--------|
| `J.Utils.GetCachedVars()` | Intended for jmz_func.lua | Configurable | **Commented out** |
| `global_cache.lua` | aba_push, aba_defend | 0.2–0.5s | Active, well-designed |
| `bot.property` monkey-patching | jmz_func.lua | Permanent | Active, no invalidation |

The inconsistency means TS modules benefit from caching while the most-called functions in `jmz_func.lua` iterate full unit lists every call.
