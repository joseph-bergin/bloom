class_name Music
extends RefCounted
## Four looping layers that the game mixes live. Same rule as the cues: PCM
## built at startup, no binary assets, every value a number you can move.
##
## The layers are all exactly LOOP long and are started together, so they
## stay in phase for as long as the game runs and can be crossfaded against
## each other without ever being re-synced.
##
##   bed     always on — the dark you are standing in
##   pulse   the run itself: a heartbeat and a bassline
##   tension rises with your luminance. The brighter you burn, the more
##           crowded the music gets. That is the whole game in one fader.
##   dread   the boss
##
## D minor, 80 BPM, eight bars: Dm - Bb - F - C.

const RATE := 11025          # half rate: nothing here lives above 3 kHz
const LOOP := 12.0           # 4 bars at 80 BPM
const BAR := 3.0
const BEAT := 0.75
const BARS := 4
## Extra tail generated and folded back over the head, so the noise in the
## bed and dread layers is circularly smooth. Without it the seam jumped a
## fifth of full scale and clicked once every loop.
const FOLD := 0.5            # seconds
## How much low wash sits under each drone.
const BED_WASH := 2.2
const DREAD_WASH := 1.0

## Sustained partials must complete a whole number of cycles inside the loop
## or the seam clicks. Snapping costs at most 1/24 Hz, which nobody can hear.
static func _snap(f: float) -> float:
	return round(f * LOOP) / LOOP

const D2 := 73.42
const F2 := 87.31
const A2 := 110.00
const BB2 := 116.54
const C3 := 130.81
const D3 := 146.83
const E3 := 164.81
const F3 := 174.61
const G3 := 196.00
const A3 := 220.00

## One bar each: i - VI - III - VII, the oldest sad loop there is.
const ROOTS := [D2, BB2, F2, C3]
## What the tension layer is allowed to play over each bar.
const VOICES := [
	[D3, F3, A3],
	[BB2, D3, F3],
	[F3, A3, C3 * 2.0],
	[C3, E3, G3],
]

static func _len() -> int:
	return int(LOOP * RATE)

static func _fold_len() -> int:
	return int(FOLD * RATE)

## Angular velocity per sample for a snapped frequency. Hoisted out of the
## inner loops: snapping per partial per sample was most of the cost.
static func _w(f: float) -> float:
	return TAU * _snap(f) / float(RATE)

## The dark you are standing in. Two low drones a fifth apart, detuned
## enough to beat slowly against each other, under a wash of filtered noise.
static func bed() -> AudioStreamWAV:
	var n: int = _len()
	var f: int = _fold_len()
	var buf := PackedFloat32Array(); buf.resize(n + f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11071
	# Angular velocities, snapped once. _snap() per partial per sample was
	# most of the generation cost.
	var w1: float = _w(D2)
	var w2: float = _w(D2 * 1.005)
	var w3: float = _w(A2)
	var w4: float = _w(D2 * 0.5)
	var s1: float = _w(1.0 / 12.0)
	var s2: float = _w(1.0 / 8.0)
	var lp: float = 0.0
	for i in range(n + f):
		var t: float = float(i)
		var v: float = sin(w1 * t) * 0.30 + sin(w2 * t) * 0.22
		v += sin(w3 * t) * 0.14 + sin(w4 * t) * 0.20
		# Two slow swells at different rates, so the bed never sits still.
		v *= 0.70 + 0.20 * sin(s1 * t) + 0.10 * sin(s2 * t)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.0015)
		buf[i] = v + lp * BED_WASH
	return Synth._wav(Synth._normalise(_fold(buf, n, f), 0.5), true, RATE)

## The run: a heartbeat on one and three, and the root under it.
static func pulse() -> AudioStreamWAV:
	var n: int = _len()
	var buf := PackedFloat32Array(); buf.resize(n)
	for bar in range(BARS):
		var root: float = ROOTS[bar]
		# One sustained root across each bar, soft in and fully out again, so
		# nothing is still ringing at the loop point.
		_place(buf, bar * BAR, BAR * 0.98, func(x: float, t: float) -> float:
			var e: float = minf(x / 0.12, 1.0) * pow(1.0 - x, 1.1)
			return (sin(TAU * root * t) * 0.5
				+ sin(TAU * root * 2.0 * t) * 0.10) * e)
		for beat in [0, 2]:
			_place(buf, bar * BAR + float(beat) * BEAT, 0.42,
				func(x: float, t: float) -> float:
					# Pitch drops through the hit: that is what makes it a
					# heartbeat rather than a note.
					var f: float = lerpf(96.0, 44.0, pow(x, 0.35))
					return sin(TAU * f * t) * _hit(x, 0.02, 2.6) * 0.85)
	return Synth._wav(Synth._normalise(buf, 0.62), true, RATE)

## Rises with your light. Sixteenths on the chord, bell-ish and close, with
## a tremolo that tightens as it goes — this is the layer that should make
## you want to put the light out.
static func tension() -> AudioStreamWAV:
	var n: int = _len()
	var buf := PackedFloat32Array(); buf.resize(n)
	var step: float = BEAT * 0.5
	var k: int = 0
	var t: float = 0.0
	while t < LOOP - step:
		var bar: int = clampi(int(t / BAR), 0, BARS - 1)
		var voices: Array = VOICES[bar]
		# Up and back down the chord. This used to be shifted an octave up
		# with a bright partial stack on top, which put 41% of the layer's
		# energy above 800 Hz — as sixteenths under everything else that
		# reads as static, and it is the layer that gets louder the better
		# you are doing.
		var idx: int = k % (voices.size() * 2 - 2)
		if idx >= voices.size():
			idx = voices.size() * 2 - 2 - idx
		var f: float = float(voices[idx])
		_place(buf, t, step * 1.6, func(x: float, tt: float) -> float:
			var e: float = _hit(x, 0.05, 3.2)
			return (sin(TAU * f * tt) * 0.5 + sin(TAU * f * 2.0 * tt) * 0.07) * e)
		k += 1
		t += step
	return Synth._wav(Synth._normalise(buf, 0.5), true, RATE)

## The boss. An octave below everything else, with a slow tremolo, so the
## room feels smaller the moment it fades in.
static func dread() -> AudioStreamWAV:
	var n: int = _len()
	var f: int = _fold_len()
	var buf := PackedFloat32Array(); buf.resize(n + f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 60627
	var w1: float = _w(D2 * 0.5)
	var w2: float = _w(D2 * 0.5 * 1.008)
	var w3: float = _w(D2)
	var w4: float = _w(BB2 * 0.5)
	# 3.2 Hz: fast enough to read as a threat, slow enough not to buzz.
	var tr: float = _w(3.2)
	var sw: float = _w(1.0 / 6.0)
	var lp: float = 0.0
	for i in range(n + f):
		var t: float = float(i)
		var v: float = sin(w1 * t) * 0.55 + sin(w2 * t) * 0.35
		v += sin(w3 * t) * 0.16 + sin(w4 * t) * 0.18
		v *= 0.55 + 0.45 * sin(tr * t)
		v *= 0.7 + 0.3 * sin(sw * t)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.004)
		buf[i] = v + lp * DREAD_WASH
	return Synth._wav(Synth._normalise(_fold(buf, n, f), 0.72), true, RATE)

## Attack then decay. Every note used to start at full amplitude — the decay
## curve alone is 1.0 at x = 0 — so each one opened on a step discontinuity,
## which is a click. Sixty-four per loop in the tension layer.
static func _hit(x: float, attack: float, fall: float) -> float:
	return minf(x / attack, 1.0) * pow(1.0 - x, fall)

## Writes one enveloped voice into the buffer at `at` seconds. `shape` gets
## the note's progress 0..1 and its own elapsed time, so it can hold a
## stable phase regardless of where in the loop it landed.
static func _place(buf: PackedFloat32Array, at: float, dur: float,
		shape: Callable) -> void:
	var start: int = int(at * RATE)
	var count: int = int(dur * RATE)
	for j in range(count):
		var i: int = start + j
		if i < 0 or i >= buf.size():
			return
		buf[i] += shape.call(float(j) / float(count), float(j) / float(RATE))

## Folds the extra tail back over the head and returns exactly `n` samples.
##
## The layer is generated `f` samples long-of-loop; blending B[n+j] into B[j]
## makes A[n-1] -> A[0] land on B[n-1] -> B[n], which is continuous in the
## source. Periodic content is untouched, because for it B[n+j] == B[j].
## The first attempt crossfaded within a fixed-length buffer, which left the
## two ends as far apart as it found them.
static func _fold(buf: PackedFloat32Array, n: int, f: int) -> PackedFloat32Array:
	for j in range(f):
		var g: float = float(j) / float(f)
		buf[j] = buf[j] * g + buf[n + j] * (1.0 - g)
	buf.resize(n)
	return buf
