extends Node3D

@export var goal_name: String = "GOAL_L1"
@export var step_distance: float = 1.0

var ik_target: Node3D
var is_stepping: bool = false
var raycast: RayCast3D


func _ready() -> void:
	var main = get_parent()
	var robot = main.get_parent()
	ik_target = robot.get_node("GOALS/" + goal_name)
	assert(ik_target != null)
	
	# Create raycast
	raycast = RayCast3D.new()
	raycast.enabled = true
	add_child(raycast)
	raycast.set_collision_mask_value(1, true)
	raycast.target_position = Vector3.DOWN * 10.0


func _process(_delta: float) -> void:
	# Raycast down from leg, update foot target
	raycast.global_position = ik_target.global_position
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var ground_pos = raycast.get_collision_point()
		ik_target.global_position = ground_pos
		
		# Step if IK target drifts from ground
		if not is_stepping and ik_target.global_position.distance_to(ground_pos) > step_distance:
			step(ground_pos)


func step(target_pos: Vector3) -> void:
	if is_stepping:
		return
	
	is_stepping = true
		var half_way = (ik_target.global_position + target_pos) / 2.0
	var apex = half_way + Vector3.UP * 0.4
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ik_target, "global_position", apex, 0.1)
	tween.tween_property(ik_target, "global_position", target_pos, 0.1)
	tween.tween_callback(func(): is_stepping = false)
	
	
