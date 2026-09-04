extends RefCounted
## RMS overall and RMS above ~800 Hz. The first version used the first
## difference, which is a 6 dB/oct tilt and therefore just measures pitch —
## it scored the highest-pitched layer as the noisiest and told me nothing.

func run() -> int:
	# Calibration first. If a pure 200 Hz sine reports meaningful energy
	# "above 800 Hz" then the measure is a tilt, not a band, and every
	# number under it is worthless.
	_report("REF 200Hz sine", _sine(200.0))
	_report("REF 2kHz sine", _sine(2000.0))
	_report("REF white noise", _noise())
	_report("music.bed", Music.bed())
	_report("music.dread", Music.dread())
	_report("music.pulse", Music.pulse())
	_report("music.tension", Music.tension())
	_report("synth.ambient", Synth.ambient())
	_report("synth.douse", Synth.douse())
	return 0

func _sine(hz: float) -> AudioStreamWAV:
	var n: int = Music.RATE * 4
	var buf := PackedFloat32Array(); buf.resize(n)
	for i in range(n):
		buf[i] = sin(TAU * hz * float(i) / float(Music.RATE)) * 0.5
	return Synth._wav(buf, false, Music.RATE)

func _noise() -> AudioStreamWAV:
	var n: int = Music.RATE * 4
	var buf := PackedFloat32Array(); buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(n):
		buf[i] = rng.randf_range(-0.5, 0.5)
	return Synth._wav(buf, false, Music.RATE)

func _report(name: String, w: AudioStreamWAV) -> void:
	var n: int = w.data.size() / 2
	var rate: float = float(w.mix_rate)
	# Four cascaded poles at 800 Hz — 24 dB/oct. One pole is 6 dB/oct, which
	# at 200 Hz still passes a quarter of the signal, so a single-pole
	# version scored a pure 200 Hz sine at 24% "above 800 Hz" and was
	# measuring pitch all over again. The REF rows above keep it honest.
	var rc: float = 1.0 / (TAU * 800.0)
	var a: float = rc / (rc + 1.0 / rate)
	var poles: int = 4
	var y := PackedFloat32Array(); y.resize(poles)
	var prev := PackedFloat32Array(); prev.resize(poles)
	var sum: float = 0.0
	var hi_sum: float = 0.0
	var peak: float = 0.0
	for i in range(n):
		var v: float = float(w.data.decode_s16(i * 2)) / 32767.0
		sum += v * v
		var x: float = v
		for k in range(poles):
			var out: float = a * (y[k] + x - prev[k])
			prev[k] = x
			y[k] = out
			x = out
		hi_sum += x * x
		peak = maxf(peak, absf(v))
	var rms: float = sqrt(sum / float(n))
	var hi: float = sqrt(hi_sum / float(n))
	print("%-14s %5d Hz  peak %.3f  rms %.4f  >800Hz %.5f  (%.1f%% of rms)" % [
		name, int(rate), peak, rms, hi, 100.0 * hi / maxf(rms, 1e-6)])
