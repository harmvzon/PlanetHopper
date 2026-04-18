@tool
extends AnimatableBody3D

# ── Signals ────────────────────────────────────────────────────────────────
signal resources_mined_changed(value: float)
signal planet_depleted()

# ── Exports ────────────────────────────────────────────────────────────────
@export var planet_data: PlanetData:
	set(val):
		planet_data = val
		if is_inside_tree():
			_rebuild_mesh()

@export var radius: float = 10.0:
	set(val):
		radius = val
		if planet_data:
			planet_data.radius = val
		if is_inside_tree():
			_setup_area()
			_rebuild_mesh()

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
const MINE_STEP: float = 0.02  # 50 hits to fully deplete

# Face normals — one per cube face projected onto sphere
const FACE_NORMALS: Array = [
	Vector3(0, 1, 0),
	Vector3(0, -1, 0),
	Vector3(1, 0, 0),
	Vector3(-1, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
]

# ── Internal ───────────────────────────────────────────────────────────────
var orbit_radius: float = 0.0
var orbit_speed: float = 0.0
var angle: float = 0.0
var surface_velocity: Vector3 = Vector3.ZERO

# ── Node refs ──────────────────────────────────────────────────────────────
@onready var _col_shape: CollisionShape3D = $CollisionShape3D
@onready var _area: Area3D = $Area3D
@onready var _area_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var _faces: Node3D = $Faces


# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_area()
	
	if planet_data:
		planet_data.changed.connect(_rebuild_mesh)
		print("planet_data.changed connected")
		_rebuild_mesh()
	else:
		print("no planet_data assigned")
		
	if Engine.is_editor_hint():
		return

	orbit_radius = Vector2(global_position.x, global_position.y).length()
	angle = atan2(global_position.y, global_position.x)

	if orbit_speed_override != 0.0:
		orbit_speed = orbit_speed_override
	else:
		orbit_speed = BASE_ORBIT_SPEED / sqrt(max(orbit_radius, 0.1))

	if planet_data:
		_rebuild_mesh()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	angle += orbit_speed * delta
	var new_pos := Vector3(
		cos(angle) * orbit_radius,
		sin(angle) * orbit_radius,
		0.0
	)
	surface_velocity = (new_pos - global_position) / delta
	global_position = new_pos


# ── Setup ──────────────────────────────────────────────────────────────────

func _setup_area() -> void:
	var area_col := SphereShape3D.new()
	area_col.radius = radius * AREA_RADIUS_MULTIPLIER
	_area_shape.shape = area_col
	_area.gravity = radius * GRAVITY_PER_RADIUS


# ── Mesh ───────────────────────────────────────────────────────────────────

var _rebuild_pending: bool = false

func _rebuild_mesh() -> void:
	if planet_data == null or _faces == null:
		print("rebuild blocked: planet_data=", planet_data, " faces=", _faces)
		return
	if _rebuild_pending:
		print("rebuild blocked: pending")
		return
	_rebuild_pending = true
	print("rebuild started, radius=", radius, " face count=", _faces.get_child_count())

	planet_data.radius = radius

	for i in FACE_NORMALS.size():
		var face := _faces.get_child(i) as PlanetMeshFace
		if face:
			print("regenerating face ", i)
			face.normal = FACE_NORMALS[i]
			face.regenerate_mesh(planet_data)

	call_deferred("_deferred_collision_rebuild")

func _finish_rebuild() -> void:
	_rebuild_collision()
	_rebuild_pending = false
	print("rebuild finished")

func _rebuild_collision() -> void:
	# Combine all face meshes into one ConcavePolygonShape3D
	var vertices := PackedVector3Array()

	for child in _faces.get_children():
		var face := child as MeshInstance3D
		if face == null or face.mesh == null:
			continue
		var mesh_arrays := face.mesh.surface_get_arrays(0)
		var face_verts: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
		var face_indices: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
		for idx in face_indices:
			vertices.append(face_verts[idx])

	if vertices.size() == 0:
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(vertices)
	_col_shape.shape = shape


# ── Degradation ────────────────────────────────────────────────────────────

func _apply_degradation(t: float) -> void:
	for child in _faces.get_children():
		var face := child as MeshInstance3D
		if face and face.material_override:
			face.material_override.set_shader_parameter("degradation", t)


# ── Mining ─────────────────────────────────────────────────────────────────

func get_biome_resource() -> int:
	# Biome is now driven by PlanetData gradient + noise
	# For now return RAW_ORE as default
	# TODO: assign biome type as an export once art direction is clearer
	return Inventory.Item.RAW_ORE


func mine_hit() -> void:
	if resources_mined >= 1.0:
		return

	print("mine_hit called, resources_mined before: ", resources_mined)
	resources_mined += MINE_STEP
	print("mine_hit called, resources_mined after: ", resources_mined)

	Inventory.add(get_biome_resource(), 1)
	Inventory.add(Inventory.Item.RAW_ORE, 1)

	if randf() < 0.05:
		Inventory.add_star_energy(1)
