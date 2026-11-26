class_name AudioEngine
extends Node
## Real-time procedural audio synthesizer using AudioStreamGenerator.
## Generates chill pentatonic kalimba chimes (zero heavy bass drone) and
## crisp wild organic SFX with zero external MP3/WAV dependencies.

const MIX_RATE: float = 24000.0
const BUFFER_LENGTH: float = 0.085
const MAX_VOICES: int = 24
const PENTATONIC_RATIOS: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5, 3.0]

var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _muted: bool = false
var _scale_index: int = 0

var _voices: Array[Dictionary] = []
var _chime_timer: float = 0.6
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_note_idx: int = 2


func _ready() -> void:
	_rng.randomize()
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LENGTH

	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralAudioPlayer"
	_player.stream = stream
	_player.volume_db = -3.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func set_muted(m: bool) -> void:
	_muted = m
	if _player != null:
		_player.stream_paused = _muted
	if _muted:
		_voices.clear()


func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted


func is_muted() -> bool:
	return _muted


func set_scale_index(idx: int) -> void:
	_scale_index = clampi(idx, 0, Scales.NUM_SCALES - 1)


func _get_scale_root() -> float:
	var scale_dict: Dictionary = Scales.SCALES[_scale_index]
	return float(scale_dict.get("music_root", 261.63))


func _process(delta: float) -> void:
	if _muted or _playback == null:
		return

	# Gentle ambient pentatonic kalimba melody (airy, light, zero bass drone)
	_chime_timer -= delta
	if _chime_timer <= 0.0:
		_chime_timer = _rng.randf_range(1.05, 2.25)
		_spawn_ambient_kalimba()

	_fill_audio_buffer()


func _spawn_ambient_kalimba() -> void:
	var step: int = _rng.randi_range(-2, 2)
	if step == 0:
		step = 1
	_last_note_idx = clampi(_last_note_idx + step, 0, PENTATONIC_RATIOS.size() - 1)
	var root: float = _get_scale_root()
	# Keep kalimba airy in the mid-high register (never muddy bass)
	var base_freq: float = root * PENTATONIC_RATIOS[_last_note_idx]
	if base_freq < 260.0:
		base_freq *= 2.0
	_add_voice({
		"kind": "kalimba",
		"age": 0.0,
		"duration": _rng.randf_range(0.85, 1.45),
		"freq": base_freq,
		"freq_end": base_freq,
		"gain": 0.11,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.008,
		"decay": 4.2,
		"noise_gain": 0.02,
	})


func _add_voice(v: Dictionary) -> void:
	if _muted:
		return
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	_voices.append(v)


func play_chomp(pitch_mult: float = 1.0) -> void:
	var p: float = clampf(pitch_mult, 0.7, 1.6)
	_add_voice({
		"kind": "organic_pop",
		"age": 0.0,
		"duration": 0.14,
		"freq": 320.0 * p,
		"freq_end": 780.0 * p,
		"gain": 0.30,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.004,
		"decay": 18.0,
		"noise_gain": 0.10,
	})
	_add_voice({
		"kind": "kalimba",
		"age": 0.0,
		"duration": 0.24,
		"freq": 540.0 * p,
		"freq_end": 620.0 * p,
		"gain": 0.14,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.005,
		"decay": 11.0,
		"noise_gain": 0.0,
	})


func play_hurt() -> void:
	_add_voice({
		"kind": "wobble",
		"age": 0.0,
		"duration": 0.30,
		"freq": 280.0,
		"freq_end": 110.0,
		"gain": 0.32,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.006,
		"decay": 8.5,
		"noise_gain": 0.14,
	})


func play_spit(level: int = 1) -> void:
	var lvl_boost: float = 1.0 + float(clampi(level, 1, 3) - 1) * 0.16
	_add_voice({
		"kind": "organic_pop",
		"age": 0.0,
		"duration": 0.19,
		"freq": 460.0 * lvl_boost,
		"freq_end": 180.0,
		"gain": 0.26,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.005,
		"decay": 13.0,
		"noise_gain": 0.16,
	})


func play_shrink() -> void:
	_add_voice({
		"kind": "kalimba",
		"age": 0.0,
		"duration": 0.28,
		"freq": 680.0,
		"freq_end": 340.0,
		"gain": 0.22,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.005,
		"decay": 9.5,
		"noise_gain": 0.04,
	})


func play_dash(level: int = 1) -> void:
	var base: float = 240.0 + float(clampi(level, 1, 3)) * 55.0
	_add_voice({
		"kind": "whoosh",
		"age": 0.0,
		"duration": 0.28,
		"freq": base,
		"freq_end": base * 2.2,
		"gain": 0.28,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.012,
		"decay": 9.0,
		"noise_gain": 0.18,
	})


func play_heal() -> void:
	var root: float = maxf(320.0, _get_scale_root() * 1.5)
	var notes: Array[float] = [root, root * 1.25, root * 1.5]
	for i in range(notes.size()):
		_add_voice({
			"kind": "kalimba",
			"age": -float(i) * 0.065,
			"duration": 0.45,
			"freq": notes[i],
			"freq_end": notes[i],
			"gain": 0.20,
			"phase": 0.0,
			"phase2": 0.0,
			"attack": 0.006,
			"decay": 6.0,
			"noise_gain": 0.0,
		})


func play_scale_up() -> void:
	var root: float = maxf(300.0, _get_scale_root() * 1.25)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.0, 2.5]
	for i in range(ratios.size()):
		_add_voice({
			"kind": "kalimba",
			"age": -float(i) * 0.07,
			"duration": 0.85,
			"freq": root * ratios[i],
			"freq_end": root * ratios[i],
			"gain": 0.18,
			"phase": 0.0,
			"phase2": 0.0,
			"attack": 0.008,
			"decay": 4.0,
			"noise_gain": 0.01,
		})


func play_chime(pitch_mult: float = 1.0) -> void:
	var freq: float = maxf(360.0, _get_scale_root() * 1.5) * clampf(pitch_mult, 0.6, 2.0)
	_add_voice({
		"kind": "kalimba",
		"age": 0.0,
		"duration": 0.55,
		"freq": freq,
		"freq_end": freq,
		"gain": 0.18,
		"phase": 0.0,
		"phase2": 0.0,
		"attack": 0.006,
		"decay": 5.5,
		"noise_gain": 0.01,
	})


func play_victory() -> void:
	var root: float = 392.0 # G4 bright cosmic sparkle
	var melody: Array[float] = [1.0, 1.125, 1.25, 1.5, 2.0, 2.25, 2.5, 3.0]
	for i in range(melody.size()):
		_add_voice({
			"kind": "kalimba",
			"age": -float(i) * 0.09,
			"duration": 1.1,
			"freq": root * melody[i],
			"freq_end": root * melody[i],
			"gain": 0.17,
			"phase": 0.0,
			"phase2": 0.0,
			"attack": 0.008,
			"decay": 3.4,
			"noise_gain": 0.01,
		})


func _fill_audio_buffer() -> void:
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var inv_sr: float = 1.0 / MIX_RATE
	var frames: PackedVector2Array = PackedVector2Array()
	frames.resize(frames_available)

	for i in range(frames_available):
		var sample_l: float = 0.0
		var sample_r: float = 0.0

		var idx: int = _voices.size() - 1
		while idx >= 0:
			var v: Dictionary = _voices[idx]
			var age: float = float(v["age"]) + inv_sr
			v["age"] = age
			if age < 0.0:
				idx -= 1
				continue

			var dur: float = float(v["duration"])
			if age >= dur:
				_voices.remove_at(idx)
				idx -= 1
				continue

			var t: float = age / dur
			var attack: float = maxf(0.001, float(v["attack"]))
			var env: float = minf(1.0, age / attack) * exp(-age * float(v["decay"]))
			var freq: float = lerpf(float(v["freq"]), float(v["freq_end"]), t)
			var phase: float = float(v["phase"]) + TAU * freq * inv_sr
			if phase > TAU:
				phase -= TAU
			v["phase"] = phase

			var sig: float = 0.0
			var kind: String = String(v["kind"])
			if kind == "kalimba":
				# Warm fundamental + subtle bell-like 2.756x metallic tine overtone
				var phase2: float = float(v["phase2"]) + TAU * (freq * 2.756) * inv_sr
				if phase2 > TAU:
					phase2 -= TAU
				v["phase2"] = phase2
				var overtone_env: float = exp(-age * 18.0)
				sig = sin(phase) + 0.24 * sin(phase2) * overtone_env
			elif kind == "organic_pop":
				sig = sin(phase) + 0.35 * sin(phase * 2.0)
			elif kind == "wobble":
				var lfo: float = 1.0 + 0.14 * sin(age * 46.0)
				sig = sin(phase * lfo) * 0.85
			else:
				sig = sin(phase) * 0.7

			var n_gain: float = float(v["noise_gain"])
			if n_gain > 0.0:
				var noise_env: float = exp(-age * 24.0)
				sig += (_rng.randf() * 2.0 - 1.0) * n_gain * noise_env

			var out_s: float = sig * env * float(v["gain"])
			# Gentle stereo shimmer by voice index
			var pan: float = 0.5 + 0.15 * sin(float(idx) * 1.7)
			sample_l += out_s * (1.0 - pan * 0.35)
			sample_r += out_s * (0.65 + pan * 0.35)
			idx -= 1

		# Soft saturating limiter so multiple overlapping chimes/SFX stay clean
		frames[i] = Vector2(tanh(sample_l), tanh(sample_r))

	_playback.push_buffer(frames)
