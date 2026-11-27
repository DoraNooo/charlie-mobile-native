class_name AudioEngine
extends Node
## Dreamy Studio Ghibli (Joe Hisaishi x Ori x GRIS) procedural audio engine.
## Pre-bakes lush 16-bit stereo PCM AudioStreamWAV instruments, a seamless 6.0 s
## orchestral glass-choir pad, and poetic tactile SFX once in _ready(), mixed
## natively on Godot's C++ audio thread through dedicated DreamMusic & DreamSfx
## reverb/chorus/LPF buses (0.00 ms/frame DSP, zero external audio assets).

const MIX_RATE: int = 24000
const BASE_NOTE_HZ: float = 261.63 # C4 reference pitch for tonal instruments
const PAD_BASE_HZ: float = 131.0   # C3 exact integer-cycle pad pitch (262 cycles / 2.0 s)
const PCM_CLAMP: int = 30000

const BUS_DREAM_MUSIC: StringName = &"DreamMusic"
const BUS_DREAM_SFX: StringName = &"DreamSfx"

const PAD_VOICES: int = 2
const AMBIENT_POOL_SIZE: int = 8
const SFX_POOL_SIZE: int = 12
const DUCK_DB: float = -9.0
const DUCK_SMOOTH_SPEED: float = 8.0
const PAD_PITCH_SMOOTH_SPEED: float = 1.4

# Joe Hisaishi Major 9th & Lydian voicing (1, 9, 3, #11, 5, 6, maj7, 8, 9', 3')
const LYDIAN_MAJ9: Array[float] = [
	1.0, 1.125, 1.25, 1.40625, 1.5, 1.6667, 1.875, 2.0, 2.25, 2.5
]

# Ascending pentatonic ratios for joyful combo chomps (never harsh or dissonant)
const COMBO_RATIOS: Array[float] = [
	1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25
]

# 6 curated Joe Hisaishi-style poetic 4-note & 5-note motifs (indices into LYDIAN_MAJ9)
const POETIC_MOTIFS: Array[Array] = [
	[0, 2, 4, 6],       # Rising Maj7 wonder
	[4, 2, 1, 0],       # Tender lullaby descent home
	[0, 4, 6, 7, 4],    # Hisaishi summer arch
	[2, 4, 7, 6],       # Floating nocturnal lanterns
	[1, 2, 4, 5, 4],    # Pastoral forest dewdrop
	[0, 1, 3, 4, 8],    # Shimmering Lydian starlight
]


class QueuedNote:
	var delay: float = 0.0
	var stream: AudioStreamWAV = null
	var pitch_scale: float = 1.0
	var volume_db: float = -10.0
	var is_ambient: bool = false


# Pre-baked 16-bit stereo PCM streams (baked once in _ready)
var _wav_pad: AudioStreamWAV = null
var _wav_felt_piano: AudioStreamWAV = null
var _wav_celesta: AudioStreamWAV = null
var _wav_silk_harp: AudioStreamWAV = null
var _wav_droplet: AudioStreamWAV = null
var _wav_spit: AudioStreamWAV = null
var _wav_dash: AudioStreamWAV = null
var _wav_hurt: AudioStreamWAV = null
var _wav_heartbeat: AudioStreamWAV = null

# Native AudioStreamPlayer pools (2 pad + 8 ambient + 12 SFX = 22 total)
var _pad_players: Array[AudioStreamPlayer] = []
var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_base_dbs: Array[float] = []
var _ambient_cursor: int = 0
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0

# Lightweight scheduled event queue for arpeggios, chords, and rubato phrases
var _queue: Array[QueuedNote] = []

var _muted: bool = false
var _app_paused: bool = false
var _ducked: bool = false
var _target_duck_db: float = 0.0
var _current_duck_db: float = 0.0
var _scale_index: int = 0

# Ethereal pad state (smooth pitch glide, slow stereo crossfade & soft startup bloom)
var _target_pad_pitch: float = 1.0
var _current_pad_pitch: float = 1.0
var _pad_breath_phase: float = 0.0
var _pad_fade_gain: float = 0.0

# Composed phrase scheduler state
var _phrase_timer: float = 1.1
var _phrase_counter: int = 0
var _last_motif_idx: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_init_audio_buses()
	_bake_all_clips()
	_target_pad_pitch = _compute_pad_pitch_for_scale(_scale_index)
	_current_pad_pitch = _target_pad_pitch
	_init_player_pools()
	if not _muted and not _app_paused:
		_start_pads()


func _init_audio_buses() -> void:
	# Dedicated DreamMusic bus: warm velvet LPF + lush 2-voice chorus + concert-hall reverb
	var music_idx: int = AudioServer.get_bus_index(BUS_DREAM_MUSIC)
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, BUS_DREAM_MUSIC)
		AudioServer.set_bus_send(music_idx, &"Master")
	if AudioServer.get_bus_effect_count(music_idx) == 0:
		var music_lpf: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		music_lpf.cutoff_hz = 4200.0
		music_lpf.resonance = 0.5
		music_lpf.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(music_idx, music_lpf)

		var music_chorus: AudioEffectChorus = AudioEffectChorus.new()
		music_chorus.voice_count = 2
		music_chorus.wet = 0.24
		music_chorus.dry = 0.85
		music_chorus.set_voice_delay_ms(0, 16.0)
		music_chorus.set_voice_rate_hz(0, 0.32)
		music_chorus.set_voice_depth_ms(0, 2.0)
		music_chorus.set_voice_level_db(0, -2.5)
		music_chorus.set_voice_pan(0, -0.55)
		music_chorus.set_voice_delay_ms(1, 24.0)
		music_chorus.set_voice_rate_hz(1, 0.23)
		music_chorus.set_voice_depth_ms(1, 2.6)
		music_chorus.set_voice_level_db(1, -2.5)
		music_chorus.set_voice_pan(1, 0.55)
		AudioServer.add_bus_effect(music_idx, music_chorus)

		var music_reverb: AudioEffectReverb = AudioEffectReverb.new()
		music_reverb.room_size = 0.84
		music_reverb.damping = 0.62
		music_reverb.spread = 0.92
		music_reverb.wet = 0.44
		music_reverb.dry = 0.78
		music_reverb.hipass = 0.08
		music_reverb.predelay_msec = 22.0
		music_reverb.predelay_feedback = 0.14
		AudioServer.add_bus_effect(music_idx, music_reverb)

	# Dedicated DreamSfx bus: silky warmth LPF + cohesive poetic hall bloom
	var sfx_idx: int = AudioServer.get_bus_index(BUS_DREAM_SFX)
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, BUS_DREAM_SFX)
		AudioServer.set_bus_send(sfx_idx, &"Master")
	if AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var sfx_lpf: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		sfx_lpf.cutoff_hz = 5200.0
		sfx_lpf.resonance = 0.5
		sfx_lpf.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(sfx_idx, sfx_lpf)

		var sfx_reverb: AudioEffectReverb = AudioEffectReverb.new()
		sfx_reverb.room_size = 0.62
		sfx_reverb.damping = 0.65
		sfx_reverb.spread = 0.78
		sfx_reverb.wet = 0.28
		sfx_reverb.dry = 0.86
		sfx_reverb.hipass = 0.06
		sfx_reverb.predelay_msec = 12.0
		sfx_reverb.predelay_feedback = 0.10
		AudioServer.add_bus_effect(sfx_idx, sfx_reverb)


func _init_player_pools() -> void:
	_pad_players.clear()
	for i: int in range(PAD_VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "DreamPad_%d" % i
		p.bus = BUS_DREAM_MUSIC
		p.stream = _wav_pad
		p.volume_db = -48.0
		p.pitch_scale = _current_pad_pitch
		add_child(p)
		_pad_players.append(p)

	_ambient_players.clear()
	_ambient_base_dbs.clear()
	for i: int in range(AMBIENT_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "AmbientPlayer_%d" % i
		p.bus = BUS_DREAM_MUSIC
		p.volume_db = -16.0
		add_child(p)
		_ambient_players.append(p)
		_ambient_base_dbs.append(-16.0)

	_sfx_players.clear()
	for i: int in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		p.bus = BUS_DREAM_SFX
		p.volume_db = -10.0
		add_child(p)
		_sfx_players.append(p)


func _bake_all_clips() -> void:
	_wav_pad = _bake_ethereal_pad()
	_wav_felt_piano = _bake_felt_piano()
	_wav_celesta = _bake_celesta()
	_wav_silk_harp = _bake_silk_harp()
	_wav_droplet = _bake_droplet()
	_wav_spit = _bake_ember_breath()
	_wav_dash = _bake_silk_glide()
	_wav_hurt = _bake_cello_sigh()
	_wav_heartbeat = _bake_velvet_heartbeat()


func _make_stereo_wav(
	data: PackedByteArray,
	loop_forward: bool = false,
	loop_end_frames: int = 0
) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = true
	wav.data = data
	if loop_forward and loop_end_frames > 0:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = loop_end_frames
	return wav


func _bake_ethereal_pad() -> AudioStreamWAV:
	# Seamless 6.0-second stereo velvet string/glass-choir pad tuned to C3 (131.0 Hz).
	# Bakes a 2.0-second exact-integer-cycle stereo tile (1x=262, 1.5x=393, 2x=524,
	# 2.5x=655 just major third, 3x=786, slow LFO=1 cycle -> exact +/-0.5 Hz stereo
	# ensemble detune) at 3 kHz exact-recurrence steps upsampled 8x to 24 kHz
	# (highest partial 393 Hz is 3.8x below 1.5 kHz Nyquist), then tiles 3x in C++ for
	# a 144,000-frame (6.0 s) mathematically 100% click-free LOOP_FORWARD bed.
	const STRIDE: int = 8
	var tile_samples: int = 2 * MIX_RATE # 48,000 frames (2.0 s)
	var num_steps: int = tile_samples / STRIDE # 6,000 oscillator steps
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(tile_samples)
	var inv_steps: float = 1.0 / float(num_steps)

	var dw1: float = TAU * 262.0 * inv_steps
	var c1s: float = cos(dw1)
	var s1s: float = sin(dw1)

	var dw5: float = TAU * 393.0 * inv_steps
	var c5s: float = cos(dw5)
	var s5s: float = sin(dw5)

	var dw3: float = TAU * 655.0 * inv_steps
	var c3s: float = cos(dw3)
	var s3s: float = sin(dw3)

	var dwl: float = TAU * inv_steps # Exact 1 cycle over 2.0 s
	var cls: float = cos(dwl)
	var sls: float = sin(dwl)

	var s1: float = 0.0
	var c1: float = 1.0
	var s5: float = 0.0
	var c5: float = 1.0
	var s3: float = 0.0
	var c3: float = 1.0
	var sl: float = 0.0
	var cl: float = 1.0

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	# Max possible sum is 21,800 (strictly inside [-30000, 30000])
	for _k: int in range(num_steps):
		var ns1: float = s1 * c1s + c1 * s1s
		c1 = c1 * c1s - s1 * s1s
		s1 = ns1
		var ns5: float = s5 * c5s + c5 * s5s
		c5 = c5 * c5s - s5 * s5s
		s5 = ns5
		var ns3: float = s3 * c3s + c3 * s3s
		c3 = c3 * c3s - s3 * s3s
		s3 = ns3
		var nsl: float = sl * cls + cl * sls
		cl = cl * cls - sl * sls
		sl = nsl

		# Exact +/-1 cycle stereo ensemble pairs via angle addition
		var f1_l: float = s1 * cl + c1 * sl
		var f1_r: float = s1 * cl - c1 * sl
		var f5_l: float = s5 * cl - c5 * sl
		var f5_r: float = s5 * cl + c5 * sl
		var f3_l: float = s3 * cl + c3 * sl
		var f3_r: float = s3 * cl - c3 * sl

		var s2: float = 2.0 * s1 * c1
		var s_oct5: float = s1 * (3.0 - 4.0 * s1 * s1)
		var breath_l: float = 0.91 + 0.09 * cl
		var breath_r: float = 0.91 + 0.09 * sl

		var curr_l: float = (
			s1 * 5600.0 + f1_l * 3600.0 + f5_l * 4900.0
			+ s2 * 4300.0 + f3_l * 1950.0 + s_oct5 * 1450.0
		) * breath_l
		var curr_r: float = (
			s1 * 5600.0 + f1_r * 3600.0 + f5_r * 4900.0
			+ s2 * 4300.0 + f3_r * 1950.0 + s_oct5 * 1450.0
		) * breath_r

		var dl: float = (curr_l - prev_l) * 0.125
		var dr: float = (curr_r - prev_r) * 0.125
		var lx: float = prev_l
		var rx: float = prev_r

		ints[out_idx] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 1] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 2] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 3] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 4] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 5] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 6] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 7] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)

		out_idx += 8
		prev_l = curr_l
		prev_r = curr_r

	var tile_bytes: PackedByteArray = ints.to_byte_array()
	var full_data: PackedByteArray = PackedByteArray()
	full_data.append_array(tile_bytes)
	full_data.append_array(tile_bytes)
	full_data.append_array(tile_bytes)
	return _make_stereo_wav(full_data, true, tile_samples * 3)


func _bake_felt_piano() -> AudioStreamWAV:
	# Intimate Joe Hisaishi / Nils Frahm felted upright piano tuned to C4 (261.63 Hz).
	# Warm 28 ms felt-hammer attack, gentle stereo unison pair, fast upper-harmonic
	# mellowing, and a lush 1.5 s singing sustain (computed at 6 kHz -> 4x linear
	# upsample to 24 kHz; highest partial 1046 Hz is 2.9x below 3 kHz Nyquist).
	var num_steps: int = int(1.5 * float(MIX_RATE) * 0.25) # 9,000 steps -> 36,000 frames
	var num_samples: int = num_steps * 4
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 4.0 / float(MIX_RATE)

	var dw1: float = TAU * BASE_NOTE_HZ * inv_step_sr
	var c1s: float = cos(dw1)
	var s1s: float = sin(dw1)
	var dwu: float = TAU * (BASE_NOTE_HZ * 1.0014) * inv_step_sr
	var cus: float = cos(dwu)
	var sus: float = sin(dwu)
	var dwf: float = TAU * (BASE_NOTE_HZ * 0.5) * inv_step_sr
	var cfs: float = cos(dwf)
	var sfs: float = sin(dwf)

	var s1: float = 0.0
	var c1: float = 1.0
	var su: float = 0.0
	var cu: float = 1.0
	var sf: float = 0.0
	var cf: float = 1.0

	var env1: float = 14800.0
	var env2: float = 5400.0
	var env3: float = 2100.0
	var env4: float = 750.0
	var env_felt: float = 1800.0
	var dec1: float = exp(-1.95 * inv_step_sr)
	var dec2: float = exp(-3.8 * inv_step_sr)
	var dec3: float = exp(-7.0 * inv_step_sr)
	var dec4: float = exp(-12.5 * inv_step_sr)
	var dec_felt: float = exp(-34.0 * inv_step_sr)

	var attack_len: int = int(0.028 * float(MIX_RATE) * 0.25) # 28 ms soft felt attack
	var inv_att: float = 1.0 / float(attack_len)
	var felt_end: int = int(0.13 * float(MIX_RATE) * 0.25)
	var fade_len: int = int(0.060 * float(MIX_RATE) * 0.25)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	# Max possible sum is 24,850 (strictly inside [-30000, 30000])
	for i: int in range(num_steps):
		var ns1: float = s1 * c1s + c1 * s1s
		c1 = c1 * c1s - s1 * s1s
		s1 = ns1
		var nsu: float = su * cus + cu * sus
		cu = cu * cus - su * sus
		su = nsu

		var s2: float = 2.0 * s1 * c1
		var s3: float = s1 * (3.0 - 4.0 * s1 * s1)
		var common: float = s3 * env3 + (2.0 * s2 * (1.0 - 2.0 * s1 * s1)) * env4
		if i < felt_end:
			var nsf: float = sf * cfs + cf * sfs
			cf = cf * cfs - sf * sfs
			sf = nsf
			common += sf * env_felt
			env_felt *= dec_felt

		var su2: float = 2.0 * su * cu
		var left: float = (s1 * 0.62 + su * 0.38) * env1 + (s2 * 0.68 + su2 * 0.32) * env2 + common
		var right: float = (s1 * 0.38 + su * 0.62) * env1 + (s2 * 0.32 + su2 * 0.68) * env2 + common

		if i < attack_len:
			var u: float = float(i) * inv_att
			var a: float = u * u * (3.0 - 2.0 * u)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		var dl: float = (left - prev_l) * 0.25
		var dr: float = (right - prev_r) * 0.25
		var lx: float = prev_l
		var rx: float = prev_r
		ints[out_idx] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 1] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 2] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 3] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		out_idx += 4
		prev_l = left
		prev_r = right

		env1 *= dec1
		env2 *= dec2
		env3 *= dec3
		env4 *= dec4

	return _make_stereo_wav(ints.to_byte_array())


func _bake_celesta() -> AudioStreamWAV:
	# Delicate Parisian music-box / celesta bell tuned to C4 (261.63 Hz).
	# Silky 14 ms attack, pure crystalline 2nd & 4th partials (zero harsh metallic
	# clang), subtle stereo shimmer, 1.45 s dreamy ring.
	var num_steps: int = int(1.45 * float(MIX_RATE) * 0.25) # 8,700 steps -> 34,800 frames
	var num_samples: int = num_steps * 4
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 4.0 / float(MIX_RATE)

	var dw1: float = TAU * BASE_NOTE_HZ * inv_step_sr
	var c1s: float = cos(dw1)
	var s1s: float = sin(dw1)
	var dwb: float = TAU * (BASE_NOTE_HZ * 1.0018) * inv_step_sr
	var cbs: float = cos(dwb)
	var sbs: float = sin(dwb)

	var s1: float = 0.0
	var c1: float = 1.0
	var sb: float = 0.0
	var cb: float = 1.0

	var env1: float = 13600.0
	var env2: float = 4100.0
	var env4: float = 1450.0
	var dec1: float = exp(-2.10 * inv_step_sr)
	var dec2: float = exp(-4.2 * inv_step_sr)
	var dec4: float = exp(-8.5 * inv_step_sr)

	var attack_len: int = int(0.014 * float(MIX_RATE) * 0.25)
	var inv_att: float = 1.0 / float(attack_len)
	var fade_len: int = int(0.055 * float(MIX_RATE) * 0.25)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	# Max possible sum is 19,150 (strictly inside [-30000, 30000])
	for i: int in range(num_steps):
		var ns1: float = s1 * c1s + c1 * s1s
		c1 = c1 * c1s - s1 * s1s
		s1 = ns1
		var nsb: float = sb * cbs + cb * sbs
		cb = cb * cbs - sb * sbs
		sb = nsb

		var s2: float = 2.0 * s1 * c1
		var h4: float = (2.0 * s2 * (1.0 - 2.0 * s1 * s1)) * env4
		var left: float = (s1 * 0.68 + sb * 0.32) * env1 + s2 * env2 + h4
		var right: float = (s1 * 0.32 + sb * 0.68) * env1 + (2.0 * sb * cb) * env2 + h4

		if i < attack_len:
			var u: float = float(i) * inv_att
			var a: float = u * u * (3.0 - 2.0 * u)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		var dl: float = (left - prev_l) * 0.25
		var dr: float = (right - prev_r) * 0.25
		var lx: float = prev_l
		var rx: float = prev_r
		ints[out_idx] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 1] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 2] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 3] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		out_idx += 4
		prev_l = left
		prev_r = right

		env1 *= dec1
		env2 *= dec2
		env4 *= dec4

	return _make_stereo_wav(ints.to_byte_array())


func _bake_silk_harp() -> AudioStreamWAV:
	# Warm nylon concert harp pluck tuned to C4 (261.63 Hz).
	# 12 ms soft finger release, lush harmonic warmth, 1.40 s natural stereo decay.
	var num_steps: int = int(1.40 * float(MIX_RATE) * 0.25) # 8,400 steps -> 33,600 frames
	var num_samples: int = num_steps * 4
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 4.0 / float(MIX_RATE)

	var dw1: float = TAU * BASE_NOTE_HZ * inv_step_sr
	var c1s: float = cos(dw1)
	var s1s: float = sin(dw1)
	var dwd: float = TAU * (BASE_NOTE_HZ * 1.0016) * inv_step_sr
	var cds: float = cos(dwd)
	var sds: float = sin(dwd)

	var s1: float = 0.0
	var c1: float = 1.0
	var sd: float = 0.0
	var cd: float = 1.0

	var env1: float = 13200.0
	var env2: float = 6100.0
	var env3: float = 2500.0
	var env5: float = 780.0
	var dec1: float = exp(-2.25 * inv_step_sr)
	var dec2: float = exp(-3.9 * inv_step_sr)
	var dec3: float = exp(-7.2 * inv_step_sr)
	var dec5: float = exp(-14.5 * inv_step_sr)

	var attack_len: int = int(0.012 * float(MIX_RATE) * 0.25)
	var inv_att: float = 1.0 / float(attack_len)
	var fade_len: int = int(0.055 * float(MIX_RATE) * 0.25)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	# Max possible sum is 22,580 (strictly inside [-30000, 30000])
	for i: int in range(num_steps):
		var ns1: float = s1 * c1s + c1 * s1s
		c1 = c1 * c1s - s1 * s1s
		s1 = ns1
		var nsd: float = sd * cds + cd * sds
		cd = cd * cds - sd * sds
		sd = nsd

		var s2: float = 2.0 * s1 * c1
		var c2: float = 1.0 - 2.0 * s1 * s1
		var s3: float = s1 * (3.0 - 4.0 * s1 * s1)
		var upper: float = s3 * env3 + (s3 * c2 + (c1 * (4.0 * c1 * c1 - 3.0)) * s2) * env5
		var left: float = (s1 * 0.65 + sd * 0.35) * env1 + s2 * env2 + upper * 0.92
		var right: float = (s1 * 0.35 + sd * 0.65) * env1 + (2.0 * sd * cd) * env2 + upper * 1.08

		if i < attack_len:
			var u: float = float(i) * inv_att
			var a: float = u * u * (3.0 - 2.0 * u)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		var dl: float = (left - prev_l) * 0.25
		var dr: float = (right - prev_r) * 0.25
		var lx: float = prev_l
		var rx: float = prev_r
		ints[out_idx] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 1] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 2] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		lx += dl
		rx += dr
		ints[out_idx + 3] = ((int(rx) & 0xffff) << 16) | (int(lx) & 0xffff)
		out_idx += 4
		prev_l = left
		prev_r = right

		env1 *= dec1
		env2 *= dec2
		env3 *= dec3
		env5 *= dec5

	return _make_stereo_wav(ints.to_byte_array())


func _bake_droplet() -> AudioStreamWAV:
	# Delicate crystalline water-droplet marimba/glass bloom for eating prey.
	# Tiny gentle 35 ms pitch blossom (486 -> 523.25 Hz) — zero laser sweep!
	var num_steps: int = int(0.24 * float(MIX_RATE) * 0.5)
	var num_samples: int = num_steps * 2
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 2.0 / float(MIX_RATE)
	var tau_inv_sr: float = TAU * inv_step_sr
	var blossom_len: int = int(0.035 * float(MIX_RATE) * 0.5)
	var inv_blossom: float = 1.0 / float(blossom_len)

	var phase_l: float = 0.0
	var phase_r: float = 0.0
	var env1: float = 15200.0
	var env2: float = 3400.0
	var dec1: float = exp(-12.5 * inv_step_sr)
	var dec2: float = exp(-26.0 * inv_step_sr)

	var attack_len: int = int(0.009 * float(MIX_RATE) * 0.5)
	var inv_att: float = 1.0 / float(attack_len)
	var fade_len: int = int(0.025 * float(MIX_RATE) * 0.5)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	for i: int in range(num_steps):
		var u: float = float(i) * inv_blossom if i < blossom_len else 1.0
		var freq: float = 486.0 + 37.25 * u * (2.0 - u)
		phase_l += freq * tau_inv_sr
		phase_r += (freq * 1.003) * tau_inv_sr

		var left: float = sin(phase_l) * env1 + sin(phase_l * 2.0) * env2
		var right: float = sin(phase_r) * env1 + sin(phase_r * 2.0) * env2

		if i < attack_len:
			var au: float = float(i) * inv_att
			var a: float = au * au * (3.0 - 2.0 * au)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		ints[out_idx] = ((int(prev_r) & 0xffff) << 16) | (int(prev_l) & 0xffff)
		ints[out_idx + 1] = ((int((prev_r + right) * 0.5) & 0xffff) << 16) | (int((prev_l + left) * 0.5) & 0xffff)
		out_idx += 2
		prev_l = left
		prev_r = right
		env1 *= dec1
		env2 *= dec2

	return _make_stereo_wav(ints.to_byte_array())


func _bake_ember_breath() -> AudioStreamWAV:
	# Soft warm ember silk-breath (3-stage heavily low-passed warm brown/pink air
	# < 950 Hz + gentle warm flute-glow core). Zero raw white-noise static!
	var num_steps: int = int(0.32 * float(MIX_RATE) / 3.0)
	var num_samples: int = num_steps * 3
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 3.0 / float(MIX_RATE)
	var inv_n: float = 1.0 / float(num_steps)
	var tau_inv_sr: float = TAU * inv_step_sr

	var phase: float = 0.0
	var noise_l: int = 13579246
	var noise_r: int = 24681357
	var lp1_l: float = 0.0
	var lp2_l: float = 0.0
	var lp3_l: float = 0.0
	var lp1_r: float = 0.0
	var lp2_r: float = 0.0
	var lp3_r: float = 0.0
	var alpha: float = 0.30 # 3-pole cascade at 8 kHz -> silky rolloff well below 950 Hz

	var env_air: float = 30000.0
	var env_glow: float = 6800.0
	var dec_air: float = exp(-8.5 * inv_step_sr)
	var dec_glow: float = exp(-11.5 * inv_step_sr)

	var attack_len: int = int(0.028 * float(MIX_RATE) / 3.0)
	var inv_att: float = 1.0 / float(attack_len)
	var fade_len: int = int(0.045 * float(MIX_RATE) / 3.0)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	for i: int in range(num_steps):
		var u: float = float(i) * inv_n
		phase += (245.0 - 42.0 * u) * tau_inv_sr

		noise_l = (noise_l * 1103515245 + 12345) & 0x7fffffff
		lp1_l += ((float(noise_l) * 9.3132257e-10 - 1.0) - lp1_l) * alpha
		lp2_l += (lp1_l - lp2_l) * alpha
		lp3_l += (lp2_l - lp3_l) * alpha

		noise_r = (noise_r * 1103515245 + 12345) & 0x7fffffff
		lp1_r += ((float(noise_r) * 9.3132257e-10 - 1.0) - lp1_r) * alpha
		lp2_r += (lp1_r - lp2_r) * alpha
		lp3_r += (lp2_r - lp3_r) * alpha

		var glow: float = sin(phase) * env_glow
		var left: float = lp3_l * env_air + glow
		var right: float = lp3_r * env_air + glow

		if i < attack_len:
			var au: float = float(i) * inv_att
			var a: float = au * au * (3.0 - 2.0 * au)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		if left > float(PCM_CLAMP):
			left = float(PCM_CLAMP)
		elif left < float(-PCM_CLAMP):
			left = float(-PCM_CLAMP)
		if right > float(PCM_CLAMP):
			right = float(PCM_CLAMP)
		elif right < float(-PCM_CLAMP):
			right = float(-PCM_CLAMP)

		var dl: float = (left - prev_l) * 0.3333333333
		var dr: float = (right - prev_r) * 0.3333333333
		ints[out_idx] = ((int(prev_r) & 0xffff) << 16) | (int(prev_l) & 0xffff)
		ints[out_idx + 1] = ((int(prev_r + dr) & 0xffff) << 16) | (int(prev_l + dl) & 0xffff)
		ints[out_idx + 2] = ((int(prev_r + dr + dr) & 0xffff) << 16) | (int(prev_l + dl + dl) & 0xffff)
		out_idx += 3
		prev_l = left
		prev_r = right
		env_air *= dec_air
		env_glow *= dec_glow

	return _make_stereo_wav(ints.to_byte_array())


func _bake_silk_glide() -> AudioStreamWAV:
	# Ethereal silky glide whoosh (warm 3-stage filtered air swell with gentle
	# stereo sweep + subtle airy harmonic cushion).
	var num_steps: int = int(0.36 * float(MIX_RATE) / 3.0)
	var num_samples: int = num_steps * 3
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 3.0 / float(MIX_RATE)
	var inv_n: float = 1.0 / float(num_steps)
	var tau_inv_sr: float = TAU * inv_step_sr

	var phase: float = 0.0
	var noise_l: int = 4567891
	var noise_r: int = 9182736
	var lp1_l: float = 0.0
	var lp2_l: float = 0.0
	var lp3_l: float = 0.0
	var lp1_r: float = 0.0
	var lp2_r: float = 0.0
	var lp3_r: float = 0.0

	var env_air: float = 26500.0
	var env_tone: float = 5200.0
	var dec_air: float = exp(-6.8 * inv_step_sr)
	var dec_tone: float = exp(-9.5 * inv_step_sr)

	var attack_len: int = int(0.045 * float(MIX_RATE) / 3.0)
	var inv_att: float = 1.0 / float(attack_len)
	var fade_len: int = int(0.055 * float(MIX_RATE) / 3.0)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	for i: int in range(num_steps):
		var u: float = float(i) * inv_n
		var alpha: float = 0.26 + 0.56 * u * (1.0 - u)
		phase += (220.0 + 110.0 * u) * tau_inv_sr

		noise_l = (noise_l * 1103515245 + 12345) & 0x7fffffff
		lp1_l += ((float(noise_l) * 9.3132257e-10 - 1.0) - lp1_l) * alpha
		lp2_l += (lp1_l - lp2_l) * alpha
		lp3_l += (lp2_l - lp3_l) * alpha

		noise_r = (noise_r * 1103515245 + 12345) & 0x7fffffff
		lp1_r += ((float(noise_r) * 9.3132257e-10 - 1.0) - lp1_r) * alpha
		lp2_r += (lp1_r - lp2_r) * alpha
		lp3_r += (lp2_r - lp3_r) * alpha

		var cushion: float = sin(phase) * env_tone
		var left: float = (lp3_l * env_air + cushion) * (1.18 - 0.36 * u)
		var right: float = (lp3_r * env_air + cushion) * (0.82 + 0.36 * u)

		if i < attack_len:
			var au: float = float(i) * inv_att
			var a: float = au * au * (3.0 - 2.0 * au)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		if left > float(PCM_CLAMP):
			left = float(PCM_CLAMP)
		elif left < float(-PCM_CLAMP):
			left = float(-PCM_CLAMP)
		if right > float(PCM_CLAMP):
			right = float(PCM_CLAMP)
		elif right < float(-PCM_CLAMP):
			right = float(-PCM_CLAMP)

		var dl: float = (left - prev_l) * 0.3333333333
		var dr: float = (right - prev_r) * 0.3333333333
		ints[out_idx] = ((int(prev_r) & 0xffff) << 16) | (int(prev_l) & 0xffff)
		ints[out_idx + 1] = ((int(prev_r + dr) & 0xffff) << 16) | (int(prev_l + dl) & 0xffff)
		ints[out_idx + 2] = ((int(prev_r + dr + dr) & 0xffff) << 16) | (int(prev_l + dl + dl) & 0xffff)
		out_idx += 3
		prev_l = left
		prev_r = right
		env_air *= dec_air
		env_tone *= dec_tone

	return _make_stereo_wav(ints.to_byte_array())


func _bake_cello_sigh() -> AudioStreamWAV:
	# Tender, melancholic muted warm cello / low felt-piano sigh for gentle hurt.
	# Soft descending minor-second interval (F3 174.61 Hz -> E3 164.81 Hz) with
	# velvety low-passed warmth — zero ugly cartoon FM buzzer or wobble!
	var num_steps: int = int(0.48 * float(MIX_RATE) / 3.0)
	var num_samples: int = num_steps * 3
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 3.0 / float(MIX_RATE)
	var tau_inv_sr: float = TAU * inv_step_sr
	var glide_len: int = int(0.14 * float(MIX_RATE) / 3.0)
	var inv_glide: float = 1.0 / float(glide_len)

	var phase_l: float = 0.0
	var phase_r: float = 0.0
	var env1: float = 14800.0
	var env2: float = 4400.0
	var env3: float = 1150.0
	var dec1: float = exp(-4.8 * inv_step_sr)
	var dec2: float = exp(-7.5 * inv_step_sr)
	var dec3: float = exp(-12.5 * inv_step_sr)

	var attack_len: int = int(0.038 * float(MIX_RATE) / 3.0)
	var inv_att: float = 1.0 / float(attack_len)
	var fade_len: int = int(0.060 * float(MIX_RATE) / 3.0)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_l: float = 0.0
	var prev_r: float = 0.0
	var out_idx: int = 0

	for i: int in range(num_steps):
		var freq: float = 164.81
		if i < glide_len:
			var g: float = float(i) * inv_glide
			freq = 174.61 - 9.80 * g * g * (3.0 - 2.0 * g)
		phase_l += freq * tau_inv_sr
		phase_r += (freq * 1.0022) * tau_inv_sr

		var sl: float = sin(phase_l)
		var sr: float = sin(phase_r)
		var left: float = sl * env1 + sin(phase_l * 2.0) * env2 + sl * (3.0 - 4.0 * sl * sl) * env3
		var right: float = sr * env1 + sin(phase_r * 2.0) * env2 + sr * (3.0 - 4.0 * sr * sr) * env3

		if i < attack_len:
			var au: float = float(i) * inv_att
			var a: float = au * au * (3.0 - 2.0 * au)
			left *= a
			right *= a
		elif i >= fade_start:
			var f: float = float(num_steps - i) * inv_fade
			left *= f
			right *= f

		var dl: float = (left - prev_l) * 0.3333333333
		var dr: float = (right - prev_r) * 0.3333333333
		ints[out_idx] = ((int(prev_r) & 0xffff) << 16) | (int(prev_l) & 0xffff)
		ints[out_idx + 1] = ((int(prev_r + dr) & 0xffff) << 16) | (int(prev_l + dl) & 0xffff)
		ints[out_idx + 2] = ((int(prev_r + dr + dr) & 0xffff) << 16) | (int(prev_l + dl + dl) & 0xffff)
		out_idx += 3
		prev_l = left
		prev_r = right
		env1 *= dec1
		env2 *= dec2
		env3 *= dec3

	return _make_stereo_wav(ints.to_byte_array())


func _bake_velvet_heartbeat() -> AudioStreamWAV:
	# Ultra-subtle, deep muffled 62 Hz velvet double-bloom for predator proximity.
	var num_steps: int = int(0.46 * float(MIX_RATE) * 0.25)
	var num_samples: int = num_steps * 4
	var ints: PackedInt32Array = PackedInt32Array()
	ints.resize(num_samples)
	var inv_step_sr: float = 4.0 / float(MIX_RATE)
	var tau_inv_sr: float = TAU * inv_step_sr

	var beat1_end: int = int(0.22 * float(MIX_RATE) * 0.25)
	var beat2_start: int = int(0.18 * float(MIX_RATE) * 0.25)
	var inv_b1: float = 1.0 / float(beat1_end)
	var inv_b2: float = 1.0 / float(num_steps - beat2_start)

	var phase1: float = 0.0
	var phase2: float = 0.0
	var env1: float = 16500.0
	var env2: float = 11500.0
	var dec1: float = exp(-12.5 * inv_step_sr)
	var dec2: float = exp(-11.5 * inv_step_sr)

	var att1_len: int = int(0.032 * float(MIX_RATE) * 0.25)
	var inv_att1: float = 1.0 / float(att1_len)
	var att2_len: int = int(0.036 * float(MIX_RATE) * 0.25)
	var inv_att2: float = 1.0 / float(att2_len)
	var fade_len: int = int(0.045 * float(MIX_RATE) * 0.25)
	var fade_start: int = num_steps - fade_len
	var inv_fade: float = 1.0 / float(fade_len)

	var prev_s: float = 0.0
	var out_idx: int = 0

	for i: int in range(num_steps):
		var sig: float = 0.0
		if i < beat1_end:
			phase1 += (64.0 - 7.0 * (float(i) * inv_b1)) * tau_inv_sr
			var a1: float = 1.0
			if i < att1_len:
				var u1: float = float(i) * inv_att1
				a1 = u1 * u1 * (3.0 - 2.0 * u1)
			sig += sin(phase1) * a1 * env1
			env1 *= dec1

		if i >= beat2_start:
			var j: int = i - beat2_start
			phase2 += (58.0 - 6.0 * (float(j) * inv_b2)) * tau_inv_sr
			var a2: float = 1.0
			if j < att2_len:
				var u2: float = float(j) * inv_att2
				a2 = u2 * u2 * (3.0 - 2.0 * u2)
			sig += sin(phase2) * a2 * env2
			env2 *= dec2

		if i >= fade_start:
			sig *= float(num_steps - i) * inv_fade

		var ds: float = (sig - prev_s) * 0.25
		var sx: float = prev_s
		var u0: int = int(sx) & 0xffff
		ints[out_idx] = (u0 << 16) | u0
		sx += ds
		var u1m: int = int(sx) & 0xffff
		ints[out_idx + 1] = (u1m << 16) | u1m
		sx += ds
		var u2m: int = int(sx) & 0xffff
		ints[out_idx + 2] = (u2m << 16) | u2m
		sx += ds
		var u3m: int = int(sx) & 0xffff
		ints[out_idx + 3] = (u3m << 16) | u3m
		out_idx += 4
		prev_s = sig

	return _make_stereo_wav(ints.to_byte_array())


func _start_pads() -> void:
	if _muted or _app_paused or _wav_pad == null or _pad_players.size() < PAD_VOICES:
		return
	_pad_fade_gain = 0.0
	for i: int in range(PAD_VOICES):
		var p: AudioStreamPlayer = _pad_players[i]
		p.stream = _wav_pad
		p.stream_paused = false
		p.pitch_scale = _current_pad_pitch * (1.0 if i == 0 else 1.0022)
		p.volume_db = -48.0
		if not p.playing:
			p.play(0.0 if i == 0 else 3.0)


func _ensure_pads_playing() -> void:
	if _muted or _app_paused or _wav_pad == null:
		return
	for i: int in range(_pad_players.size()):
		var p: AudioStreamPlayer = _pad_players[i]
		if p.stream_paused:
			p.stream_paused = false
		elif not p.playing:
			_pad_fade_gain = 0.0
			p.stream = _wav_pad
			p.pitch_scale = _current_pad_pitch * (1.0 if i == 0 else 1.0022)
			p.volume_db = -48.0
			p.play(0.0 if i == 0 else 3.0)


func _update_pads(delta: float) -> void:
	if _pad_players.size() < PAD_VOICES:
		return
	# Smoothly glide pad pitch toward the current scale's root note
	if absf(_current_pad_pitch - _target_pad_pitch) > 0.0005:
		var p_alpha: float = 1.0 - exp(-PAD_PITCH_SMOOTH_SPEED * delta)
		_current_pad_pitch = lerpf(_current_pad_pitch, _target_pad_pitch, p_alpha)
		if absf(_current_pad_pitch - _target_pad_pitch) <= 0.0005:
			_current_pad_pitch = _target_pad_pitch
		_pad_players[0].pitch_scale = clampf(_current_pad_pitch, 0.4, 2.5)
		_pad_players[1].pitch_scale = clampf(_current_pad_pitch * 1.0022, 0.4, 2.5)

	# Smooth soft startup bloom (0 -> 1 over ~1.6 s) so pad never pops in abruptly
	if _pad_fade_gain < 1.0:
		_pad_fade_gain = minf(1.0, _pad_fade_gain + delta * 0.65)
	var fade_db: float = lerpf(-30.0, 0.0, _pad_fade_gain * (2.0 - _pad_fade_gain))

	# Gentle slow crossfade breathing between the 2 offset pad voices (-19 to -17 dB total)
	_pad_breath_phase = fmod(_pad_breath_phase + delta * 0.24, TAU)
	var cross: float = 0.5 + 0.5 * sin(_pad_breath_phase)
	# Slightly richer ethereal choir-pad presence in Planetary (4) & Cosmic (5)
	var scale_pad_lift: float = 1.0 if _scale_index >= 4 else 0.0
	var base_pad_db: float = -18.5 + scale_pad_lift + _current_duck_db + fade_db

	_pad_players[0].volume_db = base_pad_db + lerpf(-2.4, 0.4, cross)
	_pad_players[1].volume_db = base_pad_db + lerpf(0.4, -2.4, cross)


func set_muted(m: bool) -> void:
	_muted = m
	if _muted:
		_queue.clear()
		_stop_all_players()
	else:
		if not _app_paused:
			_ensure_pads_playing()
			if _phrase_timer < 0.5:
				_phrase_timer = 0.9


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
		for p: AudioStreamPlayer in _pad_players:
			if p.playing:
				p.stream_paused = true
		for p: AudioStreamPlayer in _ambient_players:
			if p.playing:
				p.stream_paused = true
		for p: AudioStreamPlayer in _sfx_players:
			p.stop()
	else:
		if not _muted:
			_ensure_pads_playing()
			for p: AudioStreamPlayer in _ambient_players:
				if p.stream_paused:
					p.stream_paused = false
			if _phrase_timer < 0.5:
				_phrase_timer = 0.85


func set_scale_index(idx: int) -> void:
	_scale_index = clampi(idx, 0, Scales.NUM_SCALES - 1)
	_target_pad_pitch = _compute_pad_pitch_for_scale(_scale_index)


func _get_scale_root() -> float:
	var scale_dict: Dictionary = Scales.SCALES[_scale_index]
	return float(scale_dict.get("music_root", BASE_NOTE_HZ))


func _compute_pad_pitch_for_scale(idx: int) -> float:
	var clamped: int = clampi(idx, 0, Scales.NUM_SCALES - 1)
	var scale_dict: Dictionary = Scales.SCALES[clamped]
	var root_hz: float = float(scale_dict.get("music_root", BASE_NOTE_HZ))
	return clampf((root_hz * 0.5) / PAD_BASE_HZ, 0.5, 2.0)


func _stop_all_players() -> void:
	for p: AudioStreamPlayer in _pad_players:
		p.stop()
		p.stream_paused = false
	for p: AudioStreamPlayer in _ambient_players:
		p.stop()
		p.stream_paused = false
	for p: AudioStreamPlayer in _sfx_players:
		p.stop()
		p.stream_paused = false


func _process(delta: float) -> void:
	if _muted or _app_paused:
		return

	# Smoothly duck/unduck ambient & pad players (~9 dB down when paused/defeat)
	if absf(_current_duck_db - _target_duck_db) > 0.01:
		var alpha: float = 1.0 - exp(-DUCK_SMOOTH_SPEED * delta)
		_current_duck_db = lerpf(_current_duck_db, _target_duck_db, alpha)
		if absf(_current_duck_db - _target_duck_db) <= 0.01:
			_current_duck_db = _target_duck_db
		for i: int in range(_ambient_players.size()):
			_ambient_players[i].volume_db = _ambient_base_dbs[i] + _current_duck_db

	# Update continuous crossfading ethereal pad voices
	_update_pads(delta)

	# Composed Joe Hisaishi poetic phrase scheduler
	_phrase_timer -= delta
	if _phrase_timer <= 0.0:
		var phrase_duration: float = _spawn_poetic_phrase()
		# Leave poetic breathing room after each phrase so the hall reverb blooms
		_phrase_timer = phrase_duration + _rng.randf_range(2.2, 3.8)

	# Lightweight scheduled event queue (~0.002 ms/frame)
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


func _pick_scale_instruments() -> Array[AudioStreamWAV]:
	# Each scale shifts instrument palette & poetic color:
	# 0 Quantum: delicate celesta + silk harp
	# 1 Micro: warm water-harp + felt piano
	# 2 Forest: lush Hisaishi felt piano + silk harp
	# 3 City: nocturnal felt piano + music-box celesta
	# 4 Planetary: ethereal high silk harp + celesta
	# 5 Cosmic: wide celestial celesta + felt piano harmonies
	match _scale_index:
		0:
			return [_wav_celesta, _wav_silk_harp]
		1:
			return [_wav_silk_harp, _wav_felt_piano]
		2:
			return [_wav_felt_piano, _wav_silk_harp]
		3:
			return [_wav_felt_piano, _wav_celesta]
		4:
			return [_wav_silk_harp, _wav_celesta]
		_:
			return [_wav_celesta, _wav_felt_piano]


func _spawn_poetic_phrase() -> float:
	# Pick a curated Joe Hisaishi motif without repeating the previous one
	var motif_idx: int = _rng.randi_range(0, POETIC_MOTIFS.size() - 1)
	if motif_idx == _last_motif_idx:
		motif_idx = (motif_idx + 1) % POETIC_MOTIFS.size()
	_last_motif_idx = motif_idx
	var motif: Array = POETIC_MOTIFS[motif_idx]

	var palette: Array[AudioStreamWAV] = _pick_scale_instruments()
	var primary_wav: AudioStreamWAV = palette[0]
	var secondary_wav: AudioStreamWAV = palette[1]

	var root: float = _get_scale_root()
	# Scale-tailored register: luminous upper register for Quantum/Planetary/Cosmic,
	# intimate middle register for Micro/Forest/City
	var melody_mult: float = 1.0
	if _scale_index == 0 or _scale_index == 4 or _scale_index == 5:
		melody_mult = 2.0 if root < 270.0 else 1.0
	elif root < 250.0:
		melody_mult = 2.0

	# Soft left-hand felt-piano root + fifth accompaniment chord every 2 phrases
	if _phrase_counter % 2 == 0:
		var bass_root: float = root * 0.5
		if bass_root < 120.0:
			bass_root *= 2.0
		_schedule_note(0.0, _wav_felt_piano, bass_root / BASE_NOTE_HZ, -17.5, true)
		_schedule_note(0.075, _wav_felt_piano, (bass_root * 1.5) / BASE_NOTE_HZ, -19.0, true)
		# Gentle Major 9th inner color on Cosmic & Forest
		if _scale_index == 2 or _scale_index == 5:
			_schedule_note(0.15, _wav_felt_piano, (bass_root * 2.25) / BASE_NOTE_HZ, -20.5, true)

	_phrase_counter += 1

	# Schedule the poetic motif with expressive pianist rubato (0.38s - 0.65s steps)
	var t: float = 0.08 if (_phrase_counter % 2 == 1) else 0.0
	var base_db: float = _rng.randf_range(-15.5, -13.5)
	var n: int = motif.size()

	for i: int in range(n):
		var deg_idx: int = clampi(int(motif[i]), 0, LYDIAN_MAJ9.size() - 1)
		var freq: float = root * melody_mult * LYDIAN_MAJ9[deg_idx]
		# Keep melody gracefully within sweet acoustic register (260..1050 Hz)
		while freq > 1050.0:
			freq *= 0.5
		while freq < 260.0:
			freq *= 2.0

		# Expressive phrase dynamic arc (gentle swell into middle, tender sigh at end)
		var arc_db: float = sin(PI * float(i + 1) / float(n + 1)) * 1.6 - 0.8
		var wav: AudioStreamWAV = primary_wav
		if i == n - 1 and _rng.randf() < 0.55:
			wav = secondary_wav # Poetic timbral answer on the final note
		_schedule_note(t, wav, freq / BASE_NOTE_HZ, base_db + arc_db, true)

		# Expressive rubato spacing (slightly lingering before final resolving note)
		var step_dt: float = _rng.randf_range(0.38, 0.58)
		if i == n - 2:
			step_dt = _rng.randf_range(0.48, 0.65)
		t += step_dt

	return t


func play_chomp(combo_step: int = 0) -> void:
	# Delicate crystalline water-droplet marimba + soft ascending pentatonic celesta/harp
	var step_idx: int = clampi(combo_step, 0, COMBO_RATIOS.size() - 1)
	var ratio: float = COMBO_RATIOS[step_idx]
	_play_on_sfx(_wav_droplet, ratio, -10.5)

	var chime_freq: float = maxf(330.0, _get_scale_root() * 1.5) * ratio
	while chime_freq > 1320.0:
		chime_freq *= 0.5
	var shimmer_wav: AudioStreamWAV = _wav_celesta if (step_idx % 2 == 0) else _wav_silk_harp
	_play_on_sfx(shimmer_wav, chime_freq / BASE_NOTE_HZ, -11.2)


func play_spit(level: int = 1) -> void:
	# Soft warm ember silk-breath + glowing amber glass-bell chime
	var lvl: int = clampi(level, 1, 3)
	var breath_pitch: float = 0.96 + float(lvl - 1) * 0.08
	var breath_db: float = -10.6 + float(lvl - 1) * 0.6
	_play_on_sfx(_wav_spit, breath_pitch, breath_db)

	var root: float = maxf(310.0, _get_scale_root() * 1.5)
	_play_on_sfx(_wav_celesta, (root * 1.25) / BASE_NOTE_HZ, -10.8)
	if lvl >= 2:
		_schedule_note(0.055, _wav_celesta, (root * 1.875) / BASE_NOTE_HZ, -11.2, false)
	if lvl >= 3:
		_schedule_note(0.11, _wav_silk_harp, (root * 2.25) / BASE_NOTE_HZ, -11.0, false)


func play_dash(level: int = 1) -> void:
	# Ethereal silky glide whoosh + delicate 3-note ascending silk-harp shimmer flutter
	var lvl: int = clampi(level, 1, 3)
	var whoosh_pitch: float = 0.95 + float(lvl - 1) * 0.09
	var whoosh_db: float = -10.2 + float(lvl - 1) * 0.5
	_play_on_sfx(_wav_dash, whoosh_pitch, whoosh_db)

	var root: float = maxf(290.0, _get_scale_root() * 1.25)
	var flutter: Array[float] = [1.5, 2.0, 2.5]
	for i: int in range(flutter.size()):
		_schedule_note(
			float(i) * 0.048,
			_wav_silk_harp,
			(root * flutter[i]) / BASE_NOTE_HZ,
			-11.2 + float(i) * 0.3,
			false
		)
	if lvl >= 3:
		_schedule_note(0.145, _wav_celesta, (root * 3.0) / BASE_NOTE_HZ, -10.8, false)


func play_hurt() -> void:
	# Tender, melancholic muted warm cello / low felt-piano sigh
	_play_on_sfx(_wav_hurt, 1.0, -9.5)
	var low_root: float = maxf(130.0, _get_scale_root() * 0.5)
	_schedule_note(0.06, _wav_felt_piano, low_root / BASE_NOTE_HZ, -13.5, false)


func play_shrink() -> void:
	# Gentle two-note descending poetic sigh on silk harp & felt piano
	var root: float = maxf(290.0, _get_scale_root() * 1.5)
	_play_on_sfx(_wav_silk_harp, (root * 1.25) / BASE_NOTE_HZ, -10.8)
	_schedule_note(0.085, _wav_felt_piano, root / BASE_NOTE_HZ, -11.8, false)


func play_heal() -> void:
	# Warm rising Major 9th bloom on felt piano & celesta
	var root: float = maxf(290.0, _get_scale_root() * 1.25)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.25]
	for i: int in range(ratios.size()):
		var wav: AudioStreamWAV = _wav_celesta if i >= 2 else _wav_felt_piano
		_schedule_note(
			float(i) * 0.08,
			wav,
			(root * ratios[i]) / BASE_NOTE_HZ,
			-10.2 + float(i) * 0.25,
			false
		)


func play_chime(pitch_mult: float = 1.0) -> void:
	# Delicate celesta UI / world chime harmonized to current scale
	var freq: float = maxf(340.0, _get_scale_root() * 1.5) * clampf(pitch_mult, 0.6, 2.0)
	_play_on_sfx(_wav_celesta, freq / BASE_NOTE_HZ, -10.8)


func play_scale_up() -> void:
	# Lush Studio Ghibli ascension flourish: warm felt-piano foundation + harp/celesta arc
	var root: float = maxf(280.0, _get_scale_root())
	_play_on_sfx(_wav_felt_piano, (root * 0.5) / BASE_NOTE_HZ, -11.0)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 1.875, 2.25, 3.0]
	for i: int in range(ratios.size()):
		var wav: AudioStreamWAV = _wav_silk_harp if (i % 2 == 0) else _wav_celesta
		_schedule_note(
			float(i) * 0.082,
			wav,
			(root * ratios[i]) / BASE_NOTE_HZ,
			-9.8 + minf(1.2, float(i) * 0.22),
			false
		)


func play_victory() -> void:
	# Grand nostalgic Joe Hisaishi Major 9th / Lydian celestial cascade
	var root: float = 392.0 # G4 luminous finale
	_play_on_sfx(_wav_felt_piano, (root * 0.5) / BASE_NOTE_HZ, -10.5)
	_schedule_note(0.08, _wav_felt_piano, (root * 0.75) / BASE_NOTE_HZ, -11.0, false)
	var melody: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.875, 2.0, 2.25, 3.0]
	for i: int in range(melody.size()):
		var wav: AudioStreamWAV = _wav_silk_harp if (i % 2 == 0) else _wav_celesta
		_schedule_note(
			0.06 + float(i) * 0.105,
			wav,
			(root * melody[i]) / BASE_NOTE_HZ,
			-9.4 + minf(1.0, float(i) * 0.15),
			false
		)


func play_predator_pulse() -> void:
	# Ultra-subtle atmospheric velvet heart-swell (-17 dB)
	_play_on_sfx(_wav_heartbeat, 1.0, -17.0)


func play_power_evolve() -> void:
	# Sparkling celestial celesta & silk-harp harmonic bloom (layers cleanly with scale_up)
	var root: float = maxf(330.0, _get_scale_root() * 1.5)
	var ratios: Array[float] = [1.0, 1.25, 1.5, 2.0, 2.25]
	for i: int in range(ratios.size()):
		var wav: AudioStreamWAV = _wav_celesta if (i % 2 == 0) else _wav_silk_harp
		_schedule_note(
			0.04 + float(i) * 0.065,
			wav,
			(root * ratios[i]) / BASE_NOTE_HZ,
			-10.0,
			false
		)
