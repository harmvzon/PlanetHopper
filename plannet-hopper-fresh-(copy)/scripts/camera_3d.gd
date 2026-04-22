extends Camera3D

			
@export var follow_speed: float = 15.0
@export var zoom_grounded: float = 20.0
@export var zoom_space: float = 120.0
@export var zoom_speed: float = 3.0

var target: Node3D
var _current_zoom: float = 20.0
var _not_grounded_timer: float = 0.0
const ZOOM_OUT_DELAY: float = 0.3  # seconds before zoom triggers


func _ready() -> void:
	target = get_parent().get_node("Player")
	_current_zoom = zoom_grounded


func _process(delta: float) -> void:
	var grounded: bool = target.get("is_grounded")
	var charging: bool = target.get("is_charging")

	# Only zoom out if not grounded for longer than the delay
	if grounded and not charging:
		_not_grounded_timer = 0.0
	else:
		_not_grounded_timer += delta

	var target_zoom: float = zoom_grounded
	if _not_grounded_timer > ZOOM_OUT_DELAY:
		target_zoom = zoom_space

	_current_zoom = lerp(_current_zoom, target_zoom, zoom_speed * delta)

	# Slight lerp on position for subtle follow delay
	var goal := Vector3(
		target.global_position.x,
		target.global_position.y,
		_current_zoom
	)
	global_position = global_position.lerp(goal, follow_speed * delta)

	# Rotate to match player surface up
	var up: Vector3 = target.get("surface_up")
	if up != Vector3.ZERO:
		var angle := Vector2.UP.angle_to(Vector2(up.x, up.y))
		rotation.z = angle
