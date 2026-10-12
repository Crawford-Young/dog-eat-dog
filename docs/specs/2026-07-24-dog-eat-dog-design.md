# Dog Eat Dog — Game Design Spec

**Date:** 2026-07-24
**Status:** Approved pending user review
**Working title:** "Dog Eat Dog" (placeholder — final title gets its own user gate during the art/branding wave)
**Domain:** games (Godot 4, GDScript, GUT)
**Repo (planned):** `~/code/games/dog-eat-dog`

## Original pitch (user's words)

> "really cool game idea i had. its about getting stuck in a toxic day to day life with a reference and challenge to the idea of the dog eat dog world or the rat race we can decide later. basically its a button mashing/typing game where you have to button mash to get out of bed in the morning. swipe your mouse back and forth to brush your teeth. etc. but the worse you take care of yourself the harder these things get especially with work. work is going to your desk and typing in stuff. if you havent taken care of yourself your work will just be random letters but if you are in a healthy state it might be something short and easy to type in. i want this to be a super cute indie game so this might take a lot of chatgpt generation"

Key intent refinements from brainstorming:

- "the goal is that work isnt bad its just that you need to take care of yourself to apply yourself and feel pride in how good you do"
- Climb company ranks on performance; retire when savings hit a target. "having a no retirement you just die ending would be too much for this cute indie game."
- Coworker relationships: "goes to show that it isnt dog eat dog or rat race because people want to help you if you build those relationships"
- No firing, ever. Floor is demotion + sick days.
- Lunch listening idea: "you cant speak in the game other than the typing for work so at lunch you have to time your nods and shaking your head to the person talking to you so they think you are listening" — nods are mouse-driven, harder to coordinate than a button.
- "the better mental state you are in the less emojis and more text appears so the better you are the less guess work you have to do for the active listening"
- Powerups: "we could use powerups with downsides like coffee that could temporarily boost understanding but makes you crash. powerups are not sustainable"

## Pitch

A cute chibi dog climbs the corporate ladder in a pastel all-animal office. The world says it's dog-eat-dog; the truth is everyone wants to help you — if you take care of yourself and show up for others. Every daily task is a tactile minigame whose difficulty reflects your self-care. Retire when your savings hit the target. You are never fired and never die — the worst case is the mailroom and a sick day.

**Signature mechanic — two directions, one grammar:** tasks you fight TO do (mash to get out of bed) and temptations you fight to RESIST (the mouse gets pulled toward "one more game"). Same physicality, inverted meaning.

**Unifying rule — energy = signal clarity:** your state changes how legible the world is, in both directions:

- Output: work typing text is real words when healthy, keysmash when depleted.
- Input: coworker speech bubbles render as readable text when healthy, cryptic emoji soup when depleted.
- Audio: the lo-fi soundtrack is bright when healthy, muffled/detuned when depleted.

## Protagonist and world

- **Protagonist:** dog. Never speaks — the only "voice" is work typing output. Listening is a game mechanic, not dialogue.
- **Theme resolution:** "dog eat dog" is the titular theme, subverted — dogs are pack animals; the message ("people want to help you if you build relationships") is dog nature. Work-pride angle fits too: dogs love having a job.
- **World:** all-animal office. Cat manager; coworker cast with distinct listening rhythms (fast-talk squirrel, long-pause tortoise, chaotic bird); one rat coworker grinding joylessly as a cautionary mirror. Both puns (dog-eat-dog, rat race) available in copy/marketing.

## Core loop

Fixed day skeleton, variable content:

1. **Wake** — button mash out of bed. Morning clock starts.
2. **Morning routine** — brush teeth (mouse swipe), shower (scrub circles), breakfast (timed clicks). Each optional; each costs clock time; skips cost energy/rep (skip preview shown as cute-dread art, e.g. stink lines follow you to work).
3. **Commute → Work AM** — typing minigame.
4. **Lunch** — Active Listening social minigame with coworkers → rep.
5. **Work PM** — second typing block. Coworker-help events at high rep (coworker covers a task, brings coffee = energy bump).
6. **Evening** — dinner choice (cook = slow, big energy; takeout = fast, weak, costs money), then free slot: exercise / hobby / video games (temptation fight) / work social event (some nights, affects rep).
7. **Sleep choice** — bedtime sets tomorrow's energy.

### Stats (3) + money

- **Energy** (0–100): drives ALL minigame difficulty and signal clarity. No numeric bar shown — the dog sprite IS the bar (4–5 visible states: gleaming → normal → droopy → eye-bag wreck → blanket burrito).
- **Performance** (rolling work-score average): drives salary and promotion.
- **Rep** (coworker relationship level): gates upper promotions, triggers help events.
- **Money:** daily salary → savings. Retirement target visible from day 1 (progress poster on bedroom wall).

## Minigames

Every minigame has one input verb and one difficulty knob driven by energy:

| Minigame | Input | Energy knob |
|---|---|---|
| Wake up | Mash SPACE | Mash threshold + bar decay while mashing |
| Brush teeth | Swipe mouse L↔R | Swipe count + speed floor |
| Shower | Circular scrub on dirt spots | Spot count + scrub sensitivity |
| Breakfast | Timed clicks (flip pancake / catch toast) | Timing window width |
| Work typing | Type shown text | Text itself (signal clarity): healthy = short real phrases, depleted = keysmash; length + error tolerance scale too |
| Lunch: Active Listening | Mouse gestures — nod = up-down, shake = L-R | Cue window width; view drift (mind wanders, screen pans off coworker; mouse to re-center); bubble legibility (text ↔ emoji) |
| Cook dinner | Chop clicks + stir swipe sequence | Step count/speed |
| Video game temptation | Move cursor to "log off" while cursor is pulled toward "one more game" | Pull force scales with low energy + habit streak |
| Exercise | Rhythm mash | Tempo tolerance |

### Active Listening detail

- Coworker talks via speech bubbles. Render scales with energy: high = short readable text (cues obvious), low = emoji-only guesswork. Each beat is authored once as an emoji sequence + optional short text form; state picks the render. No long written dialogue, no localization burden.
- Cue types: agree-nod, enthusiastic double-nod, shake ("can you believe it?"), head tilt (confused; diagonal gesture), and trap cues — coworker venting, any gesture too early = interrupting; hold still.
- Wrong/late gesture = comedic misunderstanding art + rep tick down. Correct-read chains = rep combo.
- Per-coworker rhythm personalities carry content variety (same system, different timing patterns).
- Evening social events reuse the same system, longer and higher stakes.
- Gesture grammar deliberately echoes the physical verbs: brush = horizontal swipe, nod = vertical.

### Difficulty modulation

One global function `difficulty(energy, streaks)` feeds per-minigame params. Neglect streaks (3+ days no shower) add task-specific penalties. All tunables live in a single balance config resource — feel iteration lives in data, not code.

## Powerups (deliberately unsustainable)

Design rule: every powerup borrows from later-today, never generates. Sleep/food/exercise are the only true income. Daily dependency emerges naturally — the player discovers their own toxic loop.

- **Coffee** — buy at work AM. Signal clarity +2 tiers for one work block, then PM crash: clarity below baseline, cursor slightly heavier. Cheap.
- **Energy drink** — bigger boost, harsher crash + jitter: cursor micro-shakes during the boost (accuracy risk baked into the buff). Pricier.
- **Comfort snack** — small energy bump, costs money, diminishing returns if used daily.

## Progression + economy

- **Ranks (6):** Mailroom → Junior → Associate → Senior → Manager → Executive.
  - Ranks 1–3 promote on performance alone; ranks 4–6 require performance AND rep threshold (relationships matter at the top — people skills, not dog-eat-dog).
  - Each rank: salary up, work flavor changes (longer text; meetings = listening minigame at work), and more energy drain per workday. Climbing fast without a self-care foundation is a systemically emergent burnout trap.
- **Demotion:** sustained low performance → warning talk (cute-sad boss scene) → demotion + salary cut. Floor = Mailroom. Never fired.
- **Spending:** takeout, coffee/powerups, hobby gear, event costs (e.g. birthday gift).
- **Retirement:** fixed savings target visible from day 1. Once reached, a "Retire?" option appears each morning; the player picks the moment. Endings vary by state at retirement (high rep = big farewell party; low = quiet exit) — always cute, tone reflective, never punishing. Old dog naps in the sun.
- **Pace (player-paced):** aggressive-healthy play ≈ 25–30 in-game days, average ≈ 40, coasting ≈ 60+. Tunable from the balance config.

## Variety engine + consequences

- **Event deck per slot:** morning/work/lunch/evening each draw from weighted event pools — deadline crunch (typing ×2, boss watching), coworker birthday (gift: money vs rep), rain day (commute variant, wet dog art), office party invite, covering for a sick coworker (rep opportunity, energy cost). Days = skeleton + drawn cards; no two identical.
- **Neglect streaks escalate:** 3+ days no shower = coworkers sit further away at lunch (rep drain aura, stink lines). 3+ nights gaming late = temptation pull force grows (habit).
- **Recovery is fast:** one good night's sleep visibly resets a lot. Fast forgiveness — cute game, not a punishment sim.
- **Consequence tracks:** energy floor → forced sick day (lose the day's pay, partial energy reset, blanket-burrito art). Performance floor → warning → demotion. Both telegraphed one day ahead (boss glance, dog visibly wobbling). Fairness rule: no surprise punishments.

## Art + audio direction

- **Style:** chibi pastel 2D. Flat soft-shadow rooms, side-view scenes: bedroom, bathroom, kitchen, commute, office desk, break room, evening couch.
- **Dog state sprites** (4–5) replace any energy UI.
- **Pipeline:** ChatGPT gen primary, Gemini fallback (workspace rule), contact-sheet batching, per-surface user gates with rendered references. Plans lock sizes/palette/pipeline — never look. Character sheet gated FIRST (dog design anchors everything), then rooms, then cast. Placeholder art until dedicated art waves.
- **Audio:** cozy lo-fi loop shifting with energy state (bright → muffled/detuned — audio joins the signal-clarity rule). Tactile typing/mash SFX. Sourcing deferred to polish wave.

## Tech shape

- **Godot 4 + GDScript + GUT**, new repo `~/code/games/dog-eat-dog`. Ship target: web (itch.io HTML5 export) primary + desktop binaries.
- **Architecture:**
  - Minigames are self-contained scenes implementing a common contract: `setup(params) → play → result{score, time_spent}`.
  - Day scheduler = state machine feeding slot → event deck → minigame params.
  - Single `GameState` resource (energy/performance/rep/money/day/streaks).
  - Single `difficulty.gd` mapping state → per-minigame params.
  - Single balance config resource holding all tunables.
- **Web constraints from day 1:** pointer-lock for mouse-fight/nod gestures, keyboard capture for typing, HTML5 export tested every wave — not at the end.

## Testing

- GUT unit tests: difficulty mapping, economy math, promotion/demotion thresholds, event deck weighting, streak logic.
- Minigame logic tested via injected fake input streams (gesture recognizer fed synthetic mouse paths).
- Feel (mash weight, pull force, gesture windows) = user QA gates per wave; cannot be automated.

## Build strategy (approved: vertical slice first)

- **Wave 1 — vertical slice:** one complete playable day (wake → brush → work typing → lunch listening → dinner → free slot → sleep), placeholder art, energy + performance wired end-to-end, difficulty modulation working. Validates feel early — the game IS feel; if it's wrong, pivoting is cheap.
- **Later waves (order indicative):** rank ladder + economy → rep/social/events + variety deck → art passes (character gate first) → audio + juice + endings + polish.
- Each wave gets its own plan via `superpowers:writing-plans` + agent-factory execution.

## Out of scope (v1)

- Mobile/touch input.
- Localization (emoji-first design keeps the door open).
- Meta-progression across runs / new-game-plus.
- Weekend days, family/romance systems, health-condition systems.
- Steam release (itch.io first).

## Open decisions (scheduled, not vague)

- Final title — own user gate at art/branding wave.
- Dog character design — first art gate, rendered references.
- Exact balance numbers (salary curve, retirement target, decay rates) — tuned in balance config during waves; spec fixes the pace envelope above.
