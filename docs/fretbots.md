# FretBots Enhanced Difficulty System

## Overview

FretBots operates in the VScript game context (separate from bot scripts). It enhances bot performance through direct stat manipulation — GPM/XPM bonuses, neutral item distribution, dynamic difficulty adjustment, and game-start stat boosts.

## Initialization Sequence

```
FretBots.lua loaded via require
  ├── Validates GameRules exists
  ├── Requires all modules in dependency order:
  │   Debug → Flags → DataTables → OnEntityKilled → OnEntityHurt →
  │   BonusTimers → Utilities → DynamicDifficulty → Settings → Timers →
  │   HeroLoneDruid → RoleDetermination → NeutralItems → DotaRunner
  ├── Guards maxTeamSize ~= 12 (must be full lobby)
  └── Registers Initialize() for DOTA_GAMERULES_STATE_PRE_GAME

FretBots:Initialize()
  ├── Sets random seed
  ├── Registers dota_on_hero_finish_spawn listener
  ├── Starts PlayersLoadedTimer (1s interval)
  └── POSTs to DotaRunner: /api/fretbots/init, /api/fretbots/intervention

PlayersLoadedTimer() (up to 3 ticks failsafe)
  ├── Waits for all heroes to spawn
  └── On ready:
      ├── DataTables:Initialize() → AllBots, AllHumanPlayers, AllUnits
      ├── Settings finalization → difficulty voting complete
      ├── NeutralItems:Initialize()
      ├── BonusTimers:Register()
      ├── RoleDetermination:Initialize()
      └── OnEntityKilled/Hurt listeners registered
```

---

## Module Reference

### Settings.lua — Configuration & Voting

**Voting flow:**
1. `InitializationTimer()` → locale selection (6s) → difficulty voting
2. `DifficultySelectTimer()` — 1s interval, displays announcements, closes on all voted or 40s timeout
3. `ApplyVoteSettings()` — averages votes (or uses `DefaultDifficulty`). Mixed team → second vote for ally scale
4. `StartCallback()` — validates against DotaRunner's `/start` endpoint difficulty cap

**Difficulty scale formula:**
```
difficulty < 5:  scale = 1 + (difficulty - 5) / 10     → diff 0 = 0.5
difficulty 5-9:  scale = 1 + (difficulty - 3.2) / 10   → diff 5 = 0.68, diff 7 = 0.88
difficulty >= 10: scale = 1 + difficulty / 10           → diff 10 = 2.0
```

**Chat commands:**
| Command | Effect |
|---------|--------|
| `/difficulty N` | Set difficulty (0–10) |
| `/set key value` | Modify any setting (dotted path) |
| `/nudge key ±N` | Adjust a numeric setting |
| `/get key` | Display current setting value |
| `/stats kills` | Show kill statistics |
| `/getroles` | Display bot role assignments |
| `/kb` | Kill a specific bot (debug) |
| `/enablecheat` | Toggle cheat detection/repercussions |
| `/info` | Show current difficulty and settings |
| `/networth` | Display bot net worths |
| `goodsound`/`badsound`/etc | Soundboard triggers |
| `me`/`vo`/`voc` | Hero voiceover playback |

**Cheat repercussions:** Detects Dota 2 console cheat commands from `CheatList.lua`. If enabled, force-kills the player `repurcussionsPerInfraction` times per cheat.

**GPT response:** Human all-chat messages (not starting with `!`) forwarded to `Chat:SendMessageToBackend()` if `Allow_AI_GPT_Response` enabled.

---

### DynamicDifficulty.lua — Reactive Scaling

**Trigger:** Called from `OnEntityKilled` when a bot dies.

**Logic:**
1. Gets `victim.stats.humanKillAdvantage`
2. If advantage > threshold: bonus = base + floor((advantage - threshold) / incrementEvery) × increment, capped
3. Updates `Settings.gpm.offset` and `Settings.xpm.offset`

**Known bugs:** See `bugs-and-improvements.md` — `victim` not in scope for `MakeAdjustment()`, cache shadowing, operator precedence error.

---

### BonusTimers.lua — Periodic Bonuses

**Timers:**

| Timer | Interval | Function |
|-------|---------|----------|
| `NeutralItemFindTimer` | 1s | Awards neutral items per bot timing |
| `PerMinuteTimer` | 60s | Awards GPM/XPM bonuses |
| `GameStartBonus` | Once | Applies difficulty-based stat boosts |

**GameStartBonus() stats scaled by difficulty:**
- HP/mana regen (×difficultyScale)
- Bonus gold, armor, magic resist
- Bonus levels, stats
- Initial neutral items

**Neutral item flow:**
```
NeutralItems:InitializeFindTimings() → per-bot timing with variance
  → NeutralItemFindTimer every 1s → check bot.stats.neutralTiming
    → NeutralItems:NeediestBotForToken(tier) → first bot below tier (carry-first)
      → NeutralItems:GetTokenTableForTier(tier) → pick best by desire
        → NeutralItems:GiveToUnit() → create in slot 16
```

---

### DataTables.lua — Global Unit Tables

Initializes `AllBots`, `AllHumanPlayers`, `AllUnits` tables. Finds all units at init via `FindUnitsInRadius`. Per-bot/player stats initialization including kill tracking, neutral timings, role data.

---

### RoleDetermination.lua — Lane-Based Roles

**Timer:** Runs every second for 20 seconds after game start. Records minimum distance from each bot to each T1 tower.

**DetermineRoles():** After 20 seconds, assigns LANE_SAFE/LANE_MID/LANE_OFF based on closest tower. Handles 8 trilane/dual-mid scenarios to assign roles 1–5. Re-orders `AllBots[team]` for neutral item priority.

---

### NeutralItems.lua — Item Distribution

**Key functions:**
- `GiveToUnit(unit, item)` — Creates item in slot 16, removes existing, cleans up stale modifiers
- `NeediestBotForToken(tier)` — First bot below tier (carry-first ordering)
- `GetBotDesireForItem(bot, item)` — Scores items by role/position
- `InitializeFindTimings()` — Per-bot timing with difficulty scaling + random variance
- `CloseBotFindTier(tier, team)` — Disables further finds when tier cap hit

---

### DotaRunner.lua — HTTP Bridge

One-way integration to DotaRunner desktop app. `DotaRunner:Post(endpoint, data)` fires-and-forgets JSON HTTP POST to `http://127.0.0.1:27016`. All failures silently swallowed by `pcall`.

**Endpoints:**
| Endpoint | When | Data |
|----------|------|------|
| `/api/fretbots/init` | FretBots startup | version |
| `/api/fretbots/intervention` | Init | active interventions |
| `/api/fretbots/game-start` | BonusTimers register | difficulty |
| `/api/fretbots/game-end` | Post-game | winner |
| `/api/fretbots/roles` | Role determination | role assignments |

---

### OnEntityKilled.lua — Death Event Handler

Listens to `entity_killed` game event. Updates kill stats per player/bot. Calls `DynamicDifficulty:Adjust()` on bot deaths. Awards death bonuses via `AwardBonus`.

---

### OnEntityHurt.lua — Damage Tracking

Listens to `entity_hurt`. Tracks damage dealt/received per player for statistics.

---

### Other Modules

| Module | Purpose |
|--------|---------|
| `AwardBonus.lua` | Direct stat manipulation: `gold()`, `Experience()`, `armor()`, `magicResist()`, `levels()`, `stats()`, `neutral()` |
| `Timers.lua` | `CreateTimer()` / `RemoveTimer()` wrappers around VScript Timers |
| `Utilities.lua` | Print helpers, `GetNumberOfHumans()`, `RegsiterGameStateListener()`, remap/clamp math |
| `Flags.lua` | Boolean initialization state flags |
| `Debug.lua` | Gated `Debug:Print()` |
| `Chat.lua` | HTTP client for AI chat backend |
| `SettingsDefault.lua` | Default Settings table with all keys |
| `SettingsNeutralItemTable.lua` | Neutral items by tier with metadata |
| `neutrals_data.lua` | Per-hero neutral item preferences (unused by active code) |
| `matchups_data.lua` | Hero matchup scores |
| `RoleUtility.lua` | Position → role mapping helpers |
| `Soundboard.lua` / `HeroSounds*.lua` / `Voiceover*.lua` | Voice line playback |
| `RadiantTowers.lua` / `DireTowers.lua` / `*Buildings.lua` | Entity lookup tables |
| `Inspect.lua` | Lua table serializer for debug |
| `HeroLoneDruid.lua` | Disabled — Lone Druid bear coordination (commented out) |
| `BuffUnit.lua` | Direct stat manipulation for testing |
| `GameState.lua` | State tracking helpers |
