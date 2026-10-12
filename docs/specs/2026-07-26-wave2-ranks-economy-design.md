# Dog Eat Dog — Wave 2 Design: Ranks + Economy

**Date:** 2026-07-26
**Status:** Approved pending user review
**Parent spec:** `2026-07-24-dog-eat-dog-design.md` (game design; wave order "rank ladder + economy" first)
**Repo:** `~/code/games/dog-eat-dog` (wave 1 merged: PR #1, main `869bf37`)

## Wave goal

Give the day loop its WHY: money, salary from performance, a 3-rank ladder with real floors, and a reachable retirement — the game becomes completable. Parent-spec economy section, thinned to what wave 1's skeleton supports.

## User decisions (locked at brainstorm)

| Decision | Pick |
|---|---|
| Wave scope | Ranks + economy (spec order); rep/social/variety = wave 3 |
| Completable | Yes — minimal retire flow, typewriter ending beat, no ending art variants |
| Rank ladder | Cap at rank 3 (Mailroom → Junior → Associate), performance-only per spec; Senior+ shown locked with "get to know your coworkers" tease |
| Powerups | Coffee only; energy drink + snack defer |
| Floors | Both — performance floor (warning → demotion) AND energy floor (sick day) |
| Money display | Numeric — "savings 1,240 / 20,000" poster + summary pay lines |
| Warning talk | Own beat before work (cute-sad boss typewriter), demotion at next summary if still low |
| Coffee crash | Flat energy debit after work — rest of day harder through the existing difficulty pipe |
| Sick day | Short interactive beat; **mash = recovery quality** (user idea evolved: "should sick days be a button mash and the quicker you do it the less days you have to miss?" → reframed to hold the 1-day fast-forgiveness rule: always exactly 1 day lost; dog burrows INTO the blanket, good mash = proper rest = bigger energy reset tomorrow, weak mash = groggy restart) |

## Core logic (new pure RefCounted scripts, `scripts/core/`)

- **`Wallet`** — `credit(amount)`, `spend(cost) -> bool` (refuses if insufficient — money never negative), `savings`, `can_retire(target)`. Int dollars throughout; no float money.
- **`RankLadder`** — rank indices 0–2 this wave (Mailroom/Junior/Associate); table structure extensible to 6.
  - **Promotion:** performance ≥ promote-threshold for N consecutive days → rank up (integer day counter — no float accumulators, wave-1 issue #1 class designed out).
  - **Warning → demotion:** performance < floor-threshold → `warning` state (telegraph); still below floor the next day → demote one rank + salary cut. Performance back above floor → warning clears. Floor = Mailroom, never fired.
- **`GameState`** += `money: int`, `rank: int`, `coffee_today: bool`. Existing `performance` EMA is the ladder's input — wave 1's work scores get their long-arc sink.
- **`StatEffects`** stays the sole day-boundary consumer: credits salary at summary (skipped on sick day), applies coffee crash debit post-work.
- **`Difficulty`** — coffee buff: +2 clarity tiers on typing params for the work block only. Crash: flat energy debit applied after work; "clarity below baseline" emerges from lower energy — no special-case clarity override.
- **`BalanceConfig`** carries ALL new tunables: salary per rank, promote/floor thresholds, sustain days, coffee price + buff tiers + crash debit, takeout price, retirement target, sick-day energy threshold + reset band (min/max mapped from mash score), warning copy timing.

## Day-flow integration (wave-1 skeleton unchanged; beats inserted)

1. **Wake scene:** savings poster line ("🦴 savings 1,240 / 20,000"). Savings ≥ target → retire choice card (Retire / One more day) after getting up — offered every morning, never auto-retires. Sick-day trigger (wake energy < sick threshold) → sick beat instead of normal day.
2. **Warning beat** (performance floor, telegraphed): cute-sad boss typewriter beat before work — carried into the typing block. Demotion lands at NEXT day's summary if performance still below floor.
3. **Coffee choice card** pre-work (Buy $X / Skip) — the only mid-day beat added. Buy → clarity buff for work, energy debit after.
4. **Sick day:** wake slot loads, reframed prompt — dog burrows into blanket. Mash score → energy reset size for tomorrow (band from BalanceConfig). Blanket-burrito typewriter beat, cut to summary: no pay, day counted. Always exactly 1 day. Telegraphed the prior evening (wobble line at sleep beat) — no surprise punishments.
5. **Summary additions:** pay line (+salary, −spends), promotion / demotion / warning-cleared beats (typewriter), day counter.
6. **Retire chosen → ending:** typewriter narration + run stats (days, final rank, savings), restart option. Ending art variants = later wave.
7. **Dinner:** takeout now actually costs money (wave-1 "costs money" was inert — money didn't exist).

## UI surfaces

Choice cards reuse `choice_card.gd` — zero new input verbs, zero new minigames. New/changed scenes: wake (poster line + retire card + sick variant), pre-work coffee card, summary lines, ending beat. All conversational copy through `TypewriterLabel` (repo rule).

## Testing

- Full TDD, 100% on pure logic: Wallet, RankLadder (promotion sustain, warning→demote→recover chain, salary cut), StatEffects extensions (salary credit, sick-day no-pay, coffee crash), Difficulty coffee buff, retire check, sick-mash → reset-band mapping.
- Plan-time boundary traces per games rule: promotion sustain counter and `savings >= target` are integer-exact by construction.
- Scene smoke tests for new/changed scenes.
- Day-flow integration test extended: earn → spend → promote → warning → demote → sick → retire paths.
- No coverage gate on visual scenes (domain rule, stated explicitly).
- Playtest gates as wave 1: lab presets for rank/warning/sick states + full-day rides. Playtest drives the FEATURE's semantics live (does demotion telegraph read fairly? does coffee crash feel like a borrow?).

## Invariants (bind code; add to repo CLAUDE.md at wave close)

- Money never negative — `spend` checks first, callers branch on the bool.
- Rank floor = Mailroom; no firing, no death anywhere in systems or copy (existing rule, extended to warning/demotion copy).
- Retire offer every morning once `savings >= target`; never auto-retire. Retire card precedes the sick-day branch — a sick morning at target still gets the offer (declining proceeds into the sick beat); sickness never blocks retirement.
- Sick day is always exactly 1 day; mash affects recovery quality only.
- Every consequence telegraphed one day ahead (warning beat before demotion; wobble line before sick day).
- All tunables in BalanceConfig; feel iteration edits data, not minigame code.
- Energy still never shown as a number; money IS numeric by design (user pick).

## Out of scope (wave 2)

Ranks 4–6 + rep gate, energy drink + comfort snack, event deck, meetings-as-listening, hobby gear, ending art variants, audio, wake/brush score sinks (issue #2 — rep wave), emoji art revisit (issue #9 — art wave).

## Open items for plan time

- Salary/threshold/price/target numbers: seed values authored in plan, tuned at playtest via BalanceConfig (parent-spec pace targets: aggressive ≈ 25–30 days, average ≈ 40, coasting ≈ 60+ — retuned for rank-3 salary cap).
- Warning/sick/ending copy drafts: plan-authored, user-gated at playtest (copy = value judgment; wave-1 issue #7 precedent).
