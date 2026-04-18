extends RigidBody3D

@export var gravity_strength: float = 9.8
@export var move_strength: float = 8.0
@export var turn_speed: float = 2.0  # radians per second

var planet: Node3D
var facing_angle: float = 0.0  # Current rotation around the planet


func _ready() -> void:
	planet = get_parent().get_node("Planet")


func _physics_process(delta: float) -> void:
	# --- Gravity ---
	var to_planet: Vector3 = planet.global_position - global_position
	var gravity_dir: Vector3 = to_planet.normalized()
	apply_central_force(gravity_dir * gravity_strength)

	# --- Build surface coordinate frame ---
	var up: Vector3 = -gravity_dir
	var world_forward: Vector3 = Vector3(0, 0, -1)

	if abs(up.dot(world_forward)) > 0.99:
		world_forward = Vector3(1, 0, 0)

	var right: Vector3 = up.cross(world_forward).normalized()
	var surface_forward: Vector3 = right.cross(up).normalized()

	# --- Update facing angle based on input ---
	var turn_input := 0.0
	if Input.is_action_pressed("move_left"):  turn_input += 1.0
	if Input.is_action_pressed("move_right"): turn_input -= 1.0

	facing_angle += turn_input * turn_speed * delta

	# --- Calculate forward direction from facing angle ---
	# Rotate surface_forward around the up axis by facing_angle
	var forward: Vector3 = surface_forward.rotated(up, facing_angle)

	# --- Apply movement force ---
	var move_input := 0.0
	if Input.is_action_pressed("move_forward"): move_input += 1.0
	if Input.is_action_pressed("move_back"):    move_input -= 1.0

	if move_input != 0:
		apply_central_force(forward * move_input * move_strength)
