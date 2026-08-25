class_name Synth
extends RefCounted
## Procedural cue generation. The game ships no audio binaries; every sound
## is a buffer built at startup, which keeps cues tunable as numbers.

const RATE := 22050

static func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s

static func _env(i: int, n: int, attack: float, decay: float) -> float:
	var x: float = float(i) / float(maxi(n, 1))
	if x < attack:
		return x / maxf(attack, 0.0001)
	return pow(maxf(1.0 - (x - attack) / maxf(decay, 0.0001), 0.0), 2.0)

## Descending sine with a click transient — the lance leaving.
static func lance_launch() -> AudioStreamWAV:
	var n: int = int(RATE * 0.28)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(680.0, 190.0, pow(x, 0.6))
		var v: float = sin(TAU * f * float(i) / RATE) * 0.5
		v += sin(TAU * f * 2.01 * float(i) / RATE) * 0.12
		buf[i] = v * _env(i, n, 0.004, 0.98)
	return _wav(buf)

## Low body plus filtered noise — something ceasing to exist.
static func detonation(tier: int) -> AudioStreamWAV:
	var n: int = int(RATE * (0.5 + 0.06 * float(tier)))
	var buf := PackedFloat32Array(); buf.resize(n)
	var base: float = 120.0 / (1.0 + float(tier) * 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137 + tier
	var lp: float = 0.0
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = base * (1.0 - x * 0.45)
		var body: float = sin(TAU * f * float(i) / RATE)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.22)
		buf[i] = (body * 0.62 + lp * 0.38) * _env(i, n, 0.002, 0.99)
	return _wav(buf)

## A rising, opening chime — the ring going out.
static func sweep() -> AudioStreamWAV:
	var n: int = int(RATE * 0.9)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(300.0, 1180.0, pow(x, 0.75))
		var v: float = sin(TAU * f * float(i) / RATE) * 0.34
		v += sin(TAU * f * 1.5 * float(i) / RATE) * 0.16
		buf[i] = v * _env(i, n, 0.05, 0.92)
	return _wav(buf)

## The purchase chunk. Short, low, satisfying.
static func purchase() -> AudioStreamWAV:
	var n: int = int(RATE * 0.16)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var f: float = 158.0
		var v: float = sin(TAU * f * float(i) / RATE) * 0.6
		v += sin(TAU * f * 3.0 * float(i) / RATE) * 0.18
		buf[i] = v * _env(i, n, 0.003, 0.97)
	return _wav(buf)

## Sharp, bright, unmissable — a cascade firing while you weren't looking.
static func cascade() -> AudioStreamWAV:
	var n: int = int(RATE * 0.42)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = 880.0 + 440.0 * sin(x * 22.0)
		buf[i] = sin(TAU * f * float(i) / RATE) * 0.42 * _env(i, n, 0.001, 0.96)
	return _wav(buf)

## Two-tone alarm — a strike inbound, if you can see it coming.
static func alarm() -> AudioStreamWAV:
	var n: int = int(RATE * 0.7)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = 520.0 if fmod(x * 6.0, 2.0) < 1.0 else 390.0
		buf[i] = sin(TAU * f * float(i) / RATE) * 0.4 * _env(i, n, 0.01, 0.99)
	return _wav(buf)

## Impact. The floor coming out.
static func strike_land() -> AudioStreamWAV:
	var n: int = int(RATE * 1.1)
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	var lp: float = 0.0
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(74.0, 32.0, x)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.06)
		buf[i] = (sin(TAU * f * float(i) / RATE) * 0.72 + lp * 0.3) * _env(i, n, 0.001, 0.99)
	return _wav(buf)

## Looping thrum for a tracked contact. Pitch falls with tier.
static func contact_voice(tier: int) -> AudioStreamWAV:
	var f: float = 66.0 * pow(0.86, float(tier))
	var period: int = int(round(float(RATE) / f))
	var n: int = period * 24
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var p: float = TAU * f * float(i) / RATE
		var v: float = sin(p) * 0.5 + sin(p * 2.0) * 0.14 + sin(p * 3.01) * 0.07
		# Slow amplitude wobble so it reads as alive, not as a test tone.
		v *= 0.72 + 0.28 * sin(TAU * 0.6 * float(i) / RATE)
		buf[i] = v * 0.5
	return _wav(buf, true)

## Sustained low drone while any hunter lives. Removing it is the beat.
static func hunter_drone() -> AudioStreamWAV:
	var f: float = 41.0
	var period: int = int(round(float(RATE) / f))
	var n: int = period * 40
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var p: float = TAU * f * float(i) / RATE
		var v: float = sin(p) * 0.6 + sin(p * 1.5) * 0.2 + sin(p * 2.02) * 0.1
		v *= 0.8 + 0.2 * sin(TAU * 0.21 * float(i) / RATE)
		buf[i] = v * 0.55
	return _wav(buf, true)

## Accelerating tick as a tether nears 1.0.
static func slack_tick() -> AudioStreamWAV:
	var n: int = int(RATE * 0.06)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		buf[i] = sin(TAU * 1450.0 * float(i) / RATE) * 0.35 * _env(i, n, 0.002, 0.98)
	return _wav(buf)

## Ambient bed. Barely there, but the silence lands harder against it.
static func ambient() -> AudioStreamWAV:
	var n: int = RATE * 8
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260824
	var lp: float = 0.0
	for i in range(n):
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.0016)
		var sway: float = sin(TAU * 0.037 * float(i) / RATE)
		buf[i] = (lp * 6.0 + sin(TAU * 48.0 * float(i) / RATE) * 0.06) * (0.5 + 0.5 * sway) * 0.5
	# Ensure the loop point does not click.
	var fade: int = RATE / 2
	for i in range(fade):
		var g: float = float(i) / float(fade)
		buf[i] *= g
		buf[n - 1 - i] *= g
	return _wav(buf, true)

static func ui_click() -> AudioStreamWAV:
	var n: int = int(RATE * 0.04)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		buf[i] = sin(TAU * 980.0 * float(i) / RATE) * 0.22 * _env(i, n, 0.002, 0.98)
	return _wav(buf)
