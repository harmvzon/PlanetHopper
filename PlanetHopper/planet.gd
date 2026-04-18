@tool  # ← runs this script in the editor
extends AnimatableBody3D

enum Biome { LUSH, ARID, LAVA, ICE, METAL, GAS }

@export var radius: float = 1.0 : set = _set_radius
@export var biome: Biome = Biome.LUSH : set = _set_biome  # ← setter added

@export var orbit_speed_override: float = 0.0

const AREA_RADIUS_MULTIPLIER: float = 3.0
const GRAVITY_PER_RADIUS: float = 10.0
const BASE_ORBIT_SPEED: float = 1.2

# Biome colors — extend this as you add biomes
const BIOME_COLORS: Dictionary = {
	Biome.LUSH:  Color(0.2, 0.8, 0.3),
	Biome.ARID:  Color(0.8, 0.6, 0.3),
	Biome.LAVA:  Color(0.9, 0.2, 0.1),
	Biome.ICE:   Color(0.6, 0.85, 1.0),
	Biome.METAL: Color(0.5, 0.55, 0.6),
	Biome.GAS:   Color(0.7, 0.5, 0.9),
}

var orbit_radius: float = 0.0
var orbit_speed: float = 0.0
var angle: float = 0.0


func _ready() -> void:
	_apply_radius(radius)
	_apply_biome(biome)

	# Skip orbit setup in editor
	if Engine.is_editor_hint():
		return

	orbit_radius = Vector2(global_position.x, global_position.y).length()
	angle = atan2(global_position.y, global_position.x)

	if orbit_speed_override != 0.0:
		orbit_speed = orbit_speed_override
	else:
		orbit_speed = BASE_ORBIT_SPEED / sqrt(max(orbit_radius, 0.1))


func _set_radius(value: float) -> void:
	radius = value
	if is_inside_tree():
		_apply_radius(radius)


func _set_biome(value: Biome) -> void:
	biome = value
	if is_inside_tree():
		_apply_biome(biome)


func _apply_radius(r: float) -> void:
	var mesh_instance := get_node("MeshInstance3D")
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = r
	sphere_mesh.height = r * 2.0
	mesh_instance.mesh = sphere_mesh

	var col_shape := get_node("CollisionShape3D")
	var sphere_col := SphereShape3D.new()
	sphere_col.radius = r
	col_shape.shape = sphere_col

	var area_shape := get_node("Area3D/CollisionShape3D")
	var area_col := SphereShape3D.new()
	area_col.radius = r * AREA_RADIUS_MULTIPLIER
	area_shape.shape = area_col

	var area := get_node("Area3D")
	area.gravity = r * GRAVITY_PER_RADIUS

	# Update biome color in case material already exists
	_apply_biome(biome)


func _apply_biome(b: Biome) -> void:
	var mesh_instance := get_node("MeshInstance3D")
	if mesh_instance.mesh == null:
		return

	# Always create a new material — prevents resource sharing between instances
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BIOME_COLORS[b]
	mesh_instance.set_surface_override_material(0, mat)


func _physics_process(delta: float) -> void:
	# Don't orbit in editor
	if Engine.is_editor_hint():
		return

	angle += orbit_speed * delta
	global_position = Vector3(
		cos(angle) * orbit_radius,
		sin(angle) * orbit_radius,
		0.0
	)
