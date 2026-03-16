# Hero File Patterns (BotLib/hero_*.lua)

## Overview

127 hero config files in `BotLib/`, one per hero. All export a table `X` loaded via `dofile()` from `bot_generic.lua`. Files range from ~150 lines (minimal) to ~1,900 lines (Invoker). There is also `hero_lone_druid_bear.lua` — a separate bot file for the Spirit Bear unit.

---

## Canonical Template

Every hero file follows this top-to-bottom structure:

### 1. Module Header
```lua
local X = {}
local bot = GetBot()
local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Minion = dofile( GetScriptDirectory()..'/FunLib/aba_minion' )
local sTalentList = J.Skill.GetTalentList( bot )
local sAbilityList = J.Skill.GetAbilityList( bot )
local sRole = J.Item.GetRoleItemsBuyList( bot )
```

Complex heroes also pull in `Utils`:
```lua
local Utils = require( GetScriptDirectory()..'/FunLib/utils' )
```

Legacy debug flag (some older files): `local bDebugMode = ( 1 == 10 )` — always false.

### 2. Talent Tree
```lua
local tTalentTreeList = {
    ['t25'] = {10, 0},  -- 10 = prefer left, 0 = avoid right
    ['t20'] = {0, 10},
    ['t15'] = {10, 0},
    ['t10'] = {0, 10},
}
```

Some heroes define multiple talent tables in an outer array for role-based selection (Dragon Knight, Chen).

### 3. Ability Build
```lua
local tAllAbilityBuildList = {
    {1,2,1,3,1,6,2,2,2,1,6,3,3,3,6},  -- 15 entries: levels 1-15
}
```

Numbers 1–5 map to ability slots Q/W/E/D/F; 6 is ultimate. Multi-build heroes define multiple sub-tables. Invoker uses 21-entry builds (orb system). Build selection via `J.Skill.GetRandomBuild()` or deterministic role-gating.

### 4. Item Builds by Role
```lua
local sRoleItemsBuyList = {}
sRoleItemsBuyList['pos_1'] = { "item_tango", "item_power_treads", ... }
sRoleItemsBuyList['pos_5'] = { "item_blood_grenade", "item_mage_outfit", ... }
sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_1']  -- alias
```

**Aliasing:** Heroes that play one role alias all positions to one list (Anti-Mage aliases 2/3/4/5 to pos_1).

**Special variants:** Beyond `pos_1`–`pos_5`:
- Lone Druid: `pos_1_w_bear` vs `pos_1` (with/without bear build)
- Invoker: `pos_2_qe` vs `pos_2` (exort vs wex build)

Resolved via `Utils.GetLoneDruid(bot).roleType` or `Utils['GameStates']['invoker'].roleType`.

### 5. Export Table
```lua
X['sBuyList'] = sRoleItemsBuyList[sRole]
X['sSellList'] = { 'item_magic_wand', ... }

-- PvN mode override
if J.Role.IsPvNMode() or J.Role.IsAllShadow() then
    X['sBuyList'], X['sSellList'] = { 'PvN_heroname' }, {}
end

-- User customization
nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] =
    J.SetUserHeroInit( nAbilityBuildList, nTalentBuildList, X['sBuyList'], X['sSellList'] )

X['sSkillList'] = J.Skill.GetSkillList( sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList )
X['bDeafaultAbility'] = false  -- NOTE: "Deafault" is intentional typo, preserved for compat
X['bDeafaultItem'] = false     -- false = custom logic, true = engine default fallback
```

`PvN_heroname` is a key into a separate item preset system.

Crystal Maiden sets `bDeafaultAbility = true` and `bDeafaultItem = true` — engine default as fallback alongside custom logic.

### 6. MinionThink
```lua
function X.MinionThink(hMinionUnit)
    if Minion.IsValidUnit(hMinionUnit) then
        Minion.IllusionThink(hMinionUnit)
    end
end
```

Three patterns:

| Pattern | Example | Behavior |
|---------|---------|----------|
| Illusion-only | Anti-Mage | Validates illusion, delegates to `Minion.IllusionThink` |
| Generic minion | Chen, Lone Druid | Calls `Minion.MinionThink` for all summon types |
| Unit-name dispatch | Invoker | Checks unit name, runs custom logic (forged spirit), fallback to generic |

### 7. Ability Variables
```lua
local Blink = bot:GetAbilityByName('antimage_blink')
local ManaVoid = bot:GetAbilityByName('antimage_mana_void')
local BlinkDesire, BlinkLocation
local ManaVoidDesire, ManaVoidTarget
```

Module-level locals reused each frame. Some heroes re-fetch inside `SkillsComplement()` when abilities can change at runtime (Dragon Knight's Elder Dragon Form, Aghanim's upgrades).

### 8–9. SkillsComplement and ConsiderAbility Functions

See detailed patterns below.

### 10. Return
```lua
return X
```

---

## SkillsComplement() Patterns

### Standard Priority Chain (most heroes)

```lua
function X.SkillsComplement()
    if J.CanNotUseAbility(bot) then return end
    botTarget = J.GetProperTarget(bot)

    AbilityADesire, AbilityATarget = X.ConsiderAbilityA()
    if AbilityADesire > 0 then
        J.SetQueuePtToINT(bot, false)
        bot:ActionQueue_UseAbilityOnEntity(AbilityA, AbilityATarget)
        return
    end
    -- ... next ability ...
end
```

Priority is determined by ordering, not by comparing desire values.

### Combo-First Ordering (Anti-Mage)

`ConsiderBlinkVoid` checked before individual `ConsiderManaVoid` or `ConsiderBlink`. Queues both actions atomically.

### Pre-Processing Phase (Crystal Maiden)

`X.ConsiderCombo()` runs **before** the castability guard — applies Shadow Amulet/Glimmer Cape during Freezing Field channel using immediate (non-queued) actions.

### Timestamp Chaining (Invoker)

Tracks `AbilityCastedTimes` per ability. Chains follow-ups within time windows:
```lua
if DotaTime() - AbilityCastedTimes['Tornado'] <= 2 then
    -- Try EMP and ChaosMeteor
end
```

Additional Invoker complexity:
- `CastInvokerSpell` wraps every cast — checks if ability needs invoking first
- `ConsiderPreInvoke` manages orb configuration (EEE aggression, WWW chase, QQQ retreat)
- `ConsiderClearActions` monitors queue for stale/invalid actions

---

## ConsiderAbility() Patterns

### Early-Exit Guard
```lua
if not Ability:IsFullyCastable() then
    return BOT_ACTION_DESIRE_NONE, nil
end
```

### Scenario Block Structure (standard ordering)

1. **Kill confirm** — `J.WillKillTarget(target, damage, type, delay)`
2. **Team fight** — `J.IsInTeamFight(bot, 1200)`, 3+ heroes in proximity
3. **Offensive engagement** — `J.IsGoingOnSomeone(bot)`
4. **Defensive/retreating** — `J.IsRetreating(bot)`
5. **Laning phase** — early game utility
6. **Farming/pushing** — wave clear, tower siege
7. **Roshan/Tormentor** — objective utility
8. **Fallthrough** — `return BOT_ACTION_DESIRE_NONE`

### Desire Values (binary in practice)

Despite the system supporting fractional desires, nearly all Consider functions return either:
- `BOT_ACTION_DESIRE_NONE` (0)
- `BOT_ACTION_DESIRE_HIGH` (0.8)

Crystal Maiden's Q occasionally returns `BOT_ACTION_DESIRE_VERYHIGH` (0.9) when hitting 3+ enemies.

### Universal Safety Check
```lua
local nInRangeAlly = J.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
local nInRangeEnemy = J.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
if #nInRangeAlly >= #nInRangeEnemy then
    return BOT_ACTION_DESIRE_HIGH, target
end
```

Prevents suicidal dives — ally count must be ≥ enemy count around target.

### AOE Targeting
```lua
local nLocationAoE = bot:FindAoELocation(true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0)
if nLocationAoE.count >= 2 then
    return BOT_ACTION_DESIRE_HIGH, nLocationAoE.targetloc
end
```

### Location Prediction
```lua
J.GetCorrectLoc(target, castPoint)          -- J-library wrapper
botTarget:GetExtrapolatedLocation(delay)     -- engine API direct
```

### Mana Threshold Awareness
```lua
J.GetManaThreshold(bot, manaCost, abilityList)
```
Checks if casting current ability leaves enough mana for priority combo. More sophisticated than simple `nMP > 0.5` checks.

### Modifier Blacklist

Most casting conditions include standard guards:
```lua
not botTarget:HasModifier('modifier_abaddon_borrowed_time')
not botTarget:HasModifier('modifier_dazzle_shallow_grave')
```

Plus hero-specific modifiers that grow organically per file.

### Defensive Ability Pattern
```lua
J.IsUnitTargetProjectileIncoming(bot, 400)    -- projectile dodge
J.IsWillBeCastUnitTargetSpell(bot, 1400)       -- pre-emptive block
```

### Support Ally-Targeted Pattern
```lua
for _, allyHero in pairs(nearbyAllies) do
    if J.IsCore(allyHero) and J.IsGoingOnSomeone(allyHero) then
        return BOT_ACTION_DESIRE_HIGH, allyHero  -- buff core in combat
    end
end
```

---

## Complexity Tiers

| Tier | Lines | Abilities | Item Builds | MinionThink | External State | Examples |
|------|-------|-----------|-------------|-------------|----------------|---------|
| Simple | 150–300 | 3–4 | All alias to 1 | Illusion-only | None | Wraith King, Lone Druid |
| Standard | 400–700 | 4–6 | pos_3/4/5 distinct | Generic | None | Anti-Mage, Dragon Knight |
| Complex | 800–1900 | 8–12 + combos | Named variants | Unit dispatch | `Utils` shared tables | Crystal Maiden, Invoker |

---

## Notable Variations

### Anti-Mage (652 lines) — Canonical Carry
- Single build, all positions alias to pos_1
- `ConsiderBlinkVoid` combo: coordinates Blink + ManaVoid atomically
- Blink has multi-context logic: stuck escape, projectile dodge, farm, Roshan approach
- Large commented-out sections (abandoned push/defend logic)

### Crystal Maiden (1,034 lines) — Support Template
- `bDeafaultAbility = true`, `bDeafaultItem = true`
- Distinct pos_3/4/5 builds
- ConsiderCombo before castability guard
- Private helpers: `cm_GetWeakestUnit`, `cm_GetStrongestUnit`
- ConsiderQ: ~300 lines with Chinese comments, neutral creep targeting by name

### Invoker (~1,910 lines) — Most Complex
- Two complete role builds (`pos_2` and `pos_2_qe`)
- Invoke system: `CastInvokerSpell` wraps every cast
- Combo timestamp chaining (post-Tornado → EMP, post-Meteor → Blast)
- `ConsiderPreInvoke` manages orb config continuously
- `ConsiderClearActions` monitors queue for stale actions
- `CheckAbilityUsage` tracks cooldowns (can't use `IsFullyCastable()` reliably)

### Lone Druid (301 lines) — Multi-Bot Hero
- Companion `hero_lone_druid_bear.lua` runs as separate bot
- `Utils.GetLoneDruid(bot)` shared state between files
- Two builds: `pos_1` and `pos_1_w_bear`
- Currently always uses bear build (`RandomInt(1,5) >= 0` always true — dead code path)

### Dragon Knight (784 lines) — Form-State Hero
- Role-gated builds (pos_2 vs pos_3), no `GetRandomBuild`
- Re-fetches abilities each `SkillsComplement` (Aghanim's fireball)
- `bInDragonForm` checked in every Consider function (Dragon Tail range changes)
- `J.GetManaThreshold` for multi-ability mana planning

### Chen (604 lines) — Global Support
- Role-specific builds (pos_4 vs pos_5)
- `ConsiderHolyPersuasion`: priority list of neutral creep names
- `ConsiderHandOfGod`: scans entire ally list globally (global heal)
- `ConsiderDivineFavor`: `J.IsCore(allyHero)` to buff carries selectively
- No `J.WillKillTarget` — has no damaging spells

---

## Design Observations

1. **Desire values are binary in practice** — priority comes from ordering in `SkillsComplement()`, not comparing desire floats.

2. **Ally-count safety check is universal** — `#allies >= #enemies` around target before committing.

3. **Roshan/Tormentor blocks are copy-pasted templates** — standard endings in every Consider function with minor parameter adjustments.

4. **Comments mix Chinese and English** — original development in Chinese, newer additions in English.

5. **`J.SetQueuePtToINT(bot, false)` appears before every cast** — resets movement queue to prevent interference.

6. **Mode checks use both J-library and direct comparisons** — `J.IsGoingOnSomeone()` preferred, but `bot:GetActiveMode() == BOT_MODE_LANING` also used.
