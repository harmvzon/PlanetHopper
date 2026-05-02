extends Node3D

@export_category("Movement")
@export var move_speed: float = 5.0

@export_category("Facing")
@export var face_left_yaw_deg: float = 90.0
@export var face_right_yaw_deg: float = -90.0
@export var turn_instant: bool = true
@export var turn_speed: float = 20.0

var velocity_x: float = 0.0
var move_input: float = 0.0
var facing_right: bool = true
var is_moving: bool = false

func _physics_process(delta: float) -> void:
	move_input = Input.get_axis("move_left", "move_right")
	is_moving = not is_zero_approx(move_input)

	# Store this so other scripts can use clean motion data.
	velocity_x = move_input * move_speed

	# Move only on X for your side-view setup.
	global_position.x += velocity_x * delta

	if is_moving:
		_update_facing(delta)

func _update_facing(delta: float) -> void:
	if move_input > 0.0:
		facing_right = true
	elif move_input < 0.0:
		facing_right = false

	var target_yaw_deg: float = face_right_yaw_deg
	if not facing_right:
		target_yaw_deg = face_left_yaw_deg

	var target_yaw: float = deg_to_rad(target_yaw_deg)

	if turn_instant:
		rotation.y = target_yaw
	else:
		var t: float = 1.0 - exp(-turn_speed * delta)
		rotation.y = lerp_angle(rotation.y, target_yaw, t)
	
