extends SceneTree
## Visual QA deterministic 1280x720 screenshot harness launcher for CHARLIE.
##
## Recommended direct invocation (runs scenes/main.tscn with full autoloads):
##   xvfb-run -a -s "-screen 0 1280x720x24" /home/antigravity/.local/bin/godot4 \
##     --rendering-driver opengl3 --audio-driver Dummy --windowed --resolution 1280x720 \
##     --path /home/antigravity/DoraNooo/charlie-mobile-native \
##     -- --capture-shots=/tmp/charlie_shots
##
## Alternative script invocation:
##   xvfb-run -a -s "-screen 0 1280x720x24" /home/antigravity/.local/bin/godot4 \
##     --rendering-driver opengl3 --audio-driver Dummy --windowed --resolution 1280x720 \
##     --path /home/antigravity/DoraNooo/charlie-mobile-native \
##     --script res://tools/capture_shots.gd -- --capture-shots=/tmp/charlie_shots
##
## Outputs:
##   01_title.png    - Redesigned Living Ghibli Title Screen
##   02_prologue.png - Miyazaki Bedroom Window Prologue Cutscene
##   03_quantum.png  - World I Quantique gameplay
##   04_forest.png   - World III Sous-Bois gameplay
##   05_city.png     - World IV Ville Endormie gameplay
##   06_cosmic.png   - World VI Cosmique gameplay

const DEFAULT_OUT_DIR: String = "/tmp/charlie_visual_qa"
const SCALES_SCRIPT_PATH: String = "res://scripts/scales.gd"
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"


func _resolve_out_dir() -> String:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in user_args:
		if arg.begins_with("--capture-shots="):
			return arg.substr("--capture-shots=".length()).strip_edges()
		if not arg.begins_with("-") and not arg.strip_edges().is_empty():
			return arg.strip_edges()
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--capture-shots="):
			return arg.substr("--capture-shots=".length()).strip_edges()
	return DEFAULT_OUT_DIR


func _initialize() -> void:
	var out_dir: String = _resolve_out_dir()
	if root.get_node_or_null("Scales") == null and ResourceLoader.exists(SCALES_SCRIPT_PATH):
		var scales_script: Script = load(SCALES_SCRIPT_PATH) as Script
		if scales_script != null:
			var scales_node: Node = scales_script.new() as Node
			if scales_node != null:
				scales_node.name = "Scales"
				root.add_child(scales_node)

	var main_packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if main_packed == null:
		push_error("[capture_shots] Failed to load %s" % MAIN_SCENE_PATH)
		quit(1)
		return

	var main_node: Node = main_packed.instantiate()
	root.add_child(main_node)

	# If --capture-shots=... was not passed in argv, trigger capture directly
	if not bool(main_node.get("_is_capture_mode")):
		main_node.set("_is_capture_mode", true)
		var audio_node: Node = main_node.get("_audio") as Node
		if audio_node != null and audio_node.has_method("set_muted"):
			audio_node.call("set_muted", true)
		if main_node.has_method("_run_visual_capture"):
			main_node.call_deferred("_run_visual_capture", out_dir)
