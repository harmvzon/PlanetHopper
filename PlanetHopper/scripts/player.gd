extends RigidBody3D

# Movement
@export var move_speed: float = 8.0
@export var max_charge: float = 2.0
@export var jump_force: float = 15.0
@export var thrust_force: float = 10.0
@export var rotate_speed: float = 2.0

# Trajectory
@export var trajectory_steps: int = 60
@export var trajectory_step_size: float = 0.05

# State
enum State { GROUNDED, LAUNCHED, FREE }
var state: State = State.GROUNDED

# Internal
var _gravity_direction: Vector3 = Vector3.ZERO
var _on_floor: bool = false
var _charge: float = 0.0
var _area_count: int = 0
var _trajectory_dots: Array[MeshInstance3D] = []
var _dot_node: Node3D


func _ready() -> void:
	_dot_node = get_node("TrajectoryDots")
	_build_trajectory_dots()
	_set_dots_visible(false)

	# Track when player enters/exits gravity areas
	for planet in get_tree().get_nodes_in_group("planets"):
		var area := planet.get_node("Area3D")
		area.body_entered.connect(_on_area_entered)
		area.body_exited.connect(_on_area_exited)


func _on_area_entered(body: Node3D) -> void:
	if body == self:
		_area_count += 1
		if state == State.FREE:
			state = State.LAUNCHED


func _on_area_exited(body: Node3D) -> void:
	if body == self:
		_area_count -= 1
		if _area_count <= 0:
			state = State.FREE
			_set_dots_visible(false)


func _physics_process(delta: float) -> void:
	match state:
		State.GROUNDED: _state_grounded(delta)
		State.LAUNCHED: _state_launched(delta)
		State.FREE:     _state_free(delta)


func _state_grounded(delta: float) -> void:
	# Walk
	var input := Input.get_axis("move_left", "move_right")
	if input != 0.0:
		var move_dir := global_transform.basis.x * input
		apply_central_force(move_dir * move_speed)

	# Charge jump
	if Input.is_action_pressed("thrust"):
		_charge = min(_charge + delta, max_charge)
		_update_trajectory()
		_set_dots_visible(true)

	# Launch
	if Input.is_action_just_released("thrust") and _charge > 0.0:
		var up := -_gravity_direction
		var launch_vel := up * jump_force * (_charge / max_charge)
		linear_velocity += launch_vel
		_charge = 0.0
		_set_dots_visible(false)
		state = State.LAUNCHED


func _state_launched(_delta: float) -> void:
	# No player control — Area3D gravity steers
	# Transitions to FREE via _on_area_exited signal
	pass


func _state_free(delta: float) -> void:
	# Rotate with A/D
	var rotate_input := Input.get_axis("move_left", "move_right")
	if rotate_input != 0.0:
		rotate_z(-rotate_input * rotate_speed * delta)

	# Thrust forward (player's up axis)
	if Input.is_action_pressed("thrust"):
		var forward := global_transform.basis.y
		apply_central_force(forward * thrust_force)


func _integrate_forces(state_: PhysicsDirectBodyState3D) -> void:
	_gravity_direction = state_.total_gravity.normalized()

	# Floor detection
	_on_floor = false
	for i in state_.get_contact_count():
		var normal := state_.get_contact_local_normal(i)
		if normal.dot(-_gravity_direction) > 0.5:
			_on_floor = true
			if state == State.LAUNCHED:
				state = State.GROUNDED
			break

	# Orient to surface when grounded or launched
	if state != State.FREE and _gravity_direction != Vector3.ZERO:
		var up := -_gravity_direction
		var reference := Vector3.FORWARD
		if abs(up.dot(reference)) > 0.99:
			reference = Vector3.RIGHT
		var right := reference.cross(up).normalized()
		var forward := up.cross(right).normalized()
		var target_basis := Basis(right, up, -forward)
		state_.transform.basis = state_.transform.basis.slerp(target_basis, 0.2)

	# Lock to XY plane
	var pos := state_.transform.origin
	pos.z = 0.0
	state_.transform.origin = pos

	var vel := state_.linear_velocity
	vel.z = 0.0
	state_.linear_velocity = vel


# --- Trajectory Simulation ---

func _simulate_trajectory() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var pos := global_position
	var up := -_gravity_direction
	var vel := linear_velocity + up * jump_force * (_charge / max_charge)
	vel.z = 0.0

	var planets := get_tree().get_nodes_in_group("planets")

	for i in trajectory_steps:
		points.append(pos)

		for planet in planets:
			var area := planet.get_node("Area3D")
			var area_shape := area.get_node("CollisionShape3D")
			var area_radius: float = (area_shape.shape as SphereShape3D).radius

			# Check landing on planet surface
			var planet_shape := planet.get_node("CollisionShape3D")
			var planet_radius: float = (planet_shape.shape as SphereShape3D).radius
			var to_planet: Vector3 = planet.global_position - pos
			var dist: float = to_planet.length()

			# Stop trajectory if we hit the planet surface
			if dist < planet_radius * 1.05:
				return points

			# Apply gravity if within area
			if dist < area_radius:
				var grav: float = area.gravity
				vel += to_planet.normalized() * grav * trajectory_step_size

		vel.z = 0.0
		pos += vel * trajectory_step_size

	return points


func _update_trajectory() -> void:
	var points := _simulate_trajectory()
	for i in _trajectory_dots.size():
		if i < points.size():
			_trajectory_dots[i].global_position = points[i]
			_trajectory_dots[i].visible = true
			# Fade dots toward end of arc
			var mat := _trajectory_dots[i].get_surface_override_material(0)
			if mat:
				var alpha := 1.0 - (float(i) / points.size())
				(mat as StandardMaterial3D).albedo_color.a = alpha
		else:
			# Hide dots beyond current trajectory length
			_trajectory_dots[i].visible = false


func _build_trajectory_dots() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12

	for i in trajectory_steps:
		var dot := MeshInstance3D.new()
		dot.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot.set_surface_override_material(0, mat)

		_dot_node.add_child(dot)
		_trajectory_dots.append(dot)


func _set_dots_visible(visible_: bool) -> void:
	_dot_node.visible = visible_
