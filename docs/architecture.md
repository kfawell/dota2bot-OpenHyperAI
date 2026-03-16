# OHA Architecture Overview

## Two Runtime Contexts

OHA operates in two completely separate Lua runtime environments within Dota 2. They share no global state and must not mix APIs.

### Bot Script Context
- **Files:** `bot_generic.lua`, `hero_selection.lua`, `mode_*.lua`, `ability_item_usage_generic.lua`, `item_purchase_generic.lua`, `BotLib/`, `FunLib/`
- **APIs:** `GetBot()`, `GetScriptDirectory()`, `dofile()`, `require()` with script-relative paths
- **Lifecycle:** Loaded per-bot at game start. Engine calls exported functions every frame.

### VScript Game Context
- **Files:** `FretBots.lua`, `FretBots/*.lua`, `Buff/*.lua`
- **APIs:** `GameRules`, `ListenToGameEvent()`, `CreateTimer()`, `FindUnitsInRadius()`
- **Lifecycle:** Loaded once via `require 'bots.FretBots.ModuleName'` (dot-path notation). Self-initializes via game state listeners.

---

## Execution Flow

### Game Startup Sequence

```
Engine loads hero_selection.lua (once per team)
  ├── Think() called every frame during pick phase
  ├── Reads Customize/general.lua for bans, presets, settings
  ├── Builds role-specific hero pools from aba_hero_pos_weights.lua
  ├── Scores candidates via matchup data (FretBots/matchups_data.lua)
  └── Picks heroes with staggered timing (1s apart + jitter)

Engine loads bot_generic.lua (once per bot hero)
  ├── dofile() loads BotLib/hero_<name>.lua → returns table X
  ├── X contains: sBuyList, sSellList, sSkillList, bDeafaultAbility, bDeafaultItem
  └── Exports MinionThink() for summon/illusion AI

Engine loads ability_item_usage_generic.lua (per bot)
  ├── AbilityLevelUpThink() — levels abilities from X.sSkillList
  ├── AbilityUsageThink() — delegates to X.SkillsComplement()
  ├── ItemUsageThink() — dispatches via X.ConsiderItemDesire table
  ├── BuybackUsageThink() — buyback decisions + glyph usage
  └── CourierUsageThink() — courier state machine

Engine loads item_purchase_generic.lua (per bot)
  └── ItemPurchaseThink() — component queue state machine from X.sBuyList

Engine loads each mode_*.lua (per bot)
  └── GetDesire() polled every frame; highest-desire mode's Think() runs
```

### FretBots Startup (VScript Context)

```
FretBots.lua loaded via require
  ├── Registers Initialize() for DOTA_GAMERULES_STATE_PRE_GAME
  └── Initialize() fires:
      ├── PlayersLoadedTimer (1s interval, up to 3 ticks)
      │   ├── DataTables:Initialize() — builds AllBots, AllHumanPlayers
      │   ├── Settings finalization — difficulty voting, chat commands
      │   ├── NeutralItems:Initialize() — neutral item timing/distribution
      │   ├── BonusTimers:Register() — GPM/XPM/stat bonuses
      │   ├── RoleDetermination:Initialize() — lane-based role assignment
      │   └── OnEntityKilled/Hurt listeners registered
      └── Posts to DotaRunner at /api/fretbots/init
```

---

## Mode System (Desire-Based Behavior Selection)

Every frame, the engine polls `GetDesire()` on all ~20 mode files and activates the highest one. Modes return float values 0.0–1.0 (constants like `BOT_MODE_DESIRE_HIGH` ≈ 0.75). Some modes exceed 1.0 for pre-emption.

### Mode Priority Hierarchy (typical)

| Priority | Mode | Desire Range | Notes |
|----------|------|-------------|-------|
| 1 | Retreat | 0 – 1.1+ | Highest; uses HP/MP curve + enemy count |
| 2 | Farm (run mode) | ABSOLUTE×1.1 | When massively ahead, bomb enemy base |
| 3 | Rune | 0 – 0.95 | Bounty/power/water/wisdom collection |
| 4 | Roshan | 0 – 0.95 | DPS check + enemy proximity |
| 5 | Tormentor | 0 – 0.9 | Level/DPS gating, team assembly |
| 6 | Laning | 0.01 – 0.9 | Last-hit creep override peaks at 0.9 |
| 7 | Push (×3 lanes) | 0 – 0.85 | Delegated to aba_push.lua |
| 8 | Defend (×3 lanes) | 0 – 0.9 | Delegated to aba_defend.lua |
| 9 | Ward | 0 – VERYHIGH | Pos 4–5 only |
| 10 | Roam | 0 – ABSOLUTE | Hero-specific ganking |
| 11 | Team Roam | complex | Team fight participation |
| 12 | Outpost | VERYLOW – HIGH | After enemy T2 falls |
| 13 | Secret Shop | 0 – 0.95 | When items need secret shop components |
| 14 | Farm (normal) | 0.4 – HIGH | **Currently broken — see bugs** |

### Mode Override System

Heroes in `Utils.BuggyHeroesDueToValveTooLazy` use override files from `FunLib/override_generic/`:
- `mode_attack_generic.lua` — custom attack targeting
- `mode_laning_generic.lua` — reimplements lane assignment from OHA's position system

---

## Hero Config System (BotLib/hero_*.lua)

127 hero files, each returning a table `X`. Loaded via `dofile()` from `bot_generic.lua`.

### Standard Template

```
Section 1: Module header (require J, dofile Minion, get talent/ability/role)
Section 2: Talent tree definition (t10/t15/t20/t25 weights)
Section 3: Ability build list (15 entries for levels 1-15)
Section 4: Item builds by role (pos_1 through pos_5)
Section 5: Export table (sBuyList, sSellList, sSkillList, bDeafaultAbility/Item)
Section 6: MinionThink() — summon/illusion AI
Section 7: Ability variable declarations
Section 8: SkillsComplement() — main ability casting logic
Section 9: ConsiderAbility*() functions — per-ability evaluation
Section 10: return X
```

### Complexity Tiers

| Tier | Lines | Examples | Distinguishing Features |
|------|-------|---------|------------------------|
| Simple | 150–300 | Wraith King, Lone Druid | Single build, basic abilities |
| Standard | 400–700 | Anti-Mage, Dragon Knight | Multi-role builds, combo logic |
| Complex | 800–1900 | Crystal Maiden, Invoker | Shared state, timestamp chaining, custom helpers |

### Key Patterns in SkillsComplement()

1. **Linear priority chain** — compute each ability's desire, execute first positive, return early
2. **Combo-first ordering** — check combined abilities before individual ones (Anti-Mage Blink+ManaVoid)
3. **Timestamp chaining** — track cast times, chain follow-up abilities within time windows (Invoker)
4. **Pre-processing** — run combo checks before the castability guard (Crystal Maiden Shadow Amulet during channel)

---

## Item Purchase Pipeline

```
hero_*.lua defines sBuyList (ordered item names)
  → item_purchase_generic.lua reverses list into purchaseListInReverseOrder
    → Pops last item, decomposes via Item.GetBasicItems() into leaf components
      → _buildRequiredCounts() tracks how many of each component needed
        → _stillNeeds() checks inventory/stash to avoid double-buying
          → ActionImmediate_PurchaseItem() buys one component per tick
            → When all components owned, engine auto-assembles the item
              → Next item popped from queue
```

Interleaved with: consumable purchases (clarity, dust, wards, TP, shard), dropped item recovery, Lone Druid bear item management, and transitional item selling.

---

## FretBots Enhanced Difficulty System

Operates entirely in VScript context. Enhances bot performance through direct stat manipulation rather than behavioral changes.

### Module Dependency Graph

```
FretBots.lua (orchestrator)
  ├── Debug, Flags, Utilities (infrastructure)
  ├── DataTables (AllBots, AllHumanPlayers initialization)
  ├── Settings (difficulty voting, chat commands, config)
  ├── DynamicDifficulty (reactive GPM/XPM adjustment on deaths)
  ├── BonusTimers (periodic gold/XP/stat bonuses)
  ├── NeutralItems (tiered neutral item distribution)
  ├── RoleDetermination (lane-based role assignment)
  ├── OnEntityKilled / OnEntityHurt (event listeners)
  ├── AwardBonus (direct stat manipulation)
  ├── DotaRunner (HTTP bridge to desktop app)
  └── Chat, Soundboard, HeroSounds (player interaction)
```

### Difficulty Scale

| Difficulty | Scale | Effect |
|-----------|-------|--------|
| 0 | 0.5 | Half bonuses |
| 5 | 0.68 | Below baseline |
| 7 | 0.88 | Near baseline |
| 10 | 2.0 | Double bonuses |

### DotaRunner Integration

FretBots POSTs to `http://127.0.0.1:27016` at key events:
- `/api/fretbots/init` — version on startup
- `/api/fretbots/intervention` — active interventions
- `/api/fretbots/game-start` — difficulty level
- `/api/fretbots/game-end` — winner
- `/api/fretbots/roles` — bot role assignments

---

## Data Flow Diagram

```
Customize/general.lua ──→ hero_selection.lua ──→ hero picks
                     └──→ FretBots/Settings.lua

aba_hero_pos_weights.lua ──→ hero_selection.lua (pool building)
matchups_data.lua ──→ hero_selection.lua (scoring)
hero_pick_history.lua ──→ hero_selection.lua (rotation weighting)

BotLib/hero_*.lua ──→ bot_generic.lua (MinionThink)
                 └──→ ability_item_usage_generic.lua (SkillsComplement, ConsiderItemDesire)
                 └──→ item_purchase_generic.lua (sBuyList)

jmz_func.lua (J) ──→ Everything in bot script context
aba_site.lua ──→ mode_farm, mode_push, mode_defend, mode_laning
aba_role.lua ──→ hero_selection, item_purchase, mode_*
aba_item.lua ──→ item_purchase_generic, ability_item_usage_generic

FretBots/DataTables.lua ──→ All FretBots modules (AllBots, AllHumanPlayers)
FretBots/Settings.lua ──→ BonusTimers, DynamicDifficulty, NeutralItems
```

---

## Customization Layer

### Load Order

`FunLib/custom_loader.lua` tries user's local vscripts folder first (`game/Customize/general`), falling back to the workshop's `Customize/general.lua`. Per-hero overrides in `Customize/hero/[heroname].lua` can replace ability builds, talent trees, item builds, and sell lists.

### Override Precedence

```
Customize/hero/*.lua (per-hero user override)
  → J.SetUserHeroInit() applies overrides
    → BotLib/hero_*.lua base config (fallback)
      → ability_item_usage_generic.lua bDeafaultAbility/Item (engine default fallback)
```
