# Bugs and Improvement Opportunities

## Critical Bugs

### 1. Farm Mode Never Activates (`mode_farm_generic.lua`)
**Lines:** 55, 425
**Issue:** Both `GetDesire()` and `Think()` are misspelled as `GetDesie()` and `Thnk()`. The engine calls `GetDesire()` and `Think()`, so farm mode never competes for activation and never acts.
**Impact:** Bots cannot farm jungle or lane waves via this mode. Mid/late game farming behavior is absent. The "run mode" (push when ahead) also never activates.
**Fix:** Rename `GetDesie` → `GetDesire` and `Thnk` → `Think`.

### 2. DynamicDifficulty victim Not in Scope (`FretBots/DynamicDifficulty.lua`)
**Line:** 60
**Issue:** `MakeAdjustment()` references `victim` which is a parameter of `Adjust()`, not passed to `MakeAdjustment()`. The variable is nil inside `MakeAdjustment()`.
**Impact:** Dynamic difficulty adjustment silently errors on every bot death. GPM/XPM offsets are never adjusted.
**Fix:** Pass `victim` as parameter to `MakeAdjustment()`.

### 3. DynamicDifficulty Cache Shadowing (`FretBots/DynamicDifficulty.lua`)
**Lines:** 29–31
**Issue:** `local cache = {}` inside the module shadows module scope. The cache is empty when `Reset()` tries to copy from it via `Utilities:DeepCopy(cache.gpm, Settings.gpm)`.
**Impact:** `DynamicDifficulty:Reset()` copies nil values, meaning settings are never restored after suspension.
**Fix:** Populate `cache` during `Initialize()` or ensure the outer module-level `cache` is used.

### 4. DynamicDifficulty Operator Precedence (`FretBots/DynamicDifficulty.lua`)
**Lines:** 43–54
**Issue:** `if knob == 'xpm' or knob == 'gpm' and Settings.dynamicDifficulty[knob].enabled` evaluates as `knob == 'xpm' or (knob == 'gpm' and ...)` due to Lua `and` binding tighter than `or`. The xpm branch runs unconditionally.
**Impact:** XPM adjustments apply even when disabled in settings.
**Fix:** Add parentheses: `(knob == 'xpm' or knob == 'gpm') and ...`

---

## Significant Bugs

### 5. Debug Mode Always On (`ability_item_usage_generic.lua`)
**Line:** 8
**Issue:** `bDebugMode = (10 == 10)` evaluates to `true`. Every frame an item is used, debug output triggers via `J.SetReportMotive()`.
**Impact:** Performance drag from debug logging in production. Possible console spam.
**Fix:** Change to `local bDebugMode = false`.

### 6. ~~Double TP Purchase~~ (`item_purchase_generic.lua`) — INTENTIONAL
**Lines:** 749–753
**Status:** Not a bug. When `botGold >= tpCost * 2` and late game (>25 min), the bot intentionally buys 2 TPs (a spare for late game). The outer condition `tCharges <= 0 or (level >= 18 and tCharges <= 1)` gates this correctly.

### 7. Impossible TP Guard (`item_purchase_generic.lua`)
**Lines:** 726–736
**Issue:** Requires `botHP < 0.08` AND `botHP >= 1` simultaneously. Since `J.GetHP()` returns 0.0–1.0, these are mutually exclusive.
**Impact:** "Buy TP before death" logic never executes.
**Fix:** Remove the `>= 1` condition (the alive check already exists above).

### 8. TP Push-Mode Condition (`ability_item_usage_generic.lua`)
**Line:** 4731
**Issue:** `(bot:GetActiveMode() ~= BOT_MODE_PUSH_TOWER_TOP or bot:GetActiveMode() ~= BOT_MODE_PUSH_TOWER_MID or ...)` is always true (mode can't equal two constants simultaneously).
**Impact:** Pushing bots incorrectly TP back instead of continuing their push.
**Fix:** Change `or` to `and`.

### 9. Global Variable Leak (`ability_item_usage_generic.lua`)
**Line:** 4708
**Issue:** `hEffectTarget, shouldTp = X.GetLaningTPLocation(...)` — `shouldTp` assigned without `local`, leaking to global scope.
**Fix:** Add `local`.

### 10. Retreat WIP Has No Think (`mode_retreat_generic_wip.lua`)
**Issue:** Active for buggy heroes but defines no `Think()`. Heroes enter retreat mode but take no actions.
**Impact:** Buggy heroes stand still when retreating.
**Fix:** Implement `Think()` or fall back to the main retreat mode.

### 11. Outpost OnEnd Nil Reference (`mode_outpost_generic.lua`)
**Line:** 100
**Issue:** `OnEnd()` references `ShouldWaitInBaseToHeal` which is never defined.
**Impact:** Nil error whenever outpost mode deactivates.
**Fix:** Remove the reference or define the variable.

### 12. BonusTimers Division by Zero (`FretBots/BonusTimers.lua`)
**Lines:** 455–459
**Issue:** `bot:GetBaseHealthRegen() * RemapValClamped(difficultyScale / regen, ...)` — if base regen is 0, divides by zero producing `math.huge`, clamped to 6× multiplier.
**Impact:** Some heroes (Terrorblade, Phantom Lancer early) get extreme regen values.
**Fix:** Guard with `math.max(regen, 0.1)` or skip when regen is 0.

### 13. RoleDetermination Duplicate Case (`FretBots/RoleDetermination.lua`)
**Lines:** 183–197
**Issue:** Two "dual mid, solo off" cases have identical conditions (`safe==2 and mid==2 and off==1`). Second branch is unreachable.
**Fix:** Differentiate conditions or remove dead branch.

### 14. Hero Selection RandomInt Always True (`hero_selection.lua`)
**Line:** 643
**Issue:** `RandomInt(1, 5) >= 1` is always true. Matchup scoring runs 100% of the time instead of the intended ~80%.
**Fix:** Change to `RandomInt(1, 5) >= 2` (or whatever the intended probability was).

### 15. GetPositionedPool Unbounded Recursion (`hero_selection.lua`)
**Lines:** 207–210
**Issue:** When `#sortedHeroNames < 6`, calls itself recursively with the same stochastic threshold. No depth limit.
**Impact:** For positions with few qualified heroes, could theoretically stack overflow.
**Fix:** Add depth parameter, return whatever is available at depth ≥ 3.

### 16. Lone Druid Dead Code Path (`BotLib/hero_lone_druid.lua`)
**Line:** 106
**Issue:** `RandomInt(1,5) >= 0` always true — the non-bear build path is dead code.
**Fix:** Remove the dead branch or fix the condition.

### 17. Push Mode Shared State Across All Bots (`FunLib/aba_push.lua`)
**Lines:** 690–691
**Issue:** `lastAction`, `lastThinkTime`, and `fNextMovementTime` are module-level variables shared across all 5 bots. Bot A's last action can be replayed by Bot B.
**Impact:** Push behavior is contaminated between bots — one bot's throttle affects all others.
**Fix:** Convert to per-bot storage keyed on `bot:GetPlayerID()`.

### 18. Push Mode Wrong Enemy Fountain (`FunLib/aba_push.lua`)
**Line:** 95
**Issue:** `locationStateCache.enemyFountain = jmz.GetTeamFountain()` — uses ally fountain for both `teamFountain` and `enemyFountain`.
**Impact:** Any code checking distance to enemy fountain gets the wrong location.
**Fix:** Use `jmz.GetEnemyFountain()` (or equivalent).

### 19. ~~Kill Count Logic Inverted~~ (`FunLib/jmz_func.lua`) — FALSE POSITIVE
**Line:** 4143–4147
**Status:** Not a bug. The function counts deaths (not kills) on a team, so `bEnemy=true` → counts ally deaths → equals enemy kills. Callers (`mode_farm_generic.lua:279-280`) use it correctly. The naming is confusing but the logic is correct.

### 20. Tormentor Location Ignores Team (`FunLib/jmz_func.lua`)
**Line:** 5813
**Issue:** `GetTormentorLocation(team)` accepts a `team` parameter but ignores it. Returns location based on time of day instead of team.
**Impact:** Bots may path to the wrong Tormentor.
**Fix:** Use the `team` parameter to select the correct location.

### 21. ~~IsTargetedByEnemyWithModifier Uses Wrong Bot~~ (`FunLib/jmz_func.lua`) — FALSE POSITIVE
**Line:** 1283
**Status:** Not a bug. In Dota 2 bot scripting, `require()` is per-bot (each bot runs in its own Lua state). The module-level `bot = GetBot()` correctly refers to the current bot in each state. The `bot` upvalue is the correct reference.

---

## Minor Issues

### 22. Veil Motive String Copy-Paste Error (`ability_item_usage_generic.lua`)
**Line:** 5539
**Issue:** `item_veil_of_discord` handler says `"启动希瓦"` ("activate Shiva") — wrong item name.
**Fix:** Change to `"启动纷争面纱"` or equivalent.

### 23. Courier Loop Iterates Wrong IDs (`ability_item_usage_generic.lua`)
**Line:** 607
**Issue:** `GetCourier(nCourierID)` for IDs 0–4 may hit couriers of other teams. Functionally safe (PlayerID check), but wasteful.

### 24. `_countOwnedEverywhere` Missing Stash/Courier (`item_purchase_generic.lua`)
**Lines:** 81–89
**Issue:** Doesn't check stash (slots 9–14) or courier. May cause re-purchasing components already in stash.
**Fix:** Add stash slot scan.

### 25. Dead `buyRD` Code (`item_purchase_generic.lua`)
**Lines:** 718–722
**Issue:** `buyRD` set when `currentTime < 0` (only pre-game countdown, before the throttle check lets code run). Never used.
**Fix:** Remove dead code.

### 26. Duplicate `bot.lastItemToBuy` Assignment (`item_purchase_generic.lua`)
**Lines:** 337, 343
**Issue:** Same variable assigned twice in same block. Copy-paste artifact.
**Fix:** Remove duplicate.

### 27. Announcer Side Effects in GetDesire (`mode_laning_generic.lua`)
**Issue:** `PickOneAnnouncer()` and `AnnounceMessages()` run every frame inside `GetDesire()` for first 60 game seconds. Side effects in a pure-query function.

### 28. ShouldRun Duplication (`mode_retreat_generic.lua` + `mode_farm_generic.lua`)
**Issue:** `ShouldRun()` duplicated between files (~250 lines each), differing only in early-game tower thresholds.
**Fix:** Extract to shared utility.

### 29. buildContext Per-Frame Full Unit Scan (`mode_retreat_generic.lua`)
**Lines:** 44–116
**Issue:** `GetUnitList(UNIT_LIST_ALL)` called every frame retreat is evaluating. Most expensive possible query.
**Fix:** Cache with TTL (0.5–1.0 seconds).

### 30. Wisdom Rune O(n²) Synchronization (`mode_rune_generic.lua`)
**Issue:** `bot.wisdom` table synchronized across teammates by copying every frame during rune mode.
**Fix:** Use shared table or reduce sync frequency.

### 31. Tormentor DPS Never Decreases (`mode_side_shop_generic.lua`)
**Line:** 446
**Issue:** `tTeamDamage` tracks maximum-ever DPS per bot. If a bot sells items, stale max still passes threshold.
**Fix:** Recalculate from current stats.

### 32. `WillBreakInvisible` Self-Shadowing (`ability_item_usage_generic.lua`)
**Line:** 954
**Issue:** `local botName = botName` re-declares upvalue as local of itself. No-op but confusing.

### 33. handleCommand Double Parse (`hero_selection.lua`)
**Lines:** 718–732
**Issue:** `parseCommand()` called first (unused by dispatch), then `gmatch("[^;]+")` re-parses.
**Fix:** Remove unused first parse.

### 34. Ward Spots Silently Dropped (`FunLib/aba_ward_utility.lua`)
**Lines:** 210, 245, 285
**Issue:** Duplicate table keys (e.g., `[4]` in `TOWER_MID_1` for Dire) — Lua silently overwrites the first entry.
**Impact:** Ward spots are lost, reducing ward placement options.
**Fix:** Renumber duplicate keys.

### 35. Ward Lifespan Check Wrong String (`FunLib/aba_ward_utility.lua`)
**Line:** 664
**Issue:** `IsOtherWardClose` compares `sWardName` against `'item_ward_observer'` but callers pass unit names like `'npc_dota_observer_wards'`. Lifespan check never triggers.
**Fix:** Compare against the correct unit name string.

### 36. Chat GetLocalName Returns Raw Name (`FunLib/aba_chat.lua`)
**Issue:** Returns `tBotName[sRawLanguage]` where `sRawLanguage = 'sRawName'` — always returns the internal name, not localized.
**Fix:** Use locale-appropriate field (`sEnName` or `sCnName`).

### 37. Chat GetCheaterReplyString Triggers on All Commands (`FunLib/aba_chat.lua`)
**Line:** 540
**Issue:** Returns `"cheater"` for any message starting with `-`, causing bots to say "cheater" for normal `-commands`.
**Fix:** Return `nil` or check against a cheat command list.

### 38. InvisEnemyExist Never Resets (`FunLib/aba_role.lua`)
**Line:** 125
**Issue:** Once set to `true`, `invisEnemyExist` never resets. If the invis hero leaves the game, flag stays true permanently.
**Impact:** Bots waste gold on dust purchases indefinitely.
**Fix:** Add periodic reset or check if invis hero is still in game.

### 39. Team Snapshots Never Updated (`FunLib/jmz_func.lua`)
**Lines:** 4–27
**Issue:** `tAllyHeroList`, `tAllyHumanList` populated once at module require time. Never updated after disconnects/reconnects.
**Fix:** Refresh periodically or on player state change.

### 40. Proximity Query Caching Disabled (`FunLib/jmz_func.lua`)
**Lines:** 475–478, 498–500, etc.
**Issue:** All caching logic in core proximity functions is commented out. Every call iterates full unit lists.
**Impact:** Single largest performance concern in the codebase.
**Fix:** Re-enable caching with appropriate TTLs, or delegate to `global_cache.lua`.

### 41. Settings SetValue Depth Limit (`FretBots/Settings.lua`)
**Lines:** 1034–1061
**Issue:** Hardcoded depth up to 6 levels for dotted-path keys. Exceeding 6 silently fails.

### 42. FretBots Failsafe Timer Too Short (`FretBots.lua`)
**Line:** 53
**Issue:** `playerLoadFailSafeDelta = 3` — proceeds after 3 seconds even if heroes haven't spawned, potentially with incomplete DataTables.

### 43. NeutralItemFindTimer Dead Code (`FretBots/BonusTimers.lua`)
**Lines:** 212–327
**Issue:** `NeutralItemFindTimer___` (triple underscore) — entire matchup-based neutral award path is dead code.
**Fix:** Remove.

---

## Improvement Opportunities

### Architecture

1. **Extract ShouldRun()** to a shared utility in `FunLib/` — eliminate 250-line duplication between retreat and farm modes.

2. **Centralize proximity queries** in `ItemUsageComplement()` — pass pre-computed `hNearbyEnemyHeroList` to item handlers instead of each handler re-querying with its own radius.

3. **Cache buildContext()** in retreat mode — use a 0.5s TTL cache instead of scanning `UNIT_LIST_ALL` every frame.

4. **Add TTL caching to wisdom rune sync** — reduce O(n²) per-frame synchronization.

### Code Quality

5. **Fix all function name typos** — `GetDesie` → `GetDesire`, `Thnk` → `Think`, `bDeafaultAbility` (preserve for compat but document).

6. **Remove dead code** — `buyRD`, `NeutralItemFindTimer___`, Lone Druid non-bear path, commented-out Anti-Mage push/defend logic.

7. **Standardize language** — Pick Chinese or English for comments/motives. The codebase currently mixes both.

8. **Add proper debug flag** — Replace `bDebugMode = (10 == 10)` with a `Customize/general.lua` setting.

### Reliability

9. **Fix DynamicDifficulty** — Three separate bugs (victim scope, cache shadowing, operator precedence) make the entire module non-functional.

10. **Fix FretBots failsafe** — Increase from 3 to 10+ seconds or use hero-spawn-count gating instead of a fixed timer.

11. **Guard division by zero** in BonusTimers regen scaling.

12. **Add recursion depth limit** to `GetPositionedPool()`.

### Performance

13. **Reduce per-frame API calls** — `GetUnitList(UNIT_LIST_ALL)` in retreat, per-item `GetNearbyHeroes()` in ability file, `IsCourierTargetedByUnit()` scanning all unit lists every 0.5s per bot.

14. **Use ThinkLess more aggressively** — The throttle system exists but some modes bypass it (laning, retreat).

### Data Quality

15. **Update aba_matchups.lua** — 82KB of matchup data with no version tag. No automated update path when meta shifts.
16. **Complete aba_buff.lua modifier lists** — Missing `modifier_juggernaut_omnislash_invulnerability` from `enemy_is_immune`, and `modifier_legion_commander_duel`.
17. **Complete aba_skill.lua ability indices** — `sAllyUnitAbilityIndex` missing many support abilities (oracle, abaddon).
18. **Fix aba_item.lua sSellList structure** — Flat alternating array is fragile. Convert to `{sell=, replace=}` objects.
19. **Deduplicate aba_item.lua sSeniorItems** — `item_rod_of_atos` appears twice.
20. **Update aba_chat.lua hero names** — Missing some newer heroes in `tHeroNameList`.
