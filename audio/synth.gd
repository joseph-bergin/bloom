class_name Synth
extends RefCounted
## Cues are PCM buffers built at startup. No binary assets, and every sound
## stays tunable as a number.

const RATE := 22050

static func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
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

## Short bright pop. Pitch rises with the kill streak.
static func kill(tier: int) -> AudioStreamWAV:
	var n: int = int(RATE * (0.13 + 0.02 * float(tier)))
	var buf := PackedFloat32Array(); buf.resize(n)
	var base: float = 620.0 * pow(0.88, float(tier))
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = base * (1.0 - x * 0.45)
		buf[i] = (sin(TAU * f * float(i) / RATE) * 0.55
			+ sin(TAU * f * 2.0 * float(i) / RATE) * 0.18) * _env(i, n, 0.003, 0.97)
	return _wav(buf)

## A dry tick on every landed shot. Tiny, or a fast turret becomes a drill.
static func hit() -> AudioStreamWAV:
	var n: int = int(RATE * 0.045)
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(1500.0, 700.0, x)
		buf[i] = (sin(TAU * f * float(i) / RATE) * 0.45
			+ rng.randf_range(-1.0, 1.0) * 0.22) * _env(i, n, 0.002, 0.98)
	return _wav(buf)

## Brighter and longer, for a critical.
static func crit() -> AudioStreamWAV:
	var n: int = int(RATE * 0.10)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(2100.0, 900.0, pow(x, 0.6))
		buf[i] = (sin(TAU * f * float(i) / RATE) * 0.42
			+ sin(TAU * f * 1.5 * float(i) / RATE) * 0.20) * _env(i, n, 0.002, 0.97)
	return _wav(buf)

## Going dark: a downward swallow, air being pulled in.
static func douse_in() -> AudioStreamWAV:
	var n: int = int(RATE * 0.42)
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var lp: float = 0.0
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(520.0, 70.0, pow(x, 0.55))
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.10)
		buf[i] = (sin(TAU * f * float(i) / RATE) * 0.55 + lp * 0.28 * (1.0 - x)) \
			* _env(i, n, 0.01, 0.96)
	return _wav(buf)

## Coming back up: the reverse, and brighter.
static func douse_out() -> AudioStreamWAV:
	var n: int = int(RATE * 0.32)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(90.0, 620.0, pow(x, 0.7))
		buf[i] = sin(TAU * f * float(i) / RATE) * 0.45 * _env(i, n, 0.02, 0.95)
	return _wav(buf)

## The purchase chunk. Low, short, satisfying — this one matters most.
static func purchase() -> AudioStreamWAV:
	var n: int = int(RATE * 0.18)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var f: float = 150.0
		var v: float = sin(TAU * f * float(i) / RATE) * 0.62
		v += sin(TAU * f * 3.0 * float(i) / RATE) * 0.20
		v += sin(TAU * f * 0.5 * float(i) / RATE) * 0.12
		buf[i] = v * _env(i, n, 0.002, 0.96)
	return _wav(buf)

## Shield breach. The floor coming out.
static func breach() -> AudioStreamWAV:
	var n: int = int(RATE * 1.0)
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	var lp: float = 0.0
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(78.0, 30.0, x)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.07)
		buf[i] = (sin(TAU * f * float(i) / RATE) * 0.72 + lp * 0.3) * _env(i, n, 0.001, 0.99)
	return _wav(buf)

## Held while dousing: a low, close, muffling hum.
static func douse() -> AudioStreamWAV:
	var f: float = 58.0
	var period: int = int(round(float(RATE) / f))
	var n: int = period * 30
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var p: float = TAU * f * float(i) / RATE
		var v: float = sin(p) * 0.6 + sin(p * 2.01) * 0.15
		v *= 0.82 + 0.18 * sin(TAU * 0.7 * float(i) / RATE)
		buf[i] = v * 0.5
	return _wav(buf, true)

## Ambient bed. Barely there, so the breach duck lands against something.
static func ambient() -> AudioStreamWAV:
	var n: int = RATE * 8
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260825
	var lp: float = 0.0
	for i in range(n):
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.0016)
		var sway: float = sin(TAU * 0.037 * float(i) / RATE)
		buf[i] = (lp * 6.0 + sin(TAU * 46.0 * float(i) / RATE) * 0.06) * (0.5 + 0.5 * sway) * 0.5
	var fade: int = RATE / 2
	for i in range(fade):
		var g: float = float(i) / float(fade)
		buf[i] *= g
		buf[n - 1 - i] *= g
	return _wav(buf, true)

static func click() -> AudioStreamWAV:
	var n: int = int(RATE * 0.04)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		buf[i] = sin(TAU * 940.0 * float(i) / RATE) * 0.22 * _env(i, n, 0.002, 0.98)
	return _wav(buf)
