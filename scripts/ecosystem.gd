class_name Ecosystem
extends Node2D
## Manages spawning, AI behaviors (prey fleeing, dodgeable predator pursuit, wandering),
## smooth fade-in, viewport culling, and despawning for ~28 balanced creatures around Charlie.

const TARGET_COUNT: int = 28
const MAX_POOL_SIZE: int = 40
const EDIBLE_RATIO: float = 0.96
const PREDATOR_RATIO: float = 1.06

var difficulty: String = "chill"

var _creatures: Array[Creature] = []
var _pool: Array[Creature] = []
var _current_scale_idx: int = 0
var _step_result: Dictionary = {
	"nearest_prey": null,
	"nearest_predator": null,
	"predator_chasing": false,
}


func set_difficulty(mode: String) -> void:
	if Scales.DIFFICULTY_PRESETS.has(mode):
		difficulty = mode
	else:
		difficulty = "chill"
	var preset: Dictionary = _get_preset()
	var show_halo: bool = bool(preset.get("show_danger_halo", true))
	for c: Creature in _creatures:
		if is_instance_valid(c):
			c.show_danger_halo = show_halo


func reset_for_scale(charlie: Charlie, scale_idx: int) -> void:
	_current_scale_idx = clampi(scale_idx, 0, Scales.NUM_SCALES - 1)
	Creature.preload_scale(_current_scale_idx)
	for c: Creature in _creatures:
		_recycle_creature(c)
	_creatures.clear()

	if charlie == null:
		return

	var base_view: Vector2 = Vector2(charlie.world_size * 26.0, charlie.world_size * 15.0)
	for i: int in range(TARGET_COUNT):
		var want_prey: bool = _should_spawn_prey()
		var min_dist: float = charlie.world_size * (4.2 if want_prey else 7.2)
		var max_dist: float = maxf(base_view.x, base_view.y) * 0.68
		var spawn_pos: Vector2 = _random_ring_point(charlie.position, min_dist, max_dist)
		var creature: Creature = _spawn_creature(charlie, _current_scale_idx, spawn_pos, want_prey)
		if creature != null:
			creature.alpha = randf_range(0.15, 0.55)
			creature.modulate.a = creature.alpha


func get_creatures() -> Array[Creature]:
	var active: Array[Creature] = []
	for c: Creature in _creatures:
		if is_instance_valid(c) and c.alive:
			active.append(c)
	return active


func step_ecosystem(
	dt: float,
	charlie: Charlie,
	view_size_world: Vector2,
	scale_idx: int
) -> Dictionary:
	_step_result["nearest_prey"] = null
	_step_result["nearest_predator"] = null
	_step_result["predator_chasing"] = false
	if charlie == null:
		return _step_result

	var step_dt: float = clampf(dt, 0.0, 0.05)
	var next_scale: int = clampi(scale_idx, 0, Scales.NUM_SCALES - 1)
	if next_scale != _current_scale_idx:
		_current_scale_idx = next_scale
		Creature.preload_scale(_current_scale_idx)

	var preset: Dictionary = _get_preset()
	var speed_scale: float = float(preset.get("speed_scale", 1.0))
	var prey_flee: bool = bool(preset.get("prey_flee", true))
	var predator_chase: bool = bool(preset.get("predator_chase", true))
	var chase_mult: float = float(preset.get("chase_mult", 1.0))
	var show_halo: bool = bool(preset.get("show_danger_halo", true))

	var charlie_size: float = charlie.world_size
	var charlie_pos: Vector2 = charlie.position
	var view_half: Vector2 = Vector2(
		maxf(view_size_world.x * 0.5, charlie_size * 10.0),
		maxf(view_size_world.y * 0.5, charlie_size * 6.5)
	)
	var view_half_len: float = view_half.length()
	var despawn_radius_sq: float = (view_half_len * 1.48) * (view_half_len * 1.48)
	var visible_base_r: float = view_half_len * 1.12
	var min_keep_size: float = charlie_size * 0.14
	var max_keep_size: float = charlie_size * 3.4
	var edible_thresh: float = charlie_size * EDIBLE_RATIO
	var pred_thresh: float = charlie_size * PREDATOR_RATIO

	var nearest_prey: Creature = null
	var nearest_prey_dist: float = INF
	var nearest_pred: Creature = null
	var nearest_pred_dist: float = INF
	var predator_chasing: bool = false

	var idx: int = _creatures.size() - 1
	while idx >= 0:
		var c: Creature = _creatures[idx]
		if not is_instance_valid(c):
			_creatures.remove_at(idx)
			idx -= 1
			continue

		if not c.alive:
			_recycle_creature(c)
			_creatures.remove_at(idx)
			idx -= 1
			continue

		var to_charlie: Vector2 = charlie_pos - c.position
		var dist_sq: float = to_charlie.length_squared()

		# Despawn if drifted well outside the active viewport or hopelessly tiny/huge
		if dist_sq > despawn_radius_sq or c.world_size < min_keep_size or c.world_size > max_keep_size:
			_recycle_creature(c)
			_creatures.remove_at(idx)
			idx -= 1
			continue

		var dist: float = sqrt(dist_sq)

		# Smooth edge fade-in & status decay
		if c.alpha < 1.0:
			c.alpha = minf(1.0, c.alpha + step_dt * 1.9)
			c.modulate.a = c.alpha
		if c.burn_flash > 0.0:
			c.burn_flash = maxf(0.0, c.burn_flash - step_dt * 3.4)
		if c.stun_timer > 0.0:
			c.stun_timer = maxf(0.0, c.stun_timer - step_dt)

		# Classify relative to Charlie
		var edible: bool = c.world_size < edible_thresh
		var predator: bool = c.world_size >= pred_thresh
		c.is_edible = edible
		c.is_predator = predator
		c.show_danger_halo = show_halo

		var halo_range: float = maxf(charlie_size * 5.2, c.world_size * 3.8)
		c.proximity_ratio = clampf(1.0 - (dist / maxf(halo_range, 1.0)), 0.0, 1.0)

		if edible and dist < nearest_prey_dist:
			nearest_prey_dist = dist
			nearest_prey = c
		elif predator and dist < nearest_pred_dist:
			nearest_pred_dist = dist
			nearest_pred = c

		# Compute creature AI steering
		var spec_speed: float = float(c.species.get("speed", 1.0))
		var base_speed: float = charlie_size * 2.65 * spec_speed * speed_scale
		var behavior: String = str(c.species.get("behavior", "roam"))

		var desired_dir: Vector2 = _step_ambient_direction(c, behavior, step_dt)
		var target_speed: float = base_speed
		var turn_rate: float = 4.2

		# Prey fleeing when Charlie approaches
		if edible and prey_flee:
			var flee_range: float = charlie_size * 4.4
			if dist < flee_range and dist > 0.001:
				var away_dir: Vector2 = -to_charlie / dist
				var panic: float = clampf(1.0 - (dist / flee_range), 0.0, 1.0)
				desired_dir = desired_dir.lerp(away_dir, 0.35 + panic * 0.65).normalized()
				target_speed = base_speed * (1.0 + panic * 0.55)
				turn_rate = 6.5

		# Dodgeable predator pursuit (bounded turn rate & speed so Charlie can juke)
		elif predator and predator_chase and chase_mult > 0.0 and charlie.invuln_timer <= 0.0:
			var aggro_range: float = maxf(charlie_size * 6.4, c.world_size * 4.6)
			if dist < aggro_range and dist > 0.001:
				var chase_dir: Vector2 = to_charlie / dist
				desired_dir = chase_dir
				# Capped below Charlie's max swim speed (~5.6 * world_size) to remain dodgeable
				var max_chase_speed: float = charlie_size * 4.15 * chase_mult
				target_speed = minf(base_speed * (1.25 * chase_mult), max_chase_speed)
				turn_rate = 2.6 * chase_mult
				predator_chasing = true

		# Smooth turn-rate steering for organic motion
		var desired_angle: float = desired_dir.angle()
		var max_turn: float = turn_rate * step_dt
		var angle_diff: float = wrapf(desired_angle - c.facing_angle, -PI, PI)
		c.facing_angle += clampf(angle_diff, -max_turn, max_turn)

		var target_vel: Vector2 = Vector2.from_angle(c.facing_angle) * target_speed
		c.velocity = c.velocity.lerp(target_vel, 1.0 - exp(-5.5 * step_dt))
		c.position += c.velocity * step_dt
		c.phase += step_dt * (1.4 + spec_speed * 0.55)

		# Viewport culling: skip GPU draw calls & sprite updates for off-screen creatures
		var vis_r: float = visible_base_r + c.world_size * 3.0
		var is_vis: bool = dist_sq < vis_r * vis_r
		c.visible = is_vis
		if is_vis:
			c.update_visuals()

		idx -= 1

	# Replenish ecosystem around the outer viewport edge to maintain ~TARGET_COUNT
	var spawn_min_r: float = view_half_len * 1.04
	var spawn_max_r: float = view_half_len * 1.32
	var spawns_this_frame: int = 0
	while _creatures.size() < TARGET_COUNT and spawns_this_frame < 4:
		var want_prey: bool = _should_spawn_prey()
		var spawn_pos: Vector2 = _random_ring_point(charlie_pos, spawn_min_r, spawn_max_r)
		var spawned: Creature = _spawn_creature(charlie, _current_scale_idx, spawn_pos, want_prey)
		if spawned != null:
			# Nudge newly spawned creatures gently inward toward the play area
			var inward: Vector2 = (charlie_pos - spawn_pos).normalized()
			spawned.facing_angle = inward.angle() + randf_range(-0.65, 0.65)
			spawned.wander_angle = spawned.facing_angle
		spawns_this_frame += 1

	_step_result["nearest_prey"] = nearest_prey
	_step_result["nearest_predator"] = nearest_pred
	_step_result["predator_chasing"] = predator_chasing
	return _step_result


func _step_ambient_direction(c: Creature, behavior: String, dt: float) -> Vector2:
	c.behavior_timer -= dt
	match behavior:
		"orbit":
			c.wander_angle += c.orbit_dir * dt * 0.85
		"dart":
			if c.behavior_timer <= 0.0:
				c.wander_angle += randf_range(-1.4, 1.4)
				c.behavior_timer = randf_range(0.6, 1.6)
		"glide":
			c.wander_angle += sin(c.phase * 0.9) * dt * 0.45
		"drift":
			c.wander_angle += sin(c.phase * 0.5) * dt * 0.25
		"wiggle":
			c.wander_angle += sin(c.phase * 3.8) * dt * 1.65
		"predator":
			if c.behavior_timer <= 0.0:
				c.wander_angle += randf_range(-0.9, 0.9)
				c.behavior_timer = randf_range(1.4, 3.0)
		_:
			if c.behavior_timer <= 0.0:
				c.wander_angle += randf_range(-1.1, 1.1)
				c.behavior_timer = randf_range(1.0, 2.4)
	return Vector2.from_angle(c.wander_angle)


func _spawn_creature(charlie: Charlie, scale_idx: int, spawn_pos: Vector2, want_prey: bool) -> Creature:
	var scale_data: Dictionary = Scales.SCALES[clampi(scale_idx, 0, Scales.NUM_SCALES - 1)]
	var species_list: Array = scale_data.get("species", []) as Array
	if species_list.is_empty():
		return null

	var candidates: Array[Dictionary] = []
	for item: Variant in species_list:
		var spec: Dictionary = item as Dictionary
		var rel: float = float(spec.get("rel", 0.6))
		if want_prey and rel <= 1.0:
			candidates.append(spec)
		elif (not want_prey) and rel > 1.0:
			candidates.append(spec)

	if candidates.is_empty():
		candidates.append(species_list[randi() % species_list.size()] as Dictionary)

	var chosen: Dictionary = candidates[randi() % candidates.size()]
	var base_rel: float = float(chosen.get("rel", 0.6))
	var jitter: float = randf_range(0.88, 1.12)
	var creature_size: float = charlie.world_size * base_rel * jitter

	if want_prey:
		creature_size = clampf(creature_size, charlie.world_size * 0.30, charlie.world_size * 0.88)
	else:
		creature_size = clampf(creature_size, charlie.world_size * 1.14, charlie.world_size * 1.95)

	var creature: Creature = null
	while not _pool.is_empty():
		var pooled: Creature = _pool.pop_back() as Creature
		if is_instance_valid(pooled):
			creature = pooled
			break

	var is_new: bool = creature == null
	if is_new:
		creature = Creature.new()

	creature.is_edible = want_prey
	creature.is_predator = not want_prey
	creature.proximity_ratio = 0.0
	creature.show_danger_halo = bool(_get_preset().get("show_danger_halo", true))
	creature.setup(chosen, scale_idx, creature_size, spawn_pos)
	creature.alive = true
	creature.visible = true
	if is_new:
		add_child(creature)
	_creatures.append(creature)
	return creature


func _recycle_creature(c: Creature) -> void:
	if not is_instance_valid(c):
		return
	c.alive = false
	c.visible = false
	c.set_process(false)
	if _pool.size() < MAX_POOL_SIZE:
		_pool.append(c)
	else:
		c.queue_free()


func _should_spawn_prey() -> bool:
	var preset: Dictionary = _get_preset()
	var target_prey_ratio: float = float(preset.get("prey_ratio", 0.66))
	if _creatures.size() >= 6:
		var prey_count: int = 0
		for c: Creature in _creatures:
			if is_instance_valid(c) and c.alive and c.is_edible:
				prey_count += 1
		var current_ratio: float = float(prey_count) / float(_creatures.size())
		if current_ratio < target_prey_ratio - 0.08:
			return true
		if current_ratio > target_prey_ratio + 0.08:
			return false
	return randf() < target_prey_ratio


func _random_ring_point(center: Vector2, min_r: float, max_r: float) -> Vector2:
	var ang: float = randf_range(0.0, TAU)
	var lo: float = minf(min_r, max_r)
	var hi: float = maxf(min_r, max_r)
	var dist: float = sqrt(randf_range(lo * lo, hi * hi))
	return center + Vector2.from_angle(ang) * dist


func _get_preset() -> Dictionary:
	if Scales.DIFFICULTY_PRESETS.has(difficulty):
		return Scales.DIFFICULTY_PRESETS[difficulty] as Dictionary
	return Scales.DIFFICULTY_PRESETS["chill"] as Dictionary
