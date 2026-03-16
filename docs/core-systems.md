# Core Systems

## bot_generic.lua (22 lines)

The thinnest possible entry point. Loaded once per bot hero at game start.

### Responsibilities
1. Load the hero config file (`BotLib/hero_<unitname>.lua`) via `dofile()`
2. Export `MinionThink()` for summon/illusion AI with 300ms throttle

### Control Flow
```
GetBot() at global scope
  → Guard: nil, invulnerable, not hero, illusion → return
  → require FunLib/utils
  → dofile BotLib/hero_<name>.lua → BotBuild table
  → Guard: BotBuild nil → print error, return
  → Define MinionThink(hMinionUnit) with 300ms DotaTime throttle
    → Delegates to BotBuild.MinionThink()
```

### Notes
- Uses `dofile()` (not `require()`) intentionally — executes fresh each time, returns the `X` table
- MinionThink throttle stores state directly on the unit handle (`hMinionUnit.lastMinionFrameProcessTime`)
- No `Think()` function — the engine dispatches to sibling files

---

## ability_item_usage_generic.lua (~8001 lines)

The largest file in the codebase. Handles ability leveling, item usage, buyback, courier management, and chat.

### Engine-Called Functions

| Function | Throttle | Delegates to |
|----------|---------|-------------|
| `AbilityLevelUpThink()` | 1s after t=30 | `AbilityLevelUpComplement()` |
| `AbilityUsageThink()` | `frameProcessTime × (1 + ThinkLess)` | `BotBuild.SkillsComplement()` |
| `ItemUsageThink()` | same as ability | `ItemUsageComplement()` |
| `BuybackUsageThink()` | 2s after t=30 | `BuybackUsageComplement()`, `UseGlyph()` |
| `CourierUsageThink()` | 0.5s after t=30 | `CourierUsageComplement()` |

### Ability Leveling (`AbilityLevelUpComplement`, lines 27–183)

Pops abilities from `sAbilityLevelUpList[1]`, calls `bot:ActionImmediate_LevelAbility()`.

Special cases:
- **Kez stance-switching** (lines 85–135): Maps ability names between katana/sai stances
- **Phoenix fire spirits** (lines 138–141): Skips if `phoenix_launch_fire_spirit` is visible
- **Alchemist unstable concoction** (lines 143–147): Same skip pattern
- **`generic_hidden` skills** (lines 158–162): Logs warning and advances queue
- **Post-level-25 fallback** (lines 180–182): Rebuilds list from talent tree if < 3 skills remain

At `DotaTime() < 15`, resolves the bot's role via `J.Role.GetCurrentSuitableRole()`.

### Item Usage (`ItemUsageComplement`, lines 809–870)

Core dispatch loop running every frame (throttled):

1. **Guard block** (lines 813–826): Returns if dead, muted, hexed, stunned, channeling, invulnerable, casting, teleporting, Doomed, or would break invis
2. **Cache** `hNearbyEnemyHeroList` (1000 range), `botTarget`, `nMode`, `aetherRange`
3. **Item scan loop** (lines 836–866): Iterates slots `{5, 4, 3, 2, 1, 0, 15, 16}` (reverse main + neutral)
   - Looks up handler in `X.ConsiderItemDesire[itemName]`
   - If desire > 0, calls `X.SetUseItem()` and returns

`X.ConsiderItemDesire` (line 970) is a dispatch table with ~80+ item handlers. Each returns `(desire, target, castType, motive)`.

### Buyback (`BuybackUsageComplement`, lines 379–452)

Decision tree:
- Ancient < 80% HP with enemies nearby and no allies → buyback immediately
- `nFullRespawnTime < 60` → skip
- Level > 24 and `nRemainingRespawnTime > 80` → buyback if team fight
- `nRemainingRespawnTime < 40` → skip
- Enemies near ancient >= ally count → buyback

### Courier State Machine (`CourierUsageComplement`, lines 460–600)

- Lazy-initializes `bot.theCourier` via `X.GetBotCourier()`
- If courier targeted → burst + return to stash
- If `bot.SShopUser` and conditions invalid → return courier
- If idle/returning/at base → dispatch stash items, secret shop, or transfer

### Glyph Usage (`UseGlyph()`, lines 7883–7951)

Only runs on player index 1. Iterates 11 towers + barracks + ancient. Activates glyph when:
- T1 tower under attack with creeps nearby
- T2/T3 tower under attack with bots defending
- Ancient under siege

---

## item_purchase_generic.lua (991 lines)

Manages the complete item purchasing lifecycle.

### Main Think Function (`ItemPurchaseThink`, line 402)

Sequence per tick (1s throttle after t=30):

1. **Clone guards** — Clear list for illusions, Arc Warden double, Meepo clones
2. **Dropped item recovery** — Iterate `GetDroppedItemList()`, pick up own items
3. **Lone Druid bear management** — Drop/pick up items between hero and bear
4. **Consumable purchases** (lines 507–706):
   - Clarity (low mana laning)
   - Dust (invis enemies, pos 4–5)
   - Observer wards (pos 5)
   - Sentry wards (pos 4)
   - Smoke (pos 5)
   - Blood grenade (supports)
   - Shard (savings reserve system)
   - TP scrolls (two purchase blocks)
5. **Raindrop management** — Swap to backpack near enemies
6. **Inventory sells** — At fountain/secret shop, sell early items when full
7. **Transitional item selling** — `SetPairedItems()`, sell Midas when NW > 23k
8. **Item queue progression** — Core purchase state machine

### Item Queue State Machine (lines 884–952)

```
purchaseListInReverseOrder (reversed sBuyList from hero config)
  → Pop last item
    → Item.GetBasicItems() decomposes into leaf components
      → _buildRequiredCounts() maps component → count needed
        → _stillNeeds() compares against _countOwnedEverywhere()
          → Buy one component per tick via ActionImmediate_PurchaseItem()
            → On failure: GetReducedPurchaseList() retries (up to 3×)
              → After 3 min with enough gold but unfinished: skip item
```

### Shard Savings Reserve (lines 249–258)

After 12 minutes (8 turbo), inflates the required gold threshold to save for Aghanim's Shard (1400g). The reserve scales linearly from 0 to 1400 over a 5-minute window. Elegant anti-impulse-buy mechanism.

### Buyback Reserve (lines 191–231)

At level 18+, adds `bot:GetBuybackCost() + bot:GetNetWorth() / 40 - 300` to the gold threshold. Encourages holding gold for buyback in late game.

---

## hero_selection.lua (1089 lines)

Runs during hero selection phase. Loaded once per team.

### Engine-Called Functions

| Function | Phase |
|----------|-------|
| `Think()` | Every frame during hero selection |
| `UpdateLaneAssignments()` | Pre-game/strategy time |
| `GetBotNames()` | Game start |
| `SelectHeroChatCallback()` | Chat during pick phase |

### Pick Flow

```
Think()
  ├── Captain's Mode → CaptainMode.CaptainModeLogic()
  ├── 1v1 Mid → OneVsOneLogic()
  └── All other modes:
      ├── Wait for GameTime() >= 1.0 and all humans ready
      ├── InitPickScheduleOnce() → stagger picks 1s apart + jitter
      └── AllPickHeros():
          ├── ShufflePickOrder() if all-bot team
          └── For each bot slot (one per frame):
              ├── PickHeroForBotSlot(i, id):
              │   ├── Start with preselect from sSelectList[i]
              │   ├── ScoreCandidatesForTeam() → matchup scoring
              │   ├── SelectTopWithFuzz() → top 3, weighted random
              │   └── WeakHeroCount tracking
              └── SelectHero(id, pick)
```

### Key Algorithms

**ScoreCandidatesForTeam()** (lines 586–615): For each candidate in the role pool, sums matchup scores against all known enemy heroes. Negates enemy advantage (Dotabuff convention). Multiplies by `WeakPenaltyFactor()`.

**WeakPenaltyFactor()** (lines 383–413): Three curves: linear, quadratic, exponential (default `0.6^weakPicked`).

**GetPositionedPool()** (lines 176–212): Builds role-specific pool from `HeroPositionMap`. Uses stochastic threshold (`RandomInt(5, ROLE_WEIGHT_THRESHOLD)`) so pool varies between games. If < 6 heroes, recursively expands. Caps at 35 heroes.

**Pick rotation weighting**: Reads `hero_pick_history.lua` (written by DotaRunner). Delta-based scoring: `delta=0 → +bonus`, `delta>0 → -(basePenalty + multiplier×delta)`.

### Chat Commands

- `!pick <hero>` — Force a bot to pick a specific hero
- `!pos <1-5>` — Assign a position to a player
- `!ban <hero>` — Ban a hero
- `!swap <hero>` — Swap to a hero (human players)
