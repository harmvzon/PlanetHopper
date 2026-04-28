extends Node3D

# References
@onready var legs: Array[Node3D] = [
	$L1, $L2, $L3, $R1, $R2, $R3
]
@onready var body: Node3D = $BODY

# Gait config
@export var body_height: float = 1.0
@export var body_smooth: float = 0.15
@export var body_orient_speed: float = 0.2

# Tripod groups: alternates which set of legs steps
var _gait_group: int = 0  # 0 or 1
var _step_cooldown: float = 0.0

# Group A steps first: [L1, R2, L3]
# Group B steps second: [R1, L2, R3]
var _group_a: Array[int] = [0, 4, 2]  # Indices into legs array
var _group_b: Array[int] = [3, 1, 5]


func _ready() -> void:
	for leg in legs:
		# Ensure each leg has a LegController
		assert(leg is Node3D, "Leg %s missing LegController" % leg.name)


func _process(delta: float) -> void:
	# Update all legs' ground detection
	for leg in legs:
		leg.update_ground_position()
	
	# Gait timing
	_step_cooldown -= delta
	if _step_cooldown <= 0.0:
		_attempt_step_group()
		_step_cooldown = 0.3  # Delay before next group steps
	
	# Body positioning
	_update_body_transform()


func _attempt_step_group() -> void:
	var group = _group_a if _gait_group == 0 else _group_b
	
	# Check if any leg in group wants to step
	var can_step = false
	for leg_idx in group:
		if legs[leg_idx].should_step():
			can_step = true
			break
	
	if can_step:
		for leg_idx in group:
			legs[leg_idx].step()
		_gait_group = 1 - _gait_group  # Swap group


func _update_body_transform() -> void:
	# Find support feet (not currently stepping)
	var support_feet: Array[Vector3] = []
	var support_normals: Array[Vector3] = []
	
	for leg in legs:
		if not leg.is_stepping:
			support_feet.append(leg.ground_position)
			# Normal points away from planet (simplified)
			support_normals.append(
				(leg.ground_position - get_parent().global_position).normalized()
			)
	
	if support_feet.is_empty():
		return
	
	# Average position of support feet
	var avg_pos = Vector3.ZERO
	for pos in support_feet:
		avg_pos += pos
	avg_pos /= support_feet.size()
	
	# Body offset: up from support plane
	var avg_normal = Vector3.ZERO
	for normal in support_normals:
		avg_normal += normal
	avg_normal = (avg_normal / support_normals.size()).normalized()
	
	var target_pos = avg_pos + avg_normal * body_height
	body.global_position = body.global_position.lerp(target_pos, body_smooth)
	
	# Orient body to surface normal
	var target_basis = _basis_from_normal(avg_normal)
	body.global_transform.basis = body.global_transform.basis.slerp(
		target_basis, 
		body_orient_speed
	).orthonormalized()


func _basis_from_normal(normal: Vector3) -> Basis:
	# Construct basis where Y = surface normal
	var forward = body.global_transform.basis.z
	if abs(normal.dot(forward)) > 0.99:
		forward = body.global_transform.basis.x
	
	var right = forward.cross(normal).normalized()
	var new_forward = normal.cross(right).normalized()
	
	return Basis(right, normal, -new_forward)
