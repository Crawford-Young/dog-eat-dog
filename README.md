# Dog Eat Dog

A cute chibi dog climbs the corporate ladder in a pastel all-animal office. The world says it's dog-eat-dog; the truth is everyone wants to help you — if you take care of yourself and show up for others. Every daily task is a tactile minigame whose difficulty reflects your self-care. Retire when your savings hit the target. You are never fired and never die — the worst case is the mailroom and a sick day.

## Stack

| Concern | Tool |
|---|---|
| Engine | Godot 4.7.1 |
| Language | GDScript |
| Testing | GUT 9.7.1 (headless) |
| Task runner | Just |
| Commits | Conventional Commits (commitlint + husky) |

## Commands

| Command | What |
|---|---|
| `just run` | Run the game |
| `just edit` | Open the Godot editor |
| `just test` | Headless GUT unit tests |
| `just import` | Headless asset/scene reimport |
| `just cache` | Rebuild script-class cache (after new `class_name`) |
| `just export-web` | Export the web build to `build/web/` |
| `just serve` | Serve the web build on `:8060` |

Override the Godot binary with the `GODOT` env var.

## Docs

Design specs and wave checklists live in the private planning-docs repo (`~/code/docs/games/dog-eat-dog/`).

## Status

| Wave | Scope | Status |
|---|---|---|
| 1 | Vertical slice — one playable day, placeholder art, web export | in progress |

## Credits

- Emoji glyphs: [Twemoji](https://github.com/twitter/twemoji) © Twitter, Inc and other contributors, licensed [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/); bundled as the [Twemoji Mozilla](https://github.com/mozilla/twemoji-colr) COLR font build (Apache-2.0).
