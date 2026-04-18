extends Camera3D

@export var target: Node3D  # The ball
@export var planet: Node3D
@export var follow_distance: float = 8.0
@export var follow_height: float = 4.0
@export var follow_speed: float = 5.0


func _physics_process(delta: float) -> void:
	if not target or not planet:
		return

	# Surface normal at ball position
	var to_planet: Vector3 = planet.global_position - target.global_position
	var up: Vector3 = -to_planet.normalized()

	# Ball's forward direction
	var ball_forward: Vector3 = -target.global_transform.basis.z

	# Target camera position: behind and above the ball
	var offset: Vector3 = (-ball_forward * follow_distance) + (up * follow_height)
	var target_position: Vector3 = target.global_position + offset

	# Smooth follow
	global_position = global_position.lerp(target_position, follow_speed * delta)

	# Look at ball
	look_at(target.global_position, up)
