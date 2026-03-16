# Mode System

## How Modes Work

Every `mode_*.lua` runs in bot script context. The Dota 2 engine calls `GetDesire()` on every mode every frame and activates the highest-scoring one. Each mode must export:

```lua
function GetDesire()    -- REQUIRED. Returns 0.0–1.0 float. Called every frame.
function Think()        -- Called every frame when this mode is active.
function OnStart()      -- Called once when mode activates. Optional.
function OnEnd()        -- Called once when mode deactivates. Optional.
```

---

## Mode Reference

### mode_laning_generic.lua — Early Game Lane Behavior

**Purpose:** Last-hitting, denying, lane positioning during early game.

**Desire curve:**
- `≤ 10s`: 0.268 (spawn walk-out)
- `≤ 9min AND level ≤ 7`: 0.446
- `≤ 12min AND level ≤ 11`: 0.369
- `level ≤ 14 AND core NW < 7000`: 0.2
- Otherwise: 0.01 (essentially off)
- **Override:** Last-hittable creep + pos 1–2 → 0.9

**Think priority:** last-hit enemy creep → deny allied creep → delegate to override → move to lane front.

**Turbo:** Time thresholds scaled by 1.65×.

**Override:** Heroes in `BuggyHeroesDueToValveTooLazy` use `FunLib/override_generic/mode_laning_generic.lua`, which reimplements lane assignment from OHA's position system rather than engine's `GetAssignedLane()`.

**Side effects:** `PickOneAnnouncer()` and `AnnounceMessages()` run every frame in `GetDesire()` during the first 60 game seconds.

---

### mode_retreat_generic.lua — Flee to Safety

**Purpose:** Most sophisticated mode. Decides when to flee based on HP/MP, enemy count, and modifier state.

**Hard exits:** Dead, invulnerability modifiers (Borrowed Time, Shallow Grave, False Promise, Satanic, etc.).

**Core desire formula:**
```
nDesire = 1 - ((nHealth + 1 - (1-nHealth)^4) / 2)
where nHealth = 0.8*HP + 0.2*MP (most heroes)
```

**Adjustments:**
- `+(enemyCount - allyCount) × 0.1875` per excess enemy
- `+0.25` if outnumbered and not stronger
- `-0.25` for False Promise / Shallow Grave / Satanic
- `-0.3` for Slark Shadow Dance

**Special cases:**
- Tower targeting early game → 0.9
- `ConsiderCompleteItem()` → `ABSOLUTE × 1.5` if recipe + components ready to assemble
- Wraith King doesn't retreat if reincarnation ready in team fight
- Medusa uses mana shield model (mana counts more)

**`buildContext()`** scans `GetUnitList(UNIT_LIST_ALL)` every frame to count allies, enemies, special units within range. Most expensive per-frame operation in the codebase.

**`ShouldRun()`** — 15+ specific scenarios: tower proximity, tower tier, night danger, Necrophos facing you, etc.

---

### mode_farm_generic.lua — Jungle and Lane Farming

**Purpose:** Mid/late game farming. Also contains "run mode" (push when massively ahead).

**CRITICAL BUG:** Both `GetDesire()` and `Think()` are misspelled as `GetDesie()` and `Thnk()`. The engine never calls these functions, so **farm mode never activates**. See `bugs-and-improvements.md`.

**Intended desire logic:**
- Run mode: `ABSOLUTE × 1.1` when `ShouldRun()` returns non-zero
- Lane creeps: `RemapValClamped(hp, 0.2, 0.7, 0.4, HIGH)`
- Jungle: `RemapValClamped(hp, 0.2, 0.7, 0.4, VERYHIGH)`
- Hard exclusions: laning phase, Roshan, Tormentor, team fight nearby, ally in fight, etc.

**Intended Think logic:**
- Run mode: Attack enemies/barracks if safe, otherwise retreat
- Lane farming: `J.Site.GetFarmLaneTarget()`, avoid tower aggro
- Camp farming: State machine (`farmState` 0/1), `J.Site.GetClosestNeutralSpwan()`, mobility ability usage

---

### mode_roam_generic.lua — Solo Ganking

**Purpose:** Roaming, ganking, hero-specific abilities (Spirit Breaker charge, Nyx Vendetta, etc.).

**Desire sources:**
- Tango use → ABSOLUTE
- Tinker base heal → ABSOLUTE
- Hero-specific roaming dispatch table
- General roaming conditions

**State management:**
- `laneToGank` held for 1.5 minutes
- `gankGapTime` = 6 minutes between trips (very infrequent)
- `arriveGankLocTime` — stays at gank location for 33 seconds

**Twin gate code:** Disabled (`enableGateUsage = false`), noted as "to be fixed."

---

### mode_team_roam_generic.lua — Team Fight Participation

**Purpose:** Team fight joining, item pickup (Aegis/Cheese), escort, special unit attacks.

Handles: idle detection, team fight location, item swaps (Smoke, Cheese, Clarity, Flask, Refresher Shard), dropped item pickup, hero-specific attack modes.

---

### mode_roshan_generic.lua — Roshan Coordination

**Purpose:** Coordinates Roshan killing when conditions are favorable.

**Key checks:**
- `J.HasEnoughDPSForRoshan()` before committing
- Roshan HP < 50% and no visible enemies → scales to ABSOLUTE
- Cores' backpacks must not be full (Aegis drop safety)
- Respects `J.IsRoshanCloseToChangingSides()` for pit position
- Human ping near Roshan → 0.95

**No Think():** Engine's default Roshan behavior handles actions. No hero-specific override path.

---

### mode_push_tower_top/mid/bot_generic.lua — Push Lanes

Three identical one-liner files delegating to `FunLib/aba_push.lua`:
```lua
function GetDesire() return Push.GetPushDesire(bot, LANE_X) end
function Think() Push.PushThink(bot, LANE_X) end
```

Cross-mode coordination via `bot.PushLaneDesire[lane]`.

---

### mode_defend_tower_top/mid/bot_generic.lua — Defend Towers

Three identical one-liner files delegating to `FunLib/aba_defend.lua`:
```lua
function GetDesire() return Defend.GetDefendDesire(bot, LANE_X) end
```

**Think() is commented out** — engine handles actual defense movement/attacking.

---

### mode_rune_generic.lua — Rune Collection

**Rune types handled:** Bounty, Power, Water, Wisdom.

**Wisdom Rune** (lines 73–114): At 7-minute multiples, assigns closest ally per rune spot. Tracks per-minute per-spot collection via `bot.wisdom[timeInMin][spot]`.

**Rune priority:**
- Pos 1 gets DD priority, Pos 2 gets Arcane priority
- Bottle carriers always count as close
- `GetScaledDesire(HIGH, dist, 3500)` — closer is higher desire

---

### mode_ward_generic.lua — Ward Placement

**Restricted to:** Pos 4–5 only.

**Logic:** Finds closest available ward spot from `W.GetAvailabeObserverWardSpots()`. Pre-game → ABSOLUTE. Otherwise VERYHIGH within 3200. Suppressed if enemy is closer to ward location and outnumbers allies.

---

### mode_side_shop_generic.lua — Tormentor Killing

**Misnomer:** Despite filename, handles Tormentor (side shops removed from Dota 2).

**Gating:**
- Average core level ≥ 13 AND average support level ≥ 11
- `X.IsGoodRightClickDamage()` → DPS ≥ 400 threshold
- Spawns at 20 min (10 turbo), respawns every 10 min (5 turbo)

**Team assembly:** Closest support scouts first, then team assembles. Human ping coordination supported.

---

### mode_outpost_generic.lua — Outpost Capture

**Requires:** Enemy T2 tower destroyed.
**Skips:** Invoker entirely.
**Desire:** `RemapValClamped(dist, 3000, 0, VERYLOW, HIGH)` — closer is higher.

---

### mode_secret_shop_generic.lua — Secret Shop Visits

Triggered by `bot.SecretShop` flag from `item_purchase_generic.lua`. Also handles selling early-game consumables when inventory is full.

---

### mode_assemble_with_humans_generic.lua — Stub

Always returns `BOT_MODE_DESIRE_NONE`. Real logic is in team_roam and engine defaults.

---

### mode_retreat_generic_wip.lua — WIP Alternative Retreat

Power-ratio-based retreat for buggy heroes. **Has no Think()** — heroes using this retreat but take no actions while retreating.

---

## Common Patterns Across Modes

### Entry Validation
```lua
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or bot:IsIllusion() then return end
```

### Desire Caching
```lua
J.Utils.GetCachedVars(key, ttlSeconds) / J.Utils.SetCachedVars(key, value)
```

### Common Suppressors
- Enemies near allied ancient
- Bot recently damaged and outmatched
- Team pushing highground/second tier
- Active retreat/Roshan/Tormentor mode
- Ally assembling at objective

### ShouldRun() Duplication
`ShouldRun()` is duplicated between `mode_retreat_generic.lua` (lines 491–735) and `mode_farm_generic.lua` (lines 856–1115). They differ slightly in early-game tower thresholds.
