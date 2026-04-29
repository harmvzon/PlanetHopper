extends RayCast3D

@export var step_target: Node3D

func _physics_process(_delta: float) -> void:
	if not is_colliding():
		return

	step_target.global_position = get_collision_point()
