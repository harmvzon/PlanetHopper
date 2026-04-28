extends Node3D

@export var ik_target: Node3D  # The GOAL node for this leg
@export var step_distance: float = 1.5  # How far before re-stepping
@export var step_height: float = 0.4  # Arc height during swing
@export var step_duration: float = 0.2  # Time to complete a step

var is_stepping: bool = false
var ground_position: Vector3 = Vector3.ZERO

# Raycast for terrain detection
var _raycast: RayCast3D
var _default_position: Vector3  # Local rest position


func _ready() -> void:
	_default_position = ik_target.global_position
	_setup_raycast()


func _setup_raycast() -> void:
	_raycast = RayCast3D.new()
	_raycast.enabled = true
	add_child(_raycast)
	# Raycast points downward (relative to robot)
	_raycast.target_position = Vector3.DOWN * 10.0


func update_ground_position() -> void:
	# Cast from IK target downward to find terrain
	_raycast.global_position = ik_target.global_position
	_raycast.force_raycast_update()
	
	if _raycast.is_colliding():
		ground_position = _raycast.get_collision_point()
	else:
		# Fallback: stay at current position
		ground_position = ik_target.global_position


func should_step() -> bool:
	# Step if target is far from ground, and not already stepping
	if is_stepping:
		return false
	var distance_to_ground = ik_target.global_position.distance_to(ground_position)
	return distance_to_ground > step_distance


func step() -> void:
	if is_stepping:
		return
	
	is_stepping = true
	
	# Midpoint of arc
	var midpoint = (ik_target.global_position + ground_position) / 2.0
	var normal = (ik_target.global_position - ground_position).normalized()
	var apex = midpoint + normal * step_height
	
	# Tween: up → down
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(ik_target, "global_position", apex, step_duration * 0.5)
	tween.tween_property(ik_target, "global_position", ground_position, step_duration * 0.5)
	
	tween.tween_callback(func(): is_stepping = false)
