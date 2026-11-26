class_name AudioEngine
extends Node
## Zero-overhead procedural audio engine using pre-baked 16-bit PCM AudioStreamWAV
## clips mixed natively on Godot's C++ audio thread via a 14-player pool.
## Generates warm, lush, toddler-friendly soundscapes with zero external audio assets.

const MIX_RATE: int = 22050
const BASE_NOTE_HZ: float = 261.63 # C4 reference pitch for tonal WAVs
const AMBIENT_POOL_SIZE: int = 4
const SFX_POOL_SIZE: int = 10
const DUCK_DB: float = -9.0
const DUCK_SMOOTH_SPEED: float = 10.0

# Airy Lydian / pentatonic ratios for ambient phrases
const LYDIAN_PENTATONIC: Array[float] = [
	1.0, 1.125, 1.25, 1.40625, 1.5, 1.6667, 2.0, 2.25, 2.5, 3.0
]
const COMBO_RATIOS: Array[float] = [
	1.0, 1.125, 1.25, 1.40625, 1.5, 1.6875, 2.0
]


class QueuedNote:
	var delay: float = 0.0
	var stream: AudioStreamWAV = null
	var pitch_scale: float = 1.0
	var volume_db: float = -6.0
	var is_ambient: bool = false


# Pre-baked 16-bit mono PCM streams (baked once in _ready)
var _wav_kalimba: AudioStreamWAV = null
var _wav_rhodes: AudioStreamWAV = null
var _wav_harp: AudioStreamWAV = null
var _wav_chomp: AudioStreamWAV = null
var _wav_spit: AudioStreamWAV = null
var _wav_dash: AudioStreamWAV = null
var _wav_hurt: AudioStreamWAV = null
var _wav_heartbeat: AudioStreamWAV = null

# Native AudioStreamPlayer pools (4 ambient + 10 SFX = 14 total)
var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_base_dbs: Array[float] = []
var _ambient_cursor: int = 0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0

# Lightweight scheduled event queue for arpeggios, chords, and phrases
var _queue: Array[QueuedNote] = []

var _muted: bool = false
var _app_paused: bool = false
var _ducked: bool = false
var _target_duck_db: float = 0.0
var _current_duck_db: float = 0.0
var _scale_index: int = 0

var _chime_timer: float = 0.7
var _last_note_idx: int = 2
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_bake_all_clips()
	_init_player_pools()


func _init_player_pools() -> void:
	_ambient_players.clear()
	_ambient_base_dbs.clear()
	for i: int in range(AMBIENT_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "AmbientPlayer_%d" % i
		p.volume_db = -14.0
		add_child(p)
		_ambient_players.append(p)
		_ambient_base_dbs.append(-14.0)

	_sfx_players.clear()
	for i: int in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)


func _bake_all_clips() -> void:
	_wav_kalimba = _bake_kalimba()
	_wav_rhodes = _bake_rhodes()
	_wav_harp = _bake_harp()
	_wav_chomp = _bake_chomp()
	_wav_spit = _bake_spit()
	_wav_dash = _bake_dash()
	_wav_hurt = _bake_hurt()
	_wav_heartbeat = _bake_heartbeat()


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _bake_kalimba() -> AudioStreamWAV:
	# Warm woody kalimba/marimba pluck tuned to C4 (261.63 Hz)
	var num_samples: int = int(0.48 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var dw1: float = TAU * BASE_NOTE_HZ * inv_sr
	var c1_step: float = cos(dw1)
	var s1_step: float = sin(dw1)
	var dwt: float = TAU * BASE_NOTE_HZ * 2.756 * inv_sr
	var ct_step: float = cos(dwt)
	var st_step: float = sin(dwt)

	var s1: float = 0.0
	var c1: float = 1.0
	var st: float = 0.0
	var ct: float = 1.0
	var env1: float = 19800.0
	var env2: float = 6400.0
	var env3: float = 4200.0
	var dec1: float = exp(-5.2 * inv_sr)
	var dec2: float = exp(-12.0 * inv_sr)
	var dec3: float = exp(-19.0 * inv_sr)

	var attack_len: int = 90
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 220
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var sig: float = s1 * env1 + (2.0 * s1 * c1) * env2 + (s1 * (3.0 - 4.0 * s1 * s1) * 0.35 + st * 0.65) * env3
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, int(sig))
		b += 2

		var ns1: float = s1 * c1_step + c1 * s1_step
		c1 = c1 * c1_step - s1 * s1_step
		s1 = ns1
		var nst: float = st * ct_step + ct * st_step
		ct = ct * ct_step - st * st_step
		st = nst
		env1 *= dec1
		env2 *= dec2
		env3 *= dec3
	return _make_wav(data)


func _bake_rhodes() -> AudioStreamWAV:
	# Warm glassy electric-piano / celesta bell tone tuned to C4 (261.63 Hz)
	var num_samples: int = int(0.56 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var dw1: float = TAU * BASE_NOTE_HZ * inv_sr
	var c1_step: float = cos(dw1)
	var s1_step: float = sin(dw1)
	var dwb: float = TAU * (BASE_NOTE_HZ * 1.003) * inv_sr
	var cb_step: float = cos(dwb)
	var sb_step: float = sin(dwb)

	var s1: float = 0.0
	var c1: float = 1.0
	var sb: float = 0.0
	var cb: float = 1.0
	var env1: float = 16500.0
	var env2: float = 5800.0
	var env_bell: float = 3600.0
	var dec1: float = exp(-3.8 * inv_sr)
	var dec2: float = exp(-7.2 * inv_sr)
	var dec_bell: float = exp(-16.0 * inv_sr)

	var attack_len: int = 140
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 240
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var s2: float = 2.0 * s1 * c1
		var sig: float = (s1 * 0.76 + sb * 0.24) * env1 + s2 * env2 + (2.0 * s2 * (1.0 - 2.0 * s1 * s1)) * env_bell
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, int(sig))
		b += 2

		var ns1: float = s1 * c1_step + c1 * s1_step
		c1 = c1 * c1_step - s1 * s1_step
		s1 = ns1
		var nsb: float = sb * cb_step + cb * sb_step
		cb = cb * cb_step - sb * sb_step
		sb = nsb
		env1 *= dec1
		env2 *= dec2
		env_bell *= dec_bell
	return _make_wav(data)


func _bake_harp() -> AudioStreamWAV:
	# Airy crystalline harp pluck tuned to C4 (261.63 Hz)
	var num_samples: int = int(0.50 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var dw1: float = TAU * BASE_NOTE_HZ * inv_sr
	var c1_step: float = cos(dw1)
	var s1_step: float = sin(dw1)

	var s1: float = 0.0
	var c1: float = 1.0
	var env1: float = 16800.0
	var env2: float = 7800.0
	var env3: float = 3900.0
	var dec1: float = exp(-4.4 * inv_sr)
	var dec2: float = exp(-8.0 * inv_sr)
	var dec3: float = exp(-14.5 * inv_sr)

	var attack_len: int = 80
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 220
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var s2: float = 2.0 * s1 * c1
		var s3: float = s1 * (3.0 - 4.0 * s1 * s1)
		var sig: float = s1 * env1 + s2 * env2 + s3 * env3
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, int(sig))
		b += 2

		var ns1: float = s1 * c1_step + c1 * s1_step
		c1 = c1 * c1_step - s1 * s1_step
		s1 = ns1
		env1 *= dec1
		env2 *= dec2
		env3 *= dec3
	return _make_wav(data)


func _bake_chomp() -> AudioStreamWAV:
	# Juicy organic water-droplet / marimba pop (upward pitch glide + harmonic pop)
	var num_samples: int = int(0.14 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var inv_n: float = 1.0 / float(num_samples)
	var tau_inv_sr: float = TAU * inv_sr
	var phase: float = 0.0
	var env: float = 22000.0
	var env_h2: float = 0.36
	var dec: float = exp(-18.5 * inv_sr)
	var dec_h2: float = exp(-25.0 * inv_sr)
	var attack_len: int = 64
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 140
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var u: float = float(i) * inv_n
		phase += (310.0 + 510.0 * u * u) * tau_inv_sr
		var sig: float = (sin(phase) + sin(phase * 2.0) * env_h2) * env
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, int(sig))
		b += 2
		env *= dec
		env_h2 *= dec_h2
	return _make_wav(data)


func _bake_spit() -> AudioStreamWAV:
	# Warm lava whoosh + crisp sizzle burst
	var num_samples: int = int(0.18 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var inv_n: float = 1.0 / float(num_samples)
	var tau_inv_sr: float = TAU * inv_sr
	var phase: float = 0.0
	var lp_noise: float = 0.0
	var noise_state: int = 9876543
	var env_body: float = 18500.0
	var env_sizzle: float = 10500.0
	var dec_body: float = exp(-14.0 * inv_sr)
	var dec_sizzle: float = exp(-20.0 * inv_sr)
	var attack_len: int = 80
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 180
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var u: float = float(i) * inv_n
		phase += (470.0 - 300.0 * u) * tau_inv_sr
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var raw_n: float = float(noise_state) * 9.3132257e-10 - 1.0
		lp_noise += (raw_n - lp_noise) * 0.35
		var sig: float = (sin(phase) + sin(phase * 2.0) * 0.30) * env_body + (raw_n - lp_noise * 0.55) * env_sizzle
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, clampi(int(sig), -32768, 32767))
		b += 2
		env_body *= dec_body
		env_sizzle *= dec_sizzle
	return _make_wav(data)


func _bake_dash() -> AudioStreamWAV:
	# Airy resonant shimmer whoosh + soft sub-thump
	var num_samples: int = int(0.22 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var inv_n: float = 1.0 / float(num_samples)
	var tau_inv_sr: float = TAU * inv_sr
	var phase_shimmer: float = 0.0
	var phase_sub: float = 0.0
	var lp_noise: float = 0.0
	var noise_state: int = 4567891
	var env_whoosh: float = 14500.0
	var env_sub: float = 12500.0
	var dec_whoosh: float = exp(-10.5 * inv_sr)
	var dec_sub: float = exp(-18.5 * inv_sr)
	var attack_len: int = 180
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 200
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var u: float = float(i) * inv_n
		phase_shimmer += (260.0 + 360.0 * u) * tau_inv_sr
		phase_sub += (105.0 - 48.0 * u) * tau_inv_sr
		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var raw_n: float = float(noise_state) * 9.3132257e-10 - 1.0
		lp_noise += (raw_n - lp_noise) * 0.24
		var sig: float = (sin(phase_shimmer) * 0.75 + lp_noise * 0.72) * env_whoosh + sin(phase_sub) * env_sub
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, clampi(int(sig), -32768, 32767))
		b += 2
		env_whoosh *= dec_whoosh
		env_sub *= dec_sub
	return _make_wav(data)


func _bake_hurt() -> AudioStreamWAV:
	# Gentle cartoon rubbery downward wobble (warm, toddler-friendly)
	var num_samples: int = int(0.26 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var inv_n: float = 1.0 / float(num_samples)
	var tau_inv_sr: float = TAU * inv_sr
	var phase: float = 0.0
	var lfo_s: float = 0.0
	var lfo_c: float = 1.0
	var lfo_dw: float = 44.0 * inv_sr
	var lfo_cs: float = cos(lfo_dw)
	var lfo_ss: float = sin(lfo_dw)
	var env: float = 23500.0
	var dec: float = exp(-9.0 * inv_sr)
	var attack_len: int = 110
	var inv_attack: float = 1.0 / float(attack_len)
	var fade_len: int = 220
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var u: float = float(i) * inv_n
		phase += ((275.0 - 160.0 * u) * (1.0 + 0.14 * lfo_s)) * tau_inv_sr
		var sig: float = (sin(phase) + sin(phase * 2.0) * 0.18) * env
		if i < attack_len:
			sig *= float(i) * inv_attack
		elif i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, int(sig))
		b += 2
		var nlfo: float = lfo_s * lfo_cs + lfo_c * lfo_ss
		lfo_c = lfo_c * lfo_cs - lfo_s * lfo_ss
		lfo_s = nlfo
		env *= dec
	return _make_wav(data)


func _bake_heartbeat() -> AudioStreamWAV:
	# Soft warm low double-thump for predator proximity
	var num_samples: int = int(0.29 * float(MIX_RATE))
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples * 2)
	var inv_sr: float = 1.0 / float(MIX_RATE)
	var tau_inv_sr: float = TAU * inv_sr
	var thump1_end: int = int(0.14 * float(MIX_RATE))
	var thump2_start: int = int(0.12 * float(MIX_RATE))
	var inv_t1: float = 1.0 / float(thump1_end)
	var inv_t2: float = 1.0 / float(num_samples - thump2_start)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var env1: float = 22500.0
	var env2: float = 16500.0
	var dec1: float = exp(-15.5 * inv_sr)
	var dec2: float = exp(-14.0 * inv_sr)
	var att1_len: int = 190
	var inv_att1: float = 1.0 / float(att1_len)
	var att2_len: int = 220
	var inv_att2: float = 1.0 / float(att2_len)
	var fade_len: int = 200
	var fade_start: int = num_samples - fade_len
	var inv_fade: float = 1.0 / float(fade_len)
	var b: int = 0

	for i: int in range(num_samples):
		var sig: float = 0.0
		if i < thump1_end:
			phase1 += (84.0 - 32.0 * (float(i) * inv_t1)) * tau_inv_sr
			var a1: float = float(i) * inv_att1 if i < att1_len else 1.0
			sig += sin(phase1) * a1 * env1
			env1 *= dec1

		if i >= thump2_start:
			var j: int = i - thump2_start
			phase2 += (72.0 - 26.0 * (float(j) * inv_t2)) * tau_inv_sr
			var a2: float = float(j) * inv_att2 if j < att2_len else 1.0
			sig += sin(phase2) * a2 * env2
			env2 *= dec2

		if i >= fade_start:
			sig *= float(num_samples - i) * inv_fade
		data.encode_s16(b, clampi(int(sig), -32768, 32767))
		b += 2
	return _make_wav(data)


func set_muted(m: bool) -> void:
	_muted = m
	if _muted:
		_queue.clear()
		_stop_all_players()


func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted


func is_muted() -> bool:
	return _muted


func set_ducked(ducked: bool) -> void:
	_ducked = ducked
	_target_duck_db = DUCK_DB if ducked else 0.0


func set_app_paused(paused: bool) -> void:
	if _app_paused == paused:
		return
	_app_paused = paused
	if _app_paused:
		_queue.clear()
		for p: AudioStreamPlayer in _ambient_players:
			if p.playing:
				p.stream_paused = true
		for p: AudioStreamPlayer in _sfx_players:
			p.stop()
	else:
		if not _muted:
			for p: AudioStreamPlayer in _ambient_players:
				if p.stream_paused:
					p.stream_paused = false
			if _chime_timer < 0.35:
				_chime_timer = 0.55


func set_scale_index(idx: int) -> void:
	_scale_index = clampi(idx, 0, Scales.NUM_SCALES - 1)


func _get_scale_root() -> float:
	var scale_dict: Dictionary = Scales.SCALES[_scale_index]
	return float(scale_dict.get("music_root", BASE_NOTE_HZ))


func _stop_all_players() -> void:
	for p: AudioStreamPlayer in _ambient_players:
		p.stop()
		p.stream_paused = false
	for p: AudioStreamPlayer in _sfx_players:
		p.stop()
		p.stream_paused = false


func _process(delta: float) -> void:
	if _muted or _app_paused:
		return

	# Smoothly duck/unduck ambient players (~9 dB down when paused/defeat)
	if absf(_current_duck_db - _target_duck_db) > 0.01:
		var alpha: float = 1.0 - exp(-DUCK_SMOOTH_SPEED * delta)
		_current_duck_db = lerpf(_current_duck_db, _target_duck_db, alpha)
		if absf(_current_duck_db - _target_duck_db) <= 0.01:
			_current_duck_db = _target_duck_db
		for i: int in range(_ambient_players.size()):
			_ambient_players[i].volume_db = _ambient_base_dbs[i] + _current_duck_db

	# Ambient Lydian / pentatonic phrase scheduler
	_chime_timer -= delta
	if _chime_timer <= 0.0:
		_chime_timer = _rng.randf_range(1.15, 2.35)
		_spawn_ambient_phrase()

	# Lightweight scheduled event queue (0-5 items typical -> ~0.002 ms/frame)
	var q_idx: int = _queue.size() - 1
	while q_idx >= 0:
		var item: QueuedNote = _queue[q_idx]
		item.delay -= delta
		if item.delay <= 0.0:
			_queue.remove_at(q_idx)
			if item.is_ambient:
				_play_on_ambient(item.stream, item.pitch_scale, item.volume_db)
			else:
				_play_on_sfx(item.stream, item.pitch_scale, item.volume_db)
		q_idx -= 1


func _play_on_ambient(stream: AudioStreamWAV, pitch_scale: float, base_db: float) -> void:
	if _muted or _app_paused or stream == null or _ambient_players.is_empty():
		return
	var idx: int = _ambient_cursor
	_ambient_cursor = (_ambient_cursor + 1) % _ambient_players.size()
	var p: AudioStreamPlayer = _ambient_players[idx]
	_ambient_base_dbs[idx] = base_db
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	p.volume_db = base_db + _current_duck_db
	p.stream_paused = false
	p.play()


func _play_on_sfx(stream: AudioStreamWAV, pitch_scale: float, vol_db: float) -> void:
	if _muted or _app_paused or stream == null or _sfx_players.is_empty():
		return
	var chosen: AudioStreamPlayer = null
	for i: int in range(_sfx_players.size()):
		var candidate: AudioStreamPlayer = _sfx_players[(_sfx_cursor + i) % _sfx_players.size()]
		if not candidate.playing:
			chosen = candidate
			_sfx_cursor = (_sfx_cursor + i + 1) % _sfx_players.size()
			break
	if chosen == null:
		chosen = _sfx_players[_sfx_cursor]
		_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	chosen.stream = stream
	chosen.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	chosen.volume_db = vol_db
	chosen.stream_paused = false
	chosen.play()


func _schedule_note(
	delay: float,
	stream: AudioStreamWAV,
	pitch_scale: float,
	vol_db: float,
	is_ambient: bool = false
) -> void:
	if _muted or _app_paused or stream == null:
		return
	if delay <= 0.0:
		if is_ambient:
			_play_on_ambient(stream, pitch_scale, vol_db)
		else:
			_play_on_sfx(stream, pitch_scale, vol_db)
		return
	var item: QueuedNote = QueuedNote.new()
	item.delay = delay
	item.stream = stream
	item.pitch_scale = pitch_scale
	item.volume_db = vol_db
	item.is_ambient = is_ambient
	_queue.append(item)


func _pick_ambient_stream(secondary: bool = false) -> AudioStreamWAV:
	# Smooth timbre progression across the 6 scales:
	# 0 Quantum & 1 Micro: kalimba
	# 2 Forest: harp + kalimba
	# 3 City & 4 Planetary: warm Rhodes
	# 5 Cosmic: harp + Rhodes
	match _scale_index:
		0, 1:
			return _wav_kalimba
		2:
			return _wav_kalimba if secondary else _wav_harp
		3, 4:
			return _wav_rhodes
		_:
			return _wav_rhodes if secondary else _wav_harp


func _spawn_ambient_phrase() -> void:
	var step: int = _rng.randi_range(-2, 2)
	if step == 0:
		step = 1
	_last_note_idx = clampi(_last_note_idx + step, 0, LYDIAN_PENTATONIC.size() - 1)
	var root: float = _get_scale_root()
	var base_freq: float = root * LYDIAN_PENTATONIC[_last_note_idx]
	if base_freq < 260.0:
		base_freq *= 2.0

	var primary_wav: AudioStreamWAV = _pick_ambient_stream(false)
	var base_db: float = _rng.randf_range(-15.0, -12.8)
	_play_on_ambient(primary_wav, base_freq / BASE_NOTE_HZ, base_db)

	# Occasional gentle 2-note Lydian answer / shimmer for Forest, Planetary, Cosmic
	if _rng.randf() < 0.36:
		var next_idx: int = clampi(_last_note_idx + (_rng.randi_range(1, 2)), 0, LYDIAN_PENTATONIC.size() - 1)
		var next_freq: float = root * LYDIAN_PENTATONIC[next_idx]
		if next_freq < 260.0:
			next_freq *= 2.0
		var accent_wav: AudioStreamWAV = _pick_ambient_stream(true)
		_schedule_note(
			_rng.randf_range(0.18, 0.30),
			accent_wav,
			next_freq / BASE_NOTE_HZ,
			base_db - 2.2,
			true
		)


func play_chomp(combo_step: int = 0) -> void:
	var step_idx: int = clampi(combo_step, 0, COMBO_RATIOS.size() - 1)
	var p: float = COMBO_RATIOS[step_idx]
	_play_on_sfx(_wav_chomp, p, -5.0)
	_play_on_sfx(_wav_kalimba, (523.25 * p) / BASE_NOTE_HZ, -11.5)


func play_spit(level: int = 1) -> void:
	var lvl_boost: float = 1.0 + float(clampi(level, 1, 3) - 1) * 0.14
	var vol_db: float = -6.0 + float(clampi(level, 1, 3) - 1) * 1.0
	_play_on_sfx(_wav_spit, lvl_boost, vol_db)


func play_dash(level: int = 1) -> void:
	var lvl_boost: float = 1.0 + float(clampi(level, 1, 3) - 1) * 0.15
	var vol_db: float = -5.5 + float(clampi(level, 1, 3) - 1) * 1.0
	_play_on_sfx(_wav_dash, lvl_boost, vol_db)


func play_hurt() -> void:
	_play_on_sfx(_wav_hurt, 1.0, -5.0)


func play_shrink() -> void:
	_play_on_sfx(_wav_kalimba, 660.0 / BASE_NOTE_HZ, -8.5)
	_schedule_note(0.06, _wav_kalimba, 440.0 / BASE_NOTE_HZ, -10.5, false)


func play_heal() -> void:
	var root: float = maxf(320.0, _get_scale_root() * 1.5)
	var notes: Array[float] = [root, root * 1.25, root * 1.5]
	for i: int in range(notes.size()):
		var wav: AudioStreamWAV = _wav_harp if i == 2 else _wav_kalimba
		_schedule_note(float(i) * 0.065, wav, notes[i] / BASE_NOTE_HZ, -8.0, false)


func play_chime(pitch_mult: float = 1.0) -> void:
	var freq: float = maxf(360.0, _get_scale_root() * 1.5) * clampf(pitch_mult, 0.6, 2.0)
	var wav: AudioStreamWAV = _pick_ambient_stream(false)
	_play_on_sfx(wav, freq / BASE_NOTE_HZ, -9.0)


func play_scale_up() -> void:
	var root: float = maxf(300.0, _get_scale_root() * 1.25)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.0, 2.5]
	for i: int in range(ratios.size()):
		var wav: AudioStreamWAV = _wav_harp if (i % 2 == 1) else _wav_kalimba
		_schedule_note(
			float(i) * 0.07,
			wav,
			(root * ratios[i]) / BASE_NOTE_HZ,
			-7.5,
			false
		)


func play_victory() -> void:
	var root: float = 392.0 # G4 bright cosmic sparkle
	var melody: Array[float] = [1.0, 1.125, 1.25, 1.5, 2.0, 2.25, 2.5, 3.0]
	for i: int in range(melody.size()):
		var wav: AudioStreamWAV = _wav_harp if (i % 2 == 0) else _wav_rhodes
		_schedule_note(
			float(i) * 0.09,
			wav,
			(root * melody[i]) / BASE_NOTE_HZ,
			-7.0,
			false
		)


func play_predator_pulse() -> void:
	_play_on_sfx(_wav_heartbeat, 1.0, -6.5)


func play_power_evolve() -> void:
	# Sparkling ascending triad + octave chime for power upgrades (Nv.2 / Nv.3)
	var root: float = maxf(380.0, _get_scale_root() * 1.5)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.0]
	for i: int in range(ratios.size()):
		var wav: AudioStreamWAV = _wav_rhodes if i < 2 else _wav_harp
		_schedule_note(
			float(i) * 0.055,
			wav,
			(root * ratios[i]) / BASE_NOTE_HZ,
			-7.5,
			false
		)
