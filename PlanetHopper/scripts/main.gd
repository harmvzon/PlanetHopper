extends Node3D

@export var robot_node: Node3D

@export_category("Height")
@export var body_height_offset: float = 1.25
@export var bob_amount: float = 0.06
@export var bob_frequency: float = 8.0
@export var movement_speed_reference: float = 5.0

@export_category("Position Spring")
@export var x_stiffness: float = 24.0
@export var x_damping: float = 0.74
@export var lag_distance: float = 0.20

@export_category("Rotation Spring")
@export var yaw_stiffness: float = 14.0
@export var yaw_damping: float = 0.78
@export var main_yaw_offset_deg: float = 90.0

@export_category("Axis Copy")
@export var copy_z: bool = true

var _x_velocity: float = 0.0
var _yaw_velocity: float = 0.0
var _bob_phase: float = 0.0

func _ready() -> void:
	if robot_node == null:
		robot_node = get_parent_node_3d()

	top_level = true

	if robot_node != null:
		global_position = robot_node.global_position
		global_rotation = robot_node.global_rotation

func _physics_process(delta: float) -> void:
	if robot_node == null:
		return

	var robot_pos: Vector3 = robot_node.global_position
	var robot_velocity_x: float = float(robot_node.get("velocity_x"))
	var robot_is_moving: bool = bool(robot_node.get("is_moving"))

	var target_yaw: float = robot_node.global_rotation.y + deg_to_rad(
		main_yaw_offset_deg
	)

	var moving_amount: float = 0.0
	if movement_speed_reference > 0.0:
		moving_amount = clamp(
			abs(robot_velocity_x) / movement_speed_reference,
			0.0,
			1.0
		)

	if robot_is_moving:
		_bob_phase += delta * bob_frequency * (0.5 + moving_amount)

	var bob: float = sin(_bob_phase) * bob_amount * moving_amount

	var desired_x: float = robot_pos.x
	if abs(robot_velocity_x) > 0.01:
		desired_x -= sign(robot_velocity_x) * lag_distance

	_spring_x(desired_x, delta)

	global_position.y = robot_pos.y + body_height_offset + bob

	if copy_z:
		global_position.z = robot_pos.z

	_spring_yaw(target_yaw, delta)

func _spring_x(target_x: float, delta: float) -> void:
	var delta_x: float = target_x - global_position.x
	_x_velocity += delta_x * x_stiffness * delta
	_x_velocity *= x_damping
	global_position.x += _x_velocity * delta

func _spring_yaw(target_yaw: float, delta: float) -> void:
	var current_yaw: float = global_rotation.y
	var delta_yaw: float = wrapf(target_yaw - current_yaw, -PI, PI)

	_yaw_velocity += delta_yaw * yaw_stiffness * delta
	_yaw_velocity *= yaw_damping
	current_yaw += _yaw_velocity * delta

	global_rotation.y = current_yaw
