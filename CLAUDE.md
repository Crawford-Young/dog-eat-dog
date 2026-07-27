# CLAUDE.md — Dog Eat Dog

**Inherits:** `~/code/CLAUDE.md` + `~/code/games/CLAUDE.md`. Repo-specific rules only below.

## Repo Facts

- Godot binary comes from the `GODOT` env var; default in the Justfile points at the winget 4.7.1 console exe.
- After adding ANY `class_name` script: `just cache` before headless GUT (`--import` does not rebuild the class cache).
- After editing ANY `.tscn`/asset: `just import` before headless runs.
- Web export preset is committed (`export_presets.cfg`) — Web preset only, no secrets. `thread_support=false` is load-bearing (nothreads template = no COOP/COEP headers needed). `exclude_filter` keeps dev tooling (GUT addon, tests/, node_modules, package.json, .gutconfig.json, scenes/dev/, scripts/dev/) out of the pck — GUT scenes otherwise break the export with `Cannot set object script`; the lab shipped in wave-1 packs until the dev dirs were added (wave 2).
- `build/` carries a `.gdignore` (recreated by the `export-web` recipe — build/ is gitignored) so Godot never re-imports exported web icons as project resources.

## Game Rules That Bind Code

- **Energy is NEVER shown as a number** — the dog's sprite/state text IS the energy display.
- **No firing, no death** anywhere in systems or copy. Floor = demotion + sick day.
- Every minigame emits `finished(result)` with `{score: float 0..1, skipped: bool}`; choice scenes add `"choice": String`.
- **Bedtime is derived, never chosen** — `StatEffects.derive_bedtime(games_played)` maps the freetime loop's game count (0 / 1 / 2+) to early / mid / late. The sleep slot is a non-interactive narration beat, not a choice screen.
- Conversational copy types itself out — `Typewriter` (pure pacing) driven by a `TypewriterLabel` child node. Never set a bubble/prompt/summary `text` directly.
- All balance tunables live in `BalanceConfig` (`scripts/core/balance_config.gd` holds the defaults; `resources/balance_default.tres` carries overrides only and is currently zero-override) — feel iteration edits tunables, never minigame code.
- Difficulty flows ONLY through `Difficulty.*_params(energy, cfg)` — no minigame reads GameState directly.

### Wave-2 invariants (economy + ladder)

- **Money is never negative** — all spending goes through `Wallet.spend`/`Wallet.drain`, both clamp at 0. Living costs drain at `close_day` on BOTH branches (sick days pay nothing but still cost).
- **Retire precedes sick** — `DaySchedule.build` offers `retire_offer` before the sick short-circuit; a rich sick morning can still retire.
- **Sick day = exactly 1 day** — the schedule collapses to the sick beat; recovery is absolute (`sick_recovery_energy`), not blended.
- **Sick days never touch the rank ladder — by construction.** `RankLadder.evaluate` runs only after `work_pm` (game.gd), and a sick day has no work slots. `StatEffects.close_day` does NOT evaluate the ladder.
- **Rank news lands at the office** — a NarrationBeat right after afternoon work, same day. Never in the day-end summary (user ruling, issue #9).
- **Every ladder/sick consequence telegraphs one day ahead** — warning beat before any demotion, wobble line in the summary the evening before a sick-risk morning.
- **Energy carries over** — `start_next_day` blends leftover energy with the bedtime refill (`energy_carry_weight`); wrecked evenings produce wrecked mornings (user ruling, issue #5).

## Status

Wave 1 (vertical slice): DONE 2026-07-25 — one playable day (7 slots), 107 GUT tests, web export verified in-browser. Checklist archived at `~/code/docs/games/dog-eat-dog/checklists/done/dog-eat-dog-wave1.md`.
Wave 2 (ranks + economy): DONE 2026-07-27 — salary/living-cost economy, 4-rank ladder with warning-first demotion, coffee cart, sick days, retirement ending, energy carryover, lab day presets. 184 GUT tests. Checklist at `~/code/docs/games/dog-eat-dog/checklists/done/dog-eat-dog-wave2.md`.
Wave-3+ carried items: unconsumed wake/brush/lunch scores → rep/variety sink (D1), ranks 4–6 + senior tier, energy drink + snack, emoji art pass, CI workflow + dependabot housekeeping PR.
