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
| `just lab` | Open the dev lab — day presets and single-activity launchers |
| `just test` | Headless GUT unit tests |
| `just import` | Headless asset/scene reimport |
| `just cache` | Rebuild script-class cache (after new `class_name`) |
| `just export-web` | Export the web build to `build/web/` |
| `just serve` | Serve the web build on `:8060` |

Override the Godot binary with the `GODOT` env var.

## Web Export

One-time setup: install the 4.7.1 export templates (`Godot_v4.7.1-stable_export_templates.tpz` from the GitHub release) — extract the `templates/web_*` files to `%APPDATA%\Godot\export_templates\4.7.1.stable\`. The committed `export_presets.cfg` uses the nothreads template (`thread_support=false`), so the build runs without COOP/COEP headers. Then:

```sh
just export-web   # build/web/ (gitignored)
just serve        # http://localhost:8060
```

## The Morning Clock

Work starts at **8:00**. The dog wakes at 7:00, and everything from waking up to parking the car runs against that one stated deadline — the corner reads `7:42 · in by 8:00`. It ticks in real time while a morning slot is up and stops the moment the dog reaches the office; after that, time no longer matters.

Most of that hour is the commute. The five chores between the alarm and the car cost about ten minutes put together; the drive costs three times all of them combined, which is why traffic is the thing that makes you late.

The morning is meant to be a mad dash you can just barely make. A clean, fast one gets in early. One dawdle, one skipped chore, or a bad run of traffic does not.

The clock's colour is the warning: **calm → amber → red** as 8:00 closes in, so arriving late always begins from a visibly red clock. But red is a telegraph, not a promise — the traffic on any given morning is rolled fresh when the commute starts, and a bad roll can show you the red with nothing left to do about it. Some mornings you are late just because. Skipping a chore does not buy time back either: it costs a flat time penalty on top of its stat penalty, so ducking out is never a shortcut. However late the dog is, it is cashed out at the end of the commute — the dog slinks in and the day's performance takes a capped debit.

## Controls

| Slot | Input |
|---|---|
| Wake | Mash `Space` to fill the get-up bar (it decays) |
| Brush | Move the mouse back and forth to scrub; Skip button available |
| Shower | Circle the mouse around each stink spot until it's clean, then the next one appears; Skip button available — the stink follows you all day |
| Clothes | Drag each item onto the dog. Shoes bounce off until the pants are on; low energy means butterfingers, and a dropped item costs clock. **Mandatory — no skip** |
| Breakfast | Click **or** press `Space` as the marker crosses the plate; a better hit is a bigger energy refill |
| Drive | `A`/`D` (or `←`/`→`) to change lane across five lanes. Traffic comes in walls, usually with one lane open — but some walls block all five, and how fast the whole road is moving is rolled fresh each morning. A car ahead pins your speed until you weave around it. Walls shear apart as they roll, so a solid one always opens eventually; reading the stagger early is the skill. Miles-to-go and your speed read out beside the progress bar. **Nothing ever crashes** — bad driving costs time, not damage |
| Work (typing) | Phrases stream until the shift timer runs out; throughput against your rank's par is the score. Wrong chars insert and block until `Backspace`d, so a jam costs throughput |
| Lunch (listening) | Mouse gestures — nod (vertical strokes) / shake (horizontal strokes) on cue |
| Dinner | Click a choice card (cook / takeout) |
| Freetime | Mouse is captured and pulled toward "one more game" — hovering the game auto-plays it; deliberately click **Log off** to end the night |
| Sleep | No input — bedtime derives from how many games you played |
| Coffee cart | Click a choice card (buy / skip) — buy is disabled when you can't afford it |
| Retire offer | Choice card, first thing in the morning once savings hit the target — retire ends the run |
| Warning / rank news | No input — the cat's narration beat plays out (warning lands before work; rank news lands at the office right after afternoon work) |
| Sick day | Mash `Space` to burrow into the blanket — a sick morning replaces the whole day |

## Docs

Design specs and wave checklists live in the private planning-docs repo (`~/code/docs/games/dog-eat-dog/`).

## Status

| Wave | Scope | Status |
|---|---|---|
| 1 | Vertical slice — one playable day, placeholder art, web export | done |
| 2 | Ranks + economy — salary and living costs, rank ladder with warning-first demotion, coffee cart, sick days, retirement ending, energy carryover, lab day presets | done |
| 3a | Morning clock — the whole morning races a stated 8:00 arrival with a calm/amber/red HUD, shower / clothes / breakfast / five-lane commute minigames, traffic that rolls its own luck each morning, shift-timer work typing, lateness debit at the office | done |

## Credits

- Emoji glyphs: [Twemoji](https://github.com/twitter/twemoji) © Twitter, Inc and other contributors, licensed [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/); bundled as the [Twemoji Mozilla](https://github.com/mozilla/twemoji-colr) COLR font build (Apache-2.0).
