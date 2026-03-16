# Expected Behavior Changes from Bug Fixes

Observable changes when play-testing after the bug fix commits. Ordered by expected visibility — most noticeable first.

---

## High Impact (will noticeably change gameplay)

### Farm Mode Now Works (Bug 1)
**Commit:** `3e06551`
**Before:** Bots never entered farm mode. After laning phase ended, bots had no jungle/lane farming behavior and relied entirely on push, defend, and team roam modes for gold.
**After:** Bots actively farm jungle camps and lane creeps during mid/late game when no higher-priority mode (retreat, push, team fight) is active. The "run mode" sub-behavior also activates — when massively ahead, bots aggressively push into the enemy base.
**How to observe:**
- Watch bot behavior after 12–15 minutes. Bots should move between jungle camps and clear lane waves instead of standing idle or grouping prematurely.
- When bots have a large gold/XP lead, they should activate "run mode" and push aggressively.
- Bot GPM should be noticeably higher in the mid game compared to before.

### DynamicDifficulty Now Works (Bugs 2, 3, 4)
**Commit:** `431bc5f`
**Before:** The entire DynamicDifficulty module silently errored on every bot death. GPM/XPM offsets were never adjusted. Bots that fell behind stayed behind.
**After:** When human players accumulate a kill advantage over bots, FretBots increases bot GPM/XPM offsets to help them catch up. When the advantage drops, offsets reset. This is the core adaptive scaling in FretBots.
**How to observe:**
- Play a game where you get several kills ahead of the bots early.
- Watch the FretBots console output — you should see messages like "Bots are behind! Human advantage: X kills. Adjusting Bot GPM Offset: Y".
- Bots should recover their net worth faster in games where humans have a kill lead.
- Use `/get gpm.offset` and `/get xpm.offset` chat commands to see current values change during the game.

### Pushing Bots No Longer Abandon Push to TP Home (Bug 8)
**Commit:** `9ad9017`
**Before:** The condition for "TP to fountain to complete items" was always true regardless of bot mode, so bots in push/attack mode would TP back to base mid-push to assemble items from stash.
**After:** Bots actively pushing a tower or attacking will stay on the push until the mode naturally changes.
**How to observe:**
- During a team push, bots should no longer randomly TP back to fountain.
- Pushes should feel more committed and sustained.

### Tormentor Location Fixed (Bug 20)
**Commit:** `d77cbc5`
**Before:** Bots selected which Tormentor to target based on time of day instead of team. ~50% of the time, bots pathed to their own side's Tormentor (wrong — you target the enemy-side Tormentor).
**After:** Radiant bots always go to the Dire-side Tormentor and vice versa.
**How to observe:**
- Watch bot Tormentor attempts. They should consistently path to the correct Tormentor on the enemy's side of the map.
- Previously you might have seen bots walking to their own jungle's Tormentor and standing around confused.

---

## Medium Impact (affects specific situations)

### Roam Gank Level Gating Works (Global Leak Fixes)
**Commit:** `e1cd7ee`
**Before:** `botLevel` was undefined (nil), causing a runtime error when compared to a number. The level check was silently skipped, so low-level bots attempted ganks they couldn't execute.
**After:** Pos 1–2 bots won't attempt ganks until level 6. Pos 3 needs level 5. Pos 4–5 need level 4.
**How to observe:**
- In the first few minutes, supports (pos 4–5) should stay in lane until level 4 instead of roaming at level 1–2.
- Cores should not attempt roaming ganks before level 6.

### Defensive Items Fire When Outnumbered (Global Leak Fixes)
**Commit:** `e1cd7ee`
**Before:** `nAllyHeroes` was nil in the Manta/BKB-style item handler, so the outnumber check (`#nInRangeEnemy > #nAllyHeroes`) could never be true. Bots never used certain defensive items when outnumbered at low HP.
**After:** Bots use BKB-like items (specifically the item handler around line 7798) when they're outnumbered and below 60% HP with enemies within 1200 range.
**How to observe:**
- Watch for bots popping BKB or similar items when ganked by multiple heroes. This should happen more reliably now.

### TP-Before-Death Gold Preservation (Bug 7)
**Commit:** `57fb533`
**Before:** The "buy TP when about to die" logic had an impossible condition (`HP < 8%` AND `HP >= 100%`) so it never fired.
**After:** When a bot is below 8% HP, was recently damaged by a hero, has unreliable gold at risk, and doesn't have a TP, it will buy one to reduce gold loss on death.
**How to observe:**
- Bots about to die may purchase a TP scroll in their final moments. This is a gold-preservation micro-optimization, most visible in close games where every 100g matters.

### Gleipnir (Gungir) Targets Correctly (Global Leak Fixes)
**Commit:** `e1cd7ee`
**Before:** `hEffectTarget` in the Gleipnir handler was a stale global from a previous item handler call. The item could target the wrong unit or a unit from a different context.
**After:** Gleipnir correctly targets the enemy hero it's trying to reveal/root when stopping an invisible hero.
**How to observe:**
- Watch bots use Gleipnir against invisible heroes. It should consistently target the correct enemy.

### Zero-Regen Hero Scaling Fixed (Bug 12)
**Commit:** `70b24c4`
**Before:** Heroes with 0 base HP/mana regen (early game Terrorblade, Phantom Lancer, etc.) got a divide-by-zero that clamped to the maximum multiplier (6× HP regen, 10× mana regen).
**After:** These heroes get a moderate boost based on a floor of 0.1 base regen instead of an extreme multiplier.
**How to observe:**
- At higher FretBots difficulty levels, heroes like Terrorblade should no longer have absurdly high early-game regen compared to other bots.

---

## Low Impact (subtle or rare)

### Hero Pick Variety Restored (Bug 14)
**Commit:** `0ea718e`
**Before:** Matchup scoring ran 100% of the time. Every bot pick was optimized against the enemy draft.
**After:** 20% of bot picks use a random hero from the role pool instead of matchup scoring.
**How to observe:**
- Over many games, bot drafts should be less repetitive. Occasionally you'll see a "suboptimal" pick that adds variety.
- The 80/20 split means most picks are still matchup-aware.

### Hero Pool Recursion Safety (Bug 15)
**Commit:** `e1c10fc`
**Before:** If a position's hero pool had fewer than 6 candidates, the pool-building function recursed infinitely (theoretical stack overflow).
**After:** Retries up to 3 times, then returns whatever heroes were found.
**How to observe:**
- Unlikely to observe directly. Prevents a potential crash when the hero pool is heavily filtered (many bans + weak hero restrictions + position filters).

### Debug Logging Disabled (Bug 5)
**Commit:** `70d3fbb`
**Before:** Every item usage triggered debug logging via `J.SetReportMotive()`.
**After:** No debug output during normal play.
**How to observe:**
- Less console spam. Slightly better performance from skipping string formatting every frame.

### Outpost Mode Cleanup (Bug 11)
**Commit:** `8b33466`
**Before:** When outpost mode deactivated, it set an undefined global `ShouldWaitInBaseToHeal`.
**After:** Clean deactivation with no global leak.
**How to observe:**
- No visible gameplay change. Eliminates a potential interference if any other file happened to read a global named `ShouldWaitInBaseToHeal`.

---

## Test Checklist

Priority order for play-testing:

- [ ] **Farm mode**: Start a bot game, wait past 12 minutes, observe if bots farm jungle camps
- [ ] **Push commitment**: During a team push at a tower, verify bots don't TP back to base
- [ ] **Tormentor pathing**: Trigger a Tormentor attempt (past 20 min, sufficient levels), verify bots go to the correct side
- [ ] **DynamicDifficulty**: Get 5+ kills ahead, check if `/get gpm.offset` shows increased values
- [ ] **Roam gating**: Watch pos 4–5 bots in the first 4 minutes — they should lane, not roam
- [ ] **Pick variety**: Play 5+ games, note if bot hero picks vary more than before
- [ ] **Regen balance**: At difficulty 7+, check Terrorblade/PL early regen isn't absurdly high
