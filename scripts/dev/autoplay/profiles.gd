extends RefCounted

## The two players the bot can be. Every number here is meant to be humanly
## achievable: sharp p90 becomes the minigame time limits, so a superhuman
## profile would set limits no person can meet.
##
## Skill knobs (seconds unless noted):
##   orient           time spent taking in a freshly hosted screen before
##                    its first input (every slot, beats and cards too)
##   react            decision delay range, drawn fresh per decision
##   mash_frames      frames between SPACE presses when mashing (60 fps)
##   travel_frames    frames a deliberate mouse move takes
##   stroke_px        brush swipe length; stroke_frames to cover it
##   short_stroke     chance a swipe falls short of the 40 px a stroke needs
##   circle_rps       scrub / stir circling speed, revolutions per second
##   circle_radius    scrub / stir radius range, px
##   beat_sd          timing error on a beat press (s, gaussian)
##   late_pass        chance of letting the marker go by once before pressing
##   char_frames      mean frames between typed characters in work AM's
##                    burst; char_sd jitter
##   typo             chance a key is wrong: a burst letter (dropped, and a
##                    reaction to notice) or a triage sort (the other bin, so
##                    the email is filed wrong)
##   hold_sd          release error on a hold meter, in meter units (0..1)
##   gesture_px       nod / shake stroke length; gesture_frames per stroke
##   wrong_gesture    chance of nodding at a shake cue or the other way round
##   drive_zone_out   chance a drive decision is not acted on
##   drive_lookahead  how far up the road (route units) traffic is read
##   flick_px         freetime cursor speed while fighting the pull, px/frame
##   skip             chance of skipping a skippable chore (brush, shower,
##                    breakfast)
##   misdrop          chance a dragged item is let go short of the dog
##   shoes_first      chance of trying shoes before pants
##
## Policy (deterministic per profile):
##   coffee          "buy" | "skip" (the water button); falls back to water
##                   when the buy button is disabled
##   cook_every      dinner: cook when day % cook_every == 0, else takeout;
##                   1 = always cook. Falls back to cook when takeout is
##                   disabled (not enough savings)
##   freetime_games  games let through each night before logging off
##   retire          always take the retire offer (ends the run)

const PROFILES := {
	"sharp": {
		"orient": Vector2(0.8, 1.0),
		"react": Vector2(0.20, 0.30),
		"mash_frames": Vector2i(6, 8),
		"travel_frames": Vector2i(12, 18),
		"stroke_px": 60.0,
		"stroke_frames": 8,
		"short_stroke": 0.0,
		"circle_rps": 2.5,
		"circle_radius": Vector2(38.0, 42.0),
		"beat_sd": 0.02,
		"late_pass": 0.0,
		"char_frames": 9.0,
		"char_sd": 1.5,
		"typo": 0.01,
		"hold_sd": 0.02,
		"gesture_px": 45.0,
		"gesture_frames": 4,
		"wrong_gesture": 0.0,
		"drive_zone_out": 0.0,
		"drive_lookahead": 160.0,
		"flick_px": 30.0,
		"skip": 0.0,
		"misdrop": 0.0,
		"shoes_first": 0.0,
		"coffee": "skip",
		"cook_every": 1,
		"freetime_games": 0,
	},
	"sloppy": {
		"orient": Vector2(1.2, 1.6),
		"react": Vector2(0.45, 0.70),
		"mash_frames": Vector2i(8, 12),
		"travel_frames": Vector2i(20, 30),
		"stroke_px": 50.0,
		"stroke_frames": 11,
		"short_stroke": 0.2,
		"circle_rps": 1.6,
		"circle_radius": Vector2(28.0, 55.0),
		"beat_sd": 0.07,
		"late_pass": 0.15,
		"char_frames": 17.0,
		"char_sd": 4.0,
		"typo": 0.06,
		"hold_sd": 0.07,
		"gesture_px": 40.0,
		"gesture_frames": 6,
		"wrong_gesture": 0.1,
		"drive_zone_out": 0.15,
		"drive_lookahead": 80.0,
		"flick_px": 20.0,
		"skip": 0.15,
		"misdrop": 0.1,
		"shoes_first": 0.25,
		"coffee": "buy",
		"cook_every": 3,
		"freetime_games": 2,
	},
}


static func names() -> Array:
	return PROFILES.keys()


## The policy rows the report prints, in a fixed order.
static func policy_rows(profile: Dictionary) -> Array[String]:
	var dinner := "always cook" if profile.cook_every == 1 \
			else "cook every %d days, takeout otherwise" % profile.cook_every
	return [
		"orient: %.1f-%.1f s taking in each new screen before the first input" % [
			profile.orient.x, profile.orient.y,
		],
		"coffee: %s" % ("buy one" if profile.coffee == "buy" else "water"),
		"dinner: %s (cook when takeout is unaffordable)" % dinner,
		"free-time games per night: %d" % profile.freetime_games,
		"skippable chores skipped: %d%%" % roundi(profile.skip * 100.0),
		"retire: take the offer the first morning it appears",
	]
