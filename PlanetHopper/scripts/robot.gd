extends Node3D

@export var move_speed: float = 5.0
@export var turn_speed: float = 1.0  # -1, 0, or 1
@export var ground_offset : float = 0.5

@export var L1 : Node3D
@export var L2 : Node3D
@export var L3 : Node3D
@export var R1 : Node3D
@export var R2 : Node3D
@export var R3 : Node3D

func _process(delta: float) -> void:
	
	var plane1 = Plane(L1.global_position, R2.global_position, L3.global_position)
	var plane2 = Plane(R1.global_position, L2.global_position, R3.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	#var target_basis = _basis_from_normal(avg_normal)
	#transform.basis = lerp(transform.basis, target_basis, move_speed * delta).orthonormalized()
	
	#var avg = (L1.position + L2.position + L3.position + R1.position + R2.position + R3.position) / 6
	#var target_pos = avg + transform.basis.y * ground_offset
	#var distance = transform.basis.y.dot(target_pos - position)
	#position = lerp(position, position + transform.basis.y * distance, move_speed * delta)
		
	
	_handle_movement(delta)
	
	
	
func _handle_movement(delta):
	var dir = Input.get_axis("move_left", "move_right")
	translate(Vector3(0, 0, -dir) * move_speed * delta)
	
	var a_dir = Input.get_axis("move_forward", "move_back")
	rotate_object_local(Vector3.UP, a_dir * turn_speed * delta)

func _basis_from_normal(normal: Vector3) -> Basis:
	var result = Basis()
	result.x *= scale.x
	result.y *= scale.y
	result.z *= scale.z
	
	return result
