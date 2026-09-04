extends RefCounted
## The suite never sees the music: it is skipped headless, and the mix is a
## frame-by-frame thing. This drives the real Audio autoload.

var _fails: int = 0

func run(tree: SceneTree) -> int:
	# Bake synchronously — the real path uses a thread, which is exactly the
	# part a probe cannot wait on politely.
	Audio.call("_bake_music")
	Audio.call("_start_music")
	var players: Dictionary = Audio.get("_music")
	_ok(players.size() == 4, "four layers attached (%d)" % players.size())
	for layer in players:
		var p: AudioStreamPlayer = players[layer]
		_ok(p.playing, "%s is playing" % layer)
		_ok(p.bus == &"Music", "%s is on the Music bus" % layer)
		var w: AudioStreamWAV = p.stream
		_ok(w.loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s loops" % layer)

	var s: GameStateData = GameState.s
	GameState.paused = false
	s.run_over = false

	s.phase = GameStateData.Phase.UPGRADING
	var m: Dictionary = Audio.call("_music_mix")
	_ok(m["bed"] > 0.0, "the bed plays between levels")
	_ok(m["pulse"] == 0.0, "the pulse does not")

	s.phase = GameStateData.Phase.FIGHTING
	s.luminance = 0.0
	var dark: Dictionary = Audio.call("_music_mix")
	s.luminance = 200.0
	var bright: Dictionary = Audio.call("_music_mix")
	_ok(dark["pulse"] > 0.0, "the pulse comes in with the level")
	_ok(bright["tension"] > dark["tension"], "tension rises with your light")
	_ok(dark["tension"] < 0.01, "and is gone when you are dark")

	s.phase = GameStateData.Phase.BOSS
	_ok(Audio.call("_music_mix")["dread"] > 0.0, "dread arrives with the boss")

	s.run_over = true
	var over: Dictionary = Audio.call("_music_mix")
	_ok(over["pulse"] == 0.0 and over["dread"] == 0.0, "everything stops when you do")
	_ok(over["bed"] > 0.0, "except the dark")

	# Ducking must not strand the bus muted.
	Audio.call("duck", 0.001)
	_ok(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),
		"a breach mutes the music")
	await tree.create_timer(0.2).timeout
	_ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),
		"and it comes back")

	print("%d checks failed" % _fails)
	return 1 if _fails > 0 else 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("  FAIL ", msg)
