extends RefCounted
## RMS overall and RMS above ~800 Hz. The first version used the first
## difference, which is a 6 dB/oct tilt and therefore just measures pitch —
## it scored the highest-pitched layer as the noisiest and told me nothing.

func run() -> int:
	_report("music.bed", Music.bed())
	_report("music.dread", Music.dread())
	_report("music.pulse", Music.pulse())
	_report("music.tension", Music.tension())
	_report("synth.ambient", Synth.ambient())
	_report("synth.douse", Synth.douse())
	return 0

func _report(name: String, w: AudioStreamWAV) -> void:
	var n: int = w.data.size() / 2
	var rate: float = float(w.mix_rate)
	# One-pole highpass at 800 Hz: everything musical here lives below it,
	# so what survives is broadband noise.
	var rc: float = 1.0 / (TAU * 800.0)
	var a: float = rc / (rc + 1.0 / rate)
	var sum: float = 0.0
	var hi_sum: float = 0.0
	var y: float = 0.0
	var prev: float = 0.0
	var peak: float = 0.0
	for i in range(n):
		var v: float = float(w.data.decode_s16(i * 2)) / 32767.0
		sum += v * v
		y = a * (y + v - prev)
		prev = v
		hi_sum += y * y
		peak = maxf(peak, absf(v))
	var rms: float = sqrt(sum / float(n))
	var hi: float = sqrt(hi_sum / float(n))
	print("%-14s %5d Hz  peak %.3f  rms %.4f  >800Hz %.5f  (%.1f%% of rms)" % [
		name, int(rate), peak, rms, hi, 100.0 * hi / maxf(rms, 1e-6)])
