extends RefCounted
## Renders a preview of the score to a .wav so it can be listened to outside
## the game: four loops walking through the arc the mixer actually drives.
##   dark -> a level starts -> you burn brighter -> the boss

func run(out_path: String) -> int:
	var layers := {"bed": Music.bed(), "pulse": Music.pulse(),
		"tension": Music.tension(), "dread": Music.dread()}
	var loop: int = int(Music.LOOP * Music.RATE)
	var total: int = loop * 4
	var mix := PackedFloat32Array(); mix.resize(total)

	for i in range(total):
		var t: float = float(i) / float(Music.RATE)
		var gain := {
			"bed": 0.85,
			"pulse": _ramp(t, 12.0, 2.0) * 0.75,
			"tension": _ramp(t, 24.0, 6.0) * 0.8,
			"dread": _ramp(t, 36.0, 2.0) * 0.9,
		}
		var v: float = 0.0
		for name in layers:
			var g: float = gain[name]
			if g <= 0.0:
				continue
			v += _sample(layers[name], i % loop) * g
		mix[i] = v

	var w := AudioStreamWAV.new()
	var bytes := PackedByteArray(); bytes.resize(total * 2)
	for i in range(total):
		bytes.encode_s16(i * 2, int(clampf(mix[i] * 0.62, -1.0, 1.0) * 32767.0))
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = Music.RATE
	w.stereo = false
	w.data = bytes
	var err: int = w.save_to_wav(out_path)
	print("wrote %s (%.0fs) err=%d" % [out_path, float(total) / Music.RATE, err])
	return 0 if err == OK else 1

func _sample(w: AudioStreamWAV, i: int) -> float:
	return float(w.data.decode_s16(i * 2)) / 32767.0

## 0 before `at`, easing to 1 over `over` seconds.
func _ramp(t: float, at: float, over: float) -> float:
	return clampf((t - at) / over, 0.0, 1.0)
