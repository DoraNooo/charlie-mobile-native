extends Node
## Autoload singleton defining Charlie's 6 bioluminescent scales, 30 species,
## palettes, difficulty presets, and logarithmic size helpers.

const BASE_SIZE: float = 28.0
const SCALE_FACTOR: float = 4.0
const NUM_SCALES: int = 6
const MAX_SIZE: float = BASE_SIZE * 4096.0 # BASE_SIZE * 4^6

const DIFFICULTY_PRESETS: Dictionary = {
	"toddler": {
		"label": "Tout-petit · 3 ans",
		"desc": "Sans danger · Idéal dès 3 ans : Charlie rebondit doucement sans jamais perdre !",
		"prey_ratio": 0.86,
		"speed_scale": 0.58,
		"prey_flee": false,
		"predator_chase": false,
		"chase_mult": 0.0,
		"show_danger_halo": false,
		"spit_cd": 1.4,
		"dash_cd": 1.6,
	},
	"chill": {
		"label": "Chill",
		"desc": "Rythme doux, prédateurs esquivables et 3 gouttelettes de vie qui se régénèrent.",
		"prey_ratio": 0.66,
		"speed_scale": 1.0,
		"prey_flee": true,
		"predator_chase": true,
		"chase_mult": 1.0,
		"show_danger_halo": true,
		"spit_cd": 2.4,
		"dash_cd": 2.8,
	},
	"wild": {
		"label": "Sauvage",
		"desc": "Chasse intense : prédateurs plus vifs, proies agiles et réflexes affûtés !",
		"prey_ratio": 0.56,
		"speed_scale": 1.18,
		"prey_flee": true,
		"predator_chase": true,
		"chase_mult": 1.15,
		"show_danger_halo": true,
		"spit_cd": 2.6,
		"dash_cd": 3.0,
	},
}

const SCALES: Array[Dictionary] = [
	{
		"id": "quantum", "index": 0, "roman": "I", "name": "Quantique",
		"poetic_title": "L'Infiniment Petit", "unit_sub": "10⁻¹⁰ m · Monde Quantique",
		"bg_inner": Color(0.055, 0.153, 0.200), "bg_outer": Color(0.024, 0.067, 0.098),
		"mote_color": Color(0.431, 0.906, 0.855),
		"ambient": Color(0.080, 0.220, 0.280), "rim": Color(0.431, 0.906, 0.855),
		"blob_core": Color(1.0, 0.72, 0.48), "blob_edge": Color(0.98, 0.38, 0.40), "blob_glow": Color(1.0, 0.48, 0.36),
		"music_root": 329.63,
		"species": [
			{"kind": "quark", "name": "Quark", "rel": 0.36, "speed": 1.15, "color": Color("#67e8f9"), "accent": Color("#cffafe"), "behavior": "orbit"},
			{"kind": "electron", "name": "Électron", "rel": 0.55, "speed": 1.35, "color": Color("#5eead4"), "accent": Color("#f0fdfa"), "behavior": "dart"},
			{"kind": "photon", "name": "Photon", "rel": 0.78, "speed": 1.45, "color": Color("#fde68a"), "accent": Color("#fffbeb"), "behavior": "glide"},
			{"kind": "atom", "name": "Atome", "rel": 1.15, "speed": 0.85, "color": Color("#7dd3fc"), "accent": Color("#bae6fd"), "behavior": "roam"},
			{"kind": "molecule", "name": "Molécule", "rel": 1.65, "speed": 0.72, "color": Color("#fda4af"), "accent": Color("#ffe4e6"), "behavior": "predator"},
		],
	},
	{
		"id": "micro", "index": 1, "roman": "II", "name": "Microscopique",
		"poetic_title": "La Goutte d'Eau", "unit_sub": "10⁻⁶ m · Monde Microscopique",
		"bg_inner": Color(0.051, 0.204, 0.220), "bg_outer": Color(0.020, 0.094, 0.118),
		"mote_color": Color(0.525, 0.937, 0.675),
		"ambient": Color(0.075, 0.260, 0.270), "rim": Color(0.480, 0.950, 0.760),
		"blob_core": Color(1.0, 0.76, 0.50), "blob_edge": Color(0.96, 0.43, 0.41), "blob_glow": Color(1.0, 0.56, 0.34),
		"music_root": 293.66,
		"species": [
			{"kind": "spore", "name": "Spore", "rel": 0.38, "speed": 0.80, "color": Color("#86efac"), "accent": Color("#dcfce7"), "behavior": "drift"},
			{"kind": "bacteria", "name": "Bactérie", "rel": 0.58, "speed": 1.25, "color": Color("#5eead4"), "accent": Color("#ccfbf1"), "behavior": "wiggle"},
			{"kind": "amoeba", "name": "Amibe", "rel": 0.84, "speed": 0.90, "color": Color("#a7f3d0"), "accent": Color("#ecfdf5"), "behavior": "roam"},
			{"kind": "diatom", "name": "Diatomée", "rel": 1.18, "speed": 0.75, "color": Color("#fcd34d"), "accent": Color("#fef3c7"), "behavior": "glide"},
			{"kind": "tardigrade", "name": "Tardigrade", "rel": 1.70, "speed": 0.82, "color": Color("#fb923c"), "accent": Color("#ffedd5"), "behavior": "predator"},
		],
	},
	{
		"id": "forest", "index": 2, "roman": "III", "name": "Sous-Bois",
		"poetic_title": "La Rosée Nocturne", "unit_sub": "10⁻² m · Monde des Insectes",
		"bg_inner": Color(0.082, 0.204, 0.153), "bg_outer": Color(0.031, 0.098, 0.078),
		"mote_color": Color(0.992, 0.878, 0.510),
		"ambient": Color(0.110, 0.260, 0.180), "rim": Color(0.950, 0.860, 0.480),
		"blob_core": Color(1.0, 0.78, 0.50), "blob_edge": Color(0.94, 0.42, 0.34), "blob_glow": Color(1.0, 0.62, 0.28),
		"music_root": 261.63,
		"species": [
			{"kind": "ant", "name": "Fourmi", "rel": 0.38, "speed": 1.05, "color": Color("#d97706"), "accent": Color("#fde68a"), "behavior": "roam"},
			{"kind": "firefly", "name": "Luciole", "rel": 0.56, "speed": 1.35, "color": Color("#fde047"), "accent": Color("#fef9c3"), "behavior": "dart"},
			{"kind": "ladybug", "name": "Coccinelle", "rel": 0.82, "speed": 1.00, "color": Color("#ef4444"), "accent": Color("#fee2e2"), "behavior": "roam"},
			{"kind": "moth", "name": "Papillon de nuit", "rel": 1.20, "speed": 1.10, "color": Color("#f59e0b"), "accent": Color("#fef3c7"), "behavior": "glide"},
			{"kind": "frog", "name": "Grenouille", "rel": 1.72, "speed": 0.95, "color": Color("#22c55e"), "accent": Color("#bbf7d0"), "behavior": "predator"},
		],
	},
	{
		"id": "city", "index": 3, "roman": "IV", "name": "Nocturne",
		"poetic_title": "La Ville Endormie", "unit_sub": "10¹ m · Monde Terrestre",
		"bg_inner": Color(0.094, 0.161, 0.247), "bg_outer": Color(0.039, 0.075, 0.133),
		"mote_color": Color(0.984, 0.749, 0.471),
		"ambient": Color(0.130, 0.200, 0.320), "rim": Color(0.980, 0.740, 0.460),
		"blob_core": Color(1.0, 0.73, 0.50), "blob_edge": Color(0.95, 0.38, 0.42), "blob_glow": Color(1.0, 0.46, 0.42),
		"music_root": 246.94,
		"species": [
			{"kind": "lantern", "name": "Lanterne céleste", "rel": 0.38, "speed": 0.65, "color": Color("#fdba74"), "accent": Color("#ffedd5"), "behavior": "drift"},
			{"kind": "owl", "name": "Chouette nocturne", "rel": 0.60, "speed": 1.15, "color": Color("#c08457"), "accent": Color("#fef08a"), "behavior": "glide"},
			{"kind": "car", "name": "Voiture", "rel": 0.88, "speed": 1.30, "color": Color("#60a5fa"), "accent": Color("#fef08a"), "behavior": "glide"},
			{"kind": "helicopter", "name": "Hélicoptère", "rel": 1.24, "speed": 1.05, "color": Color("#38bdf8"), "accent": Color("#fef3c7"), "behavior": "roam"},
			{"kind": "blimp", "name": "Dirigeable", "rel": 1.75, "speed": 0.72, "color": Color("#f87171"), "accent": Color("#fde68a"), "behavior": "predator"},
		],
	},
	{
		"id": "planetary", "index": 4, "roman": "V", "name": "Planétaire",
		"poetic_title": "Le Ballet Orbital", "unit_sub": "10⁷ m · Monde Planétaire",
		"bg_inner": Color(0.063, 0.118, 0.204), "bg_outer": Color(0.020, 0.039, 0.078),
		"mote_color": Color(0.729, 0.902, 0.992),
		"ambient": Color(0.090, 0.170, 0.290), "rim": Color(0.700, 0.890, 1.000),
		"blob_core": Color(1.0, 0.76, 0.54), "blob_edge": Color(0.93, 0.38, 0.46), "blob_glow": Color(0.98, 0.44, 0.56),
		"music_root": 220.00,
		"species": [
			{"kind": "asteroid", "name": "Astéroïde", "rel": 0.38, "speed": 0.90, "color": Color("#cbd5e1"), "accent": Color("#f1f5f9"), "behavior": "orbit"},
			{"kind": "comet", "name": "Comète", "rel": 0.60, "speed": 1.50, "color": Color("#7dd3fc"), "accent": Color("#e0f2fe"), "behavior": "dart"},
			{"kind": "moon", "name": "Lune", "rel": 0.86, "speed": 0.75, "color": Color("#e2e8f0"), "accent": Color("#ffffff"), "behavior": "orbit"},
			{"kind": "planet", "name": "Planète", "rel": 1.25, "speed": 0.65, "color": Color("#38bdf8"), "accent": Color("#4ade80"), "behavior": "roam"},
			{"kind": "ringed", "name": "Géante à anneaux", "rel": 1.78, "speed": 0.62, "color": Color("#fbbf24"), "accent": Color("#fef3c7"), "behavior": "predator"},
		],
	},
	{
		"id": "cosmic", "index": 5, "roman": "VI", "name": "Cosmique",
		"poetic_title": "L'Infiniment Grand", "unit_sub": "10²¹ m · Monde Cosmique",
		"bg_inner": Color(0.059, 0.114, 0.173), "bg_outer": Color(0.016, 0.027, 0.059),
		"mote_color": Color(0.996, 0.941, 0.780),
		"ambient": Color(0.120, 0.140, 0.260), "rim": Color(1.000, 0.900, 0.740),
		"blob_core": Color(1.0, 0.88, 0.61), "blob_edge": Color(0.96, 0.45, 0.49), "blob_glow": Color(1.0, 0.72, 0.38),
		"music_root": 196.00,
		"species": [
			{"kind": "star", "name": "Étoile naine", "rel": 0.38, "speed": 0.85, "color": Color("#fef08a"), "accent": Color("#ffffff"), "behavior": "orbit"},
			{"kind": "nebula", "name": "Nébuleuse", "rel": 0.62, "speed": 0.70, "color": Color("#f9a8d4"), "accent": Color("#fbcfe8"), "behavior": "drift"},
			{"kind": "solar", "name": "Système solaire", "rel": 0.90, "speed": 0.78, "color": Color("#fcd34d"), "accent": Color("#93c5fd"), "behavior": "roam"},
			{"kind": "blackhole", "name": "Trou noir", "rel": 1.28, "speed": 0.72, "color": Color("#fb923c"), "accent": Color("#fed7aa"), "behavior": "predator"},
			{"kind": "galaxy", "name": "Galaxie spirale", "rel": 1.80, "speed": 0.58, "color": Color("#7dd3fc"), "accent": Color("#fde68a"), "behavior": "predator"},
		],
	},
]


func size_to_progress(world_size: float) -> float:
	var ratio: float = maxf(1.0, world_size / BASE_SIZE)
	return log(ratio) / log(SCALE_FACTOR)


func scale_start_size(idx: int) -> float:
	return BASE_SIZE * pow(SCALE_FACTOR, clampi(idx, 0, NUM_SCALES - 1))


func get_blended_palette(progress: float) -> Dictionary:
	var p: float = clampf(progress, 0.0, float(NUM_SCALES) - 0.0001)
	var idx: int = int(floor(p))
	var nxt: int = mini(NUM_SCALES - 1, idx + 1)
	var frac: float = p - float(idx)
	var blend: float = (frac - 0.65) / 0.35 if frac > 0.65 else 0.0
	var cur: Dictionary = SCALES[idx]
	var nx: Dictionary = SCALES[nxt]
	var mote: Color = (cur["mote_color"] as Color).lerp(nx["mote_color"], blend)
	var ambient: Color = (cur["ambient"] as Color).lerp(nx["ambient"], blend)
	var rim: Color = (cur["rim"] as Color).lerp(nx["rim"], blend)
	return {
		"scale_index": idx,
		"scale": cur,
		"bg_inner": (cur["bg_inner"] as Color).lerp(nx["bg_inner"], blend),
		"bg_outer": (cur["bg_outer"] as Color).lerp(nx["bg_outer"], blend),
		"mote_color": mote,
		"mote": mote,
		"accent": mote,
		"ambient": ambient,
		"rim": rim,
		"blob_core": (cur["blob_core"] as Color).lerp(nx["blob_core"], blend),
		"blob_edge": (cur["blob_edge"] as Color).lerp(nx["blob_edge"], blend),
		"blob_glow": (cur["blob_glow"] as Color).lerp(nx["blob_glow"], blend),
	}


func format_scientific_size(progress: float) -> String:
	var p: float = clampf(progress, 0.0, float(NUM_SCALES) + 0.5)
	if p < 1.0:
		var v: float = 0.1 * pow(100.0, p)
		return "%.1f nm" % v if v < 10.0 else "%d nm" % roundi(v)
	if p < 2.0:
		var v: float = pow(500.0, p - 1.0)
		return "%.1f µm" % v if v < 10.0 else "%d µm" % roundi(v)
	if p < 3.0:
		var v: float = pow(300.0, p - 2.0)
		return "%.1f mm" % v if v < 100.0 else "%.1f cm" % (v / 10.0)
	if p < 4.0:
		var v: float = 0.8 * pow(500.0, p - 3.0)
		return "%.1f m" % v if v < 100.0 else "%d m" % roundi(v)
	if p < 5.0:
		var v: float = 50.0 * pow(2500.0, p - 4.0)
		return "%d km" % roundi(v) if v < 1000.0 else "%.1fk km" % (v / 1000.0)
	var ly: float = 0.01 * pow(1e7, p - 5.0)
	if ly < 1.0:
		return "%.2f al" % ly
	return "%d al" % roundi(ly) if ly < 1000.0 else "%.1fk al" % (ly / 1000.0)
