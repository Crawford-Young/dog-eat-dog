# CLAUDE.md — Dog Eat Dog

**Inherits:** `~/code/CLAUDE.md` + `~/code/games/CLAUDE.md`. Repo-specific rules only below.

## Repo Facts

- Godot binary comes from the `GODOT` env var; default in the Justfile points at the winget 4.7.1 console exe.
- After adding ANY `class_name` script: `just cache` before headless GUT (`--import` does not rebuild the class cache).
- After editing ANY `.tscn`/asset: `just import` before headless runs.
- Web export preset is committed (`export_presets.cfg`) — Web preset only, no secrets. `thread_support=false` is load-bearing (nothreads template = no COOP/COEP headers needed).

## Game Rules That Bind Code

- **Energy is NEVER shown as a number** — the dog's sprite/state text IS the energy display.
- **No firing, no death** anywhere in systems or copy. Floor = demotion + sick day.
- Every minigame emits `finished(result)` with `{score: float 0..1, skipped: bool}`; choice scenes add `"choice": String`.
- **Bedtime is derived, never chosen** — `StatEffects.derive_bedtime(games_played)` maps the freetime loop's game count (0 / 1 / 2+) to early / mid / late. The sleep slot is a non-interactive narration beat, not a choice screen.
- Conversational copy types itself out — `Typewriter` (pure pacing) driven by a `TypewriterLabel` child node. Never set a bubble/prompt/summary `text` directly.
- All balance tunables live in `BalanceConfig` (`scripts/core/balance_config.gd` holds the defaults; `resources/balance_default.tres` carries overrides only and is currently zero-override) — feel iteration edits tunables, never minigame code.
- Difficulty flows ONLY through `Difficulty.*_params(energy, cfg)` — no minigame reads GameState directly.

## Status

Wave 1 (vertical slice): in progress — checklist at `~/code/docs/games/dog-eat-dog/checklists/active/dog-eat-dog-wave1.md`.
