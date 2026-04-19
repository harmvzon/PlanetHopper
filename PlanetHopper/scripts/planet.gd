@tool
extends AnimatableBody3D

# ── Signals ────────────────────────────────────────────────────────────────
signal resources_mined_changed(value: float)
signal planet_depleted()

# ── Enums ──────────────────────────────────────────────────────────────────
enum Biome { LUSH, ARID, LAVA, ICE, METAL, GAS }

# ── Exports ────────────────────────────────────────────────────────────────
@export var radius: float = 1.0 : set = _set_radius
@export var biome: Biome = Biome.LUSH : set = _set_biome
@export var orbit_speed_override: float = 0.0

@export var resources_mined: float = 0.0:
	set(value):
		resources_mined = clampf(value, 0.0, 1.0)
		resources_mined_changed.emit(resources_mined)
		_apply_degradation(resources_mined)
		if resources_mined >= 1.0:
			planet_depleted.emit()

# ── Constants ──────────────────────────────────────────────────────────────
const AREA_RADIUS_MULTIPLIER: float = 1.5
const GRAVITY_PER_RADIUS: float = 10.0
const BASE_ORBIT_SPEED: float = 1.2
const MINE_STEP: float = 0.02

const BIOME_COLORS: Dictionary = {
	Biome.LUSH:  {"a": Color(0.1, 0.5, 0.2), "b": Color(0.3, 0.8, 0.4), "c": Color(0.5, 1.0, 0.6)},
	Biome.ARID:  {"a": Color(0.6, 0.5, 0.2), "b": Color(0.8, 0.7, 0.3), "c": Color(1.0, 0.9, 0.5)},
	Biome.LAVA:  {"a": Color(0.5, 0.1, 0.0), "b": Color(0.9, 0.2, 0.1), "c": Color(1.0, 0.5, 0.0)},
	Biome.ICE:   {"a": Color(0.3, 0.7, 1.0), "b": Color(0.6, 0.85, 1.0), "c": Color(1.0, 1.0, 1.0)},
	Biome.METAL: {"a": Color(0.3, 0.35, 0.4), "b": Color(0.5, 0.55, 0.6), "c": Color(0.7, 0.75, 0.8)},
	Biome.GAS:   {"a": Color(0.4, 0.3, 0.5), "b": Color(0.7, 0.5, 0.9), "c": Color(0.9, 0.7, 1.0)},
}

# ── Wave Spawning ──────────────────────────────────────────────────────────
var _tiers_available: int = 0
var _current_tier: int = -1  # -1 = no tier yet
var _player_on_planet: bool = false
var _active_enemies: Array[Node] = []

# ── Internal ───────────────────────────────────────────────────────────────
var orbit_radius: float = 0.0
var orbit_speed: float = 0.0
var angle: float = 0.0
var surface_velocity: Vector3 = Vector3.ZERO
var _mining_activity: float = 0.0

# ── Node refs ──────────────────────────────────────────────────────────────
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _col_shape: CollisionShape3D = $CollisionShape3D
@onready var _area: Area3D = $Area3D
@onready var _area_shape: CollisionShape3D = $Area3D/CollisionShape3D


# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_apply_radius(radius)
	_apply_biome(biome)
	_tiers_available = max(1, int(radius / 2.0))

	if Engine.is_editor_hint():
		return

	orbit_radius = Vector2(global_position.x, global_position.y).length()
	angle = atan2(global_position.y, global_position.x)

	if orbit_speed_override != 0.0:
		orbit_speed = orbit_speed_override
	else:
		orbit_speed = BASE_ORBIT_SPEED / sqrt(max(orbit_radius, 0.1))

	# Connect Area3D signals
	_area.body_entered.connect(_on_player_entered_area)
	_area.body_exited.connect(_on_player_exited_area)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Decay mining activity over time
	_mining_activity = max(_mining_activity - delta * 3.0, 0.0)

	angle += orbit_speed * delta
	var new_pos := Vector3(
		cos(angle) * orbit_radius,
		sin(angle) * orbit_radius,
		0.0
	)
	surface_velocity = (new_pos - global_position) / delta
	global_position = new_pos
	
	# Wave tier update
	if _player_on_planet:
		_update_wave_tier()


# ── Setters ────────────────────────────────────────────────────────────────

func _set_radius(value: float) -> void:
	radius = value
	if is_inside_tree():
		_apply_radius(radius)


func _set_biome(value: Biome) -> void:
	print("Setting biome to: ", Biome.keys()[value])
	biome = value
	if is_inside_tree():
		_apply_biome(biome)


# ── Apply helpers ──────────────────────────────────────────────────────────

func _apply_radius(r: float) -> void:
	if _mesh == null:
		return

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = r
	sphere_mesh.height = r * 2.0
	_mesh.mesh = sphere_mesh

	var sphere_col := SphereShape3D.new()
	sphere_col.radius = r
	_col_shape.shape = sphere_col

	var area_col := SphereShape3D.new()
	area_col.radius = r * AREA_RADIUS_MULTIPLIER
	_area_shape.shape = area_col

	_area.gravity = r * GRAVITY_PER_RADIUS


func _apply_biome(b: Biome) -> void:
	if _mesh == null or _mesh.mesh == null:
		return

	var colors = BIOME_COLORS[b]
	
	var shader := load("res://mat/planet_noise.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader

	mat.set_shader_parameter("colorA", colors["a"])
	mat.set_shader_parameter("colorB", colors["b"])
	mat.set_shader_parameter("colorC", colors["c"])
	mat.set_shader_parameter("speed", 0.0)
	mat.set_shader_parameter("degradation", 0.0)

	_mesh.material_override = mat  # ← use node-level property, not surface


func _apply_degradation(t: float) -> void:
	if _mesh == null or _mesh.material_override == null:
		return
	
	var current_mat := _mesh.material_override as ShaderMaterial
	print("Applying degradation: ", t)
	
	# Speed driven by mining activity
	var speed := _mining_activity * (1.0 - t * 0.5)
	current_mat.set_shader_parameter("speed", speed)
	
	# Degradation lerps to gray
	current_mat.set_shader_parameter("degradation", t)
	print("Degradation parameter set to: ", t)


# ── Mining ─────────────────────────────────────────────────────────────────

func get_biome_resource() -> int:
	match biome:
		Biome.LUSH:  return Inventory.Item.BIOMASS
		Biome.LAVA:  return Inventory.Item.PYRESTONE
		Biome.ICE:   return Inventory.Item.CRYSITE
		Biome.METAL: return Inventory.Item.FERRITE
		Biome.ARID:  return Inventory.Item.RAW_ORE
		Biome.GAS:   return Inventory.Item.RAW_ORE
		_:           return Inventory.Item.RAW_ORE


func mine_hit() -> void:
	if resources_mined >= 1.0:
		return

	_mining_activity = 1.0

	print("mine_hit called, resources_mined before: ", resources_mined)
	resources_mined += MINE_STEP
	print("mine_hit called, resources_mined after: ", resources_mined)

	Inventory.add(get_biome_resource(), 1)
	Inventory.add(Inventory.Item.RAW_ORE, 1)

	if randf() < 0.05:
		Inventory.add_star_energy(1)
		
# ── Wave System ────────────────────────────────────────────────────────────

func _on_player_entered_area(body: Node3D) -> void:
	if body is RigidBody3D and body.name == "Player":
		_player_on_planet = true


func _on_player_exited_area(body: Node3D) -> void:
	if body is RigidBody3D and body.name == "Player":
		_player_on_planet = false
		_despawn_all_enemies()


func _update_wave_tier() -> void:
	if resources_mined >= 1.0:
		return  # Planet dead
	
	# Calculate tier: 0 to (tiers_available - 1)
	var new_tier: int = min(int(resources_mined * _tiers_available), _tiers_available - 1)
	
	if new_tier > _current_tier:
		_current_tier = new_tier
		print("Wave tier upgraded to: ", _current_tier)
		_spawn_wave()


func _spawn_wave() -> void:
	# Remove dead enemies first
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))
	
	var enemy_count := 3 * (_current_tier + 1)
	print("Spawning ", enemy_count, " enemies for tier ", _current_tier)
	
	for i in range(enemy_count):
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	enemy.mesh = sphere_mesh
	
	# Add to tree FIRST
	add_child(enemy)
	
	# Then set position
	var angle_h := randf() * TAU
	var angle_v := randf() * PI
	var surf_pos := Vector3(
		sin(angle_v) * cos(angle_h),
		sin(angle_v) * sin(angle_h),
		cos(angle_v)
	) * radius * 1.1
	
	enemy.global_position = global_position + surf_pos
	_active_enemies.append(enemy)


func _despawn_all_enemies() -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_current_tier = -1
	print("All enemies despawned")
