extends RefCounted
## Levels, timing and loop-seam continuity for the music layers.

func run() -> int:
	var layers := {"bed": Music.bed(), "pulse": Music.pulse(),
		"tension": Music.tension(), "dread": Music.dread()}
	for name in layers:
		var t0: int = Time.get_ticks_msec()
		var w: AudioStreamWAV = layers[name]
		var n: int = w.data.size() / 2
		var peak: float = 0.0
		for i in range(n):
			peak = maxf(peak, absf(float(w.data.decode_s16(i * 2)) / 32767.0))
		var seam: float = absf(float(w.data.decode_s16(0)) / 32767.0
			- float(w.data.decode_s16((n - 1) * 2)) / 32767.0)
		print("%-8s %5.1fs  peak %.3f  seam %.4f  loop=%s  %d ms" % [
			name, float(n) / float(Music.RATE), peak, seam,
			w.loop_mode != AudioStreamWAV.LOOP_DISABLED,
			Time.get_ticks_msec() - t0])
	return 0
