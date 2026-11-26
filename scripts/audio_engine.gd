class_name AudioEngine
extends Node
## Real-time procedural audio synthesizer using AudioStreamGenerator.
## Generates chill pentatonic kalimba chimes (zero heavy bass drone) and
## crisp wild organic SFX with zero external MP3/WAV dependencies.

const MIX_RATE: float = 24000.0
const BUFFER_LENGTH: float = 0.085
const MAX_VOICES: int = 24
const DUCKED_GAIN: float = 0.35
const PENTATONIC_RATIOS: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5, 3.0]
const COMBO_RATIOS: Array[float] = [1.0, 1.125, 1.25, 1.40625, 1.5, 1.6875, 2.0]

enum VoiceKind {
	KALIMBA = 0,
	ORGANIC_POP = 1,
	WOBBLE = 2,
	WHOOSH = 3,
	HEARTBEAT = 4,
}


class Voice:
	var kind: int = VoiceKind.KALIMBA
	var t: float = 0.0
	var dur: float = 0.5
	var inv_dur: float = 2.0
	var freq: float = 440.0
	var freq_end: float = 440.0
	var amp: float = 0.15
	var phase: float = 0.0
	var phase2: float = 0.0
	var inv_attack: float = 166.6667
	var decay: float = 5.0
	var noise_gain: float = 0.0
	var pan: float = 0.5
	var pan_l: float = 0.825
	var pan_r: float = 0.825


var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _muted: bool = false
var _app_paused: bool = false
var _ducked: bool = false
var _target_gain: float = 1.0
var _output_gain: float = 1.0
var _scale_index: int = 0

var _voices: Array[Voice] = []
var _chime_timer: float = 0.6
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_note_idx: int = 2
var _voice_seq: int = 0


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
		if not _muted and not _app_paused and not _player.playing:
			_player.play()
			_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _muted:
		_voices.clear()


func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted


func is_muted() -> bool:
	return _muted


func set_ducked(ducked: bool) -> void:
	_ducked = ducked
	_target_gain = DUCKED_GAIN if ducked else 1.0


func set_app_paused(paused: bool) -> void:
	if _app_paused == paused:
		return
	_app_paused = paused
	if _player == null:
		return
	if _app_paused:
		_player.stop()
		_playback = null
		_voices.clear()
	else:
		if not _muted:
			_player.stream_paused = false
			_player.play()
			_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func set_scale_index(idx: int) -> void:
	_scale_index = clampi(idx, 0, Scales.NUM_SCALES - 1)


func _get_scale_root() -> float:
	var scale_dict: Dictionary = Scales.SCALES[_scale_index]
	return float(scale_dict.get("music_root", 261.63))


func _process(delta: float) -> void:
	if _muted or _app_paused or _player == null:
		return

	# Recover automatically from iOS/Android audio session interruptions
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	elif _playback == null:
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

	if _playback == null:
		return

	# Gentle ambient pentatonic kalimba melody (airy, light, zero bass drone)
	_chime_timer -= delta
	if _chime_timer <= 0.0:
		_chime_timer = _rng.randf_range(1.05, 2.25)
		_spawn_ambient_kalimba()

	_fill_audio_buffer()


func _next_pan() -> float:
	_voice_seq += 1
	return 0.5 + 0.15 * sin(float(_voice_seq) * 1.7)


func _create_voice(
	kind: int,
	start_t: float,
	dur: float,
	freq: float,
	freq_end: float,
	amp: float,
	attack: float,
	decay: float,
	noise_gain: float,
	pan: float = -1.0
) -> Voice:
	var v: Voice = Voice.new()
	v.kind = kind
	v.t = start_t
	v.dur = maxf(0.005, dur)
	v.inv_dur = 1.0 / v.dur
	v.freq = freq
	v.freq_end = freq_end
	v.amp = amp
	v.phase = 0.0
	v.phase2 = 0.0
	v.inv_attack = 1.0 / maxf(0.001, attack)
	v.decay = decay
	v.noise_gain = noise_gain
	v.pan = clampf(_next_pan() if pan < 0.0 else pan, 0.0, 1.0)
	v.pan_l = 1.0 - v.pan * 0.35
	v.pan_r = 0.65 + v.pan * 0.35
	return v


func _add_voice(v: Voice) -> void:
	if _muted or _app_paused:
		return
	if _voices.size() >= MAX_VOICES:
		_voices.pop_front()
	_voices.append(v)


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
	_add_voice(_create_voice(
		VoiceKind.KALIMBA,
		0.0,
		_rng.randf_range(0.85, 1.45),
		base_freq,
		base_freq,
		0.11,
		0.008,
		4.2,
		0.02
	))


func play_chomp(combo_step: int = 0) -> void:
	var step_idx: int = clampi(combo_step, 0, COMBO_RATIOS.size() - 1)
	var p: float = COMBO_RATIOS[step_idx]
	_add_voice(_create_voice(
		VoiceKind.ORGANIC_POP,
		0.0,
		0.14,
		320.0 * p,
		780.0 * p,
		0.30,
		0.004,
		18.0,
		0.10
	))
	_add_voice(_create_voice(
		VoiceKind.KALIMBA,
		0.0,
		0.24,
		540.0 * p,
		620.0 * p,
		0.14,
		0.005,
		11.0,
		0.0
	))


func play_hurt() -> void:
	_add_voice(_create_voice(
		VoiceKind.WOBBLE,
		0.0,
		0.30,
		280.0,
		110.0,
		0.32,
		0.006,
		8.5,
		0.14
	))


func play_spit(level: int = 1) -> void:
	var lvl_boost: float = 1.0 + float(clampi(level, 1, 3) - 1) * 0.16
	_add_voice(_create_voice(
		VoiceKind.ORGANIC_POP,
		0.0,
		0.19,
		460.0 * lvl_boost,
		180.0,
		0.26,
		0.005,
		13.0,
		0.16
	))


func play_shrink() -> void:
	_add_voice(_create_voice(
		VoiceKind.KALIMBA,
		0.0,
		0.28,
		680.0,
		340.0,
		0.22,
		0.005,
		9.5,
		0.04
	))


func play_dash(level: int = 1) -> void:
	var base: float = 240.0 + float(clampi(level, 1, 3)) * 55.0
	_add_voice(_create_voice(
		VoiceKind.WHOOSH,
		0.0,
		0.28,
		base,
		base * 2.2,
		0.28,
		0.012,
		9.0,
		0.18
	))


func play_heal() -> void:
	var root: float = maxf(320.0, _get_scale_root() * 1.5)
	var notes: Array[float] = [root, root * 1.25, root * 1.5]
	for i: int in range(notes.size()):
		_add_voice(_create_voice(
			VoiceKind.KALIMBA,
			-float(i) * 0.065,
			0.45,
			notes[i],
			notes[i],
			0.20,
			0.006,
			6.0,
			0.0
		))


func play_scale_up() -> void:
	var root: float = maxf(300.0, _get_scale_root() * 1.25)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.0, 2.5]
	for i: int in range(ratios.size()):
		_add_voice(_create_voice(
			VoiceKind.KALIMBA,
			-float(i) * 0.07,
			0.85,
			root * ratios[i],
			root * ratios[i],
			0.18,
			0.008,
			4.0,
			0.01
		))


func play_chime(pitch_mult: float = 1.0) -> void:
	var freq: float = maxf(360.0, _get_scale_root() * 1.5) * clampf(pitch_mult, 0.6, 2.0)
	_add_voice(_create_voice(
		VoiceKind.KALIMBA,
		0.0,
		0.55,
		freq,
		freq,
		0.18,
		0.006,
		5.5,
		0.01
	))


func play_predator_pulse() -> void:
	# Soft double-thump heartbeat for nearby predator danger
	_add_voice(_create_voice(
		VoiceKind.HEARTBEAT,
		0.0,
		0.16,
		84.0,
		52.0,
		0.22,
		0.010,
		14.0,
		0.0,
		0.5
	))
	_add_voice(_create_voice(
		VoiceKind.HEARTBEAT,
		-0.13,
		0.18,
		72.0,
		46.0,
		0.15,
		0.012,
		12.5,
		0.0,
		0.5
	))


func play_power_evolve() -> void:
	# Sparkling ascending triad + octave chime for power upgrades (Nv.2 / Nv.3)
	var root: float = maxf(380.0, _get_scale_root() * 1.5)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.0]
	for i: int in range(ratios.size()):
		_add_voice(_create_voice(
			VoiceKind.KALIMBA,
			-float(i) * 0.055,
			0.68,
			root * ratios[i],
			root * ratios[i],
			0.19,
			0.005,
			4.5,
			0.01
		))


func play_victory() -> void:
	var root: float = 392.0 # G4 bright cosmic sparkle
	var melody: Array[float] = [1.0, 1.125, 1.25, 1.5, 2.0, 2.25, 2.5, 3.0]
	for i: int in range(melody.size()):
		_add_voice(_create_voice(
			VoiceKind.KALIMBA,
			-float(i) * 0.09,
			1.1,
			root * melody[i],
			root * melody[i],
			0.17,
			0.008,
			3.4,
			0.01
		))


func _fill_audio_buffer() -> void:
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var inv_sr: float = 1.0 / MIX_RATE
	var tau_inv_sr: float = TAU * inv_sr
	var gain_alpha: float = 1.0 - exp(-12.0 * inv_sr)
	var frames: PackedVector2Array = PackedVector2Array()
	frames.resize(frames_available)

	for i: int in range(frames_available):
		_output_gain += (_target_gain - _output_gain) * gain_alpha
		var sample_l: float = 0.0
		var sample_r: float = 0.0

		var idx: int = _voices.size() - 1
		while idx >= 0:
			var v: Voice = _voices[idx]
			var age: float = v.t + inv_sr
			v.t = age
			if age < 0.0:
				idx -= 1
				continue

			if age >= v.dur:
				_voices.remove_at(idx)
				idx -= 1
				continue

			var norm_t: float = age * v.inv_dur
			var env: float = minf(1.0, age * v.inv_attack) * exp(-age * v.decay)
			var freq: float = v.freq + (v.freq_end - v.freq) * norm_t
			var phase: float = v.phase + freq * tau_inv_sr
			if phase > TAU:
				phase -= TAU
			v.phase = phase

			var sig: float = 0.0
			var kind: int = v.kind
			if kind == VoiceKind.KALIMBA:
				# Warm fundamental + subtle bell-like 2.756x metallic tine overtone
				var phase2: float = v.phase2 + (freq * 2.756) * tau_inv_sr
				if phase2 > TAU:
					phase2 -= TAU
				v.phase2 = phase2
				sig = sin(phase) + 0.24 * sin(phase2) * exp(-age * 18.0)
			elif kind == VoiceKind.ORGANIC_POP:
				sig = sin(phase) + 0.35 * sin(phase * 2.0)
			elif kind == VoiceKind.WOBBLE:
				var lfo: float = 1.0 + 0.14 * sin(age * 46.0)
				sig = sin(phase * lfo) * 0.85
			elif kind == VoiceKind.HEARTBEAT:
				sig = sin(phase) * 0.92 + 0.18 * sin(phase * 2.0)
			else:
				sig = sin(phase) * 0.7

			if v.noise_gain > 0.0:
				sig += (_rng.randf() * 2.0 - 1.0) * v.noise_gain * exp(-age * 24.0)

			var out_s: float = sig * env * v.amp
			sample_l += out_s * v.pan_l
			sample_r += out_s * v.pan_r
			idx -= 1

		# Soft saturating limiter with smooth master ducking gain
		frames[i] = Vector2(tanh(sample_l * _output_gain), tanh(sample_r * _output_gain))

	_playback.push_buffer(frames)
