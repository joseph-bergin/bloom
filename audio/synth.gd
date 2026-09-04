class_name Synth
extends RefCounted
## Cues are PCM buffers built at startup. No binary assets, and every sound
## stays tunable as a number.

const RATE := 22050

## `rate` is a parameter because the music layers run at half rate: a dark
## bed has nothing above 3 kHz and generating them at 22 kHz doubled the
## startup cost for nothing.
static func _wav(samples: PackedFloat32Array, loop: bool = false,
		rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
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

## Scales a buffer so its loudest sample sits at `peak`.
static func _normalise(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var hi: float = 0.0
	for v in buf:
		hi = maxf(hi, absf(v))
	if hi <= 0.0001:
		return buf
	var g: float = peak / hi
	for i in range(buf.size()):
		buf[i] *= g
	return buf

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

## The boss arriving: a low two-note horn. Long enough to stop what you
## are doing and look up.
static func boss() -> AudioStreamWAV:
	var n: int = int(RATE * 1.5)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		# Drops to a second, lower note a third of the way through.
		var f: float = 116.0 if x < 0.34 else 87.0
		var p: float = TAU * f * float(i) / RATE
		var v: float = sin(p) * 0.55 + sin(p * 2.0) * 0.22 + sin(p * 3.0) * 0.10
		# A slow beat between two detuned voices, so it wavers.
		v *= 0.78 + 0.22 * sin(TAU * 5.5 * float(i) / RATE)
		var env: float = _env(i, n, 0.03, 0.99)
		if x >= 0.30 and x < 0.36:
			env *= 0.25   # a breath between the notes
		buf[i] = v * env
	return _wav(buf)

## A level clearing: a short rising figure. The counterpart to the horn.
static func cleared() -> AudioStreamWAV:
	var n: int = int(RATE * 0.75)
	var buf := PackedFloat32Array(); buf.resize(n)
	var steps: Array[float] = [392.0, 523.0, 659.0]
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = steps[clampi(int(x * 3.0), 0, 2)]
		var p: float = TAU * f * float(i) / RATE
		buf[i] = (sin(p) * 0.42 + sin(p * 2.0) * 0.14) * _env(i, n, 0.01, 0.98)
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

## Cursor crossing something you can press. Has to sit under everything —
## you hear a dozen of these a second sweeping across the tree.
static func hover() -> AudioStreamWAV:
	var n: int = int(RATE * 0.022)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(1500.0, 1900.0, x)
		buf[i] = sin(TAU * f * float(i) / RATE) * 0.09 * _env(i, n, 0.05, 0.95)
	return _wav(buf)

## A button going down. A tick of noise for the contact, a short body under
## it so it lands rather than just ticking.
static func press() -> AudioStreamWAV:
	var n: int = int(RATE * 0.07)
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	for i in range(n):
		var x: float = float(i) / float(n)
		var body: float = sin(TAU * 620.0 * float(i) / RATE) * 0.34
		body += sin(TAU * 310.0 * float(i) / RATE) * 0.16
		var tick: float = rng.randf_range(-1.0, 1.0) * 0.30 * pow(1.0 - x, 14.0)
		buf[i] = (body * _env(i, n, 0.002, 0.9) + tick)
	return _wav(buf)

## No. A short flat buzz, low enough that it never reads as a reward.
static func denied() -> AudioStreamWAV:
	var n: int = int(RATE * 0.13)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		var x: float = float(i) / float(n)
		var f: float = lerpf(190.0, 140.0, x)
		var p: float = TAU * f * float(i) / RATE
		# Square-ish: the harmonics are what make it read as a refusal.
		var v: float = signf(sin(p)) * 0.26 + sin(p * 2.0) * 0.08
		buf[i] = v * _env(i, n, 0.004, 0.92)
	return _wav(buf)

## The tree sliding in or out. Filtered noise, no pitch to clash with the
## ambient bed.
static func whoosh(up: bool) -> AudioStreamWAV:
	var n: int = int(RATE * 0.26)
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2255
	var lp: float = 0.0
	for i in range(n):
		var x: float = float(i) / float(n)
		# Sweeping the filter is the whole effect: bright opening, dull closing.
		var cut: float = lerpf(0.04, 0.42, x if up else 1.0 - x)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), cut)
		buf[i] = lp * _env(i, n, 0.12, 0.86)
	# The lowpass eats most of the amplitude, and by how much depends on the
	# sweep direction — opening came out half the level of closing. Normalise
	# rather than hand-tuning two gains that drift apart.
	return _wav(_normalise(buf, 0.5))

static func click() -> AudioStreamWAV:
	var n: int = int(RATE * 0.04)
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		buf[i] = sin(TAU * 940.0 * float(i) / RATE) * 0.22 * _env(i, n, 0.002, 0.98)
	return _wav(buf)
