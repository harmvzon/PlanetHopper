extends Node3D

@export var step_target: Node3D
@export var step_height: float = 0.35
@export var step_time: float = 0.12

var is_stepping := false

func needs_step(step_distance: float) -> bool:
	if step_target == null:
		return false

	return global_position.distance_to(step_target.global_position) > step_distance

func step_to(target_pos: Vector3, up_dir: Vector3) -> void:
	if is_stepping:
		return

	is_stepping = true

	var start_pos := global_position
	var mid_pos := (start_pos + target_pos) * 0.5
	mid_pos += up_dir.normalized() * step_height

	var tween := get_tree().create_tween()
	tween.tween_property(self, "global_position", mid_pos, step_time * 0.5)
	tween.tween_property(self, "global_position", target_pos, step_time * 0.5)
	tween.tween_callback(func():
		is_stepping = false
	)
