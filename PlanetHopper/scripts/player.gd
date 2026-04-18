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
var _trajectory_dots: Array[MeshInstance3D] = []
var _dot_node: Node3D

# State
enum State { GROUNDED, LAUNCHED, FREE }
var state: State = State.GROUNDED
var is_grounded: bool:
	get: return state == State.GROUNDED
var is_charging: bool:
	get: return _charge > 0.0

# Internal
var _gravity_direction: Vector3 = Vector3.ZERO
var _on_floor: bool = false
var _charge: float = 0.0
var _area_count: int = 0
var surface_up: Vector3:
	get: return _gravity_direction

var current_planet: Node3D = null

# ── Drill ──────────────────────────────────────────────────────────────────
const DRILL_COOLDOWN: float = 0.4  # seconds between hits; tune for game feel
var _drill_timer: float = 0.0


func _ready() -> void:
	_dot_node = get_node("TrajectoryDots")
	_build_trajectory_dots()
	_set_dots_visible(false)

	for planet in get_tree().get_nodes_in_group("planets"):
		var area := planet.get_node("Area3D")
		area.body_entered.connect(_on_area_entered.bind(planet))
		area.body_exited.connect(_on_area_exited.bind(planet))


func _on_area_entered(body: Node3D, planet: Node3D) -> void:
	if body == self:
		_area_count += 1
		current_planet = planet
		if state == State.FREE:
			state = State.LAUNCHED


func _on_area_exited(body: Node3D, _planet: Node3D) -> void:
	if body == self:
		_area_count -= 1
		if _area_count <= 0:
			current_planet = null
			state = State.FREE
			_set_dots_visible(false)


func _physics_process(delta: float) -> void:
	match state:
		State.GROUNDED: _state_grounded(delta)
		State.LAUNCHED: _state_launched(delta)
		State.FREE:     _state_free(delta)


func _state_grounded(delta: float) -> void:
	if Input.is_action_pressed("thrust"):
		_charge = min(_charge + delta, max_charge)
		_update_trajectory()
		_set_dots_visible(true)

	if Input.is_action_just_released("thrust") and _charge > 0.0:
		var up := -_gravity_direction
		var launch_vel := up * jump_force * (_charge / max_charge)
		linear_velocity += launch_vel
		_charge = 0.0
		_set_dots_visible(false)
		state = State.LAUNCHED

	# Mining runs every grounded frame, independent of thrust
	_process_mining(delta)


func _state_launched(_delta: float) -> void:
	# No player control — Area3D gravity steers
	pass


func _state_free(delta: float) -> void:
	var rotate_input := Input.get_axis("move_left", "move_right")
	if rotate_input != 0.0:
		rotate_z(-rotate_input * rotate_speed * delta)

	if Input.is_action_pressed("thrust"):
		var forward := global_transform.basis.y
		apply_central_force(forward * thrust_force)


func _integrate_forces(state_: PhysicsDirectBodyState3D) -> void:
	_gravity_direction = state_.total_gravity.normalized()

	_on_floor = false
	for i in state_.get_contact_count():
		var normal := state_.get_contact_local_normal(i)
		if normal.dot(-_gravity_direction) > 0.5:
			_on_floor = true
			if state == State.LAUNCHED:
				state = State.GROUNDED
			break

	if state == State.GROUNDED:
		var up := -_gravity_direction
		var gravity_vel := up * state_.linear_velocity.dot(up)
		var planet_lateral := Vector3.ZERO

		if current_planet != null:
			var planet := current_planet as AnimatableBody3D
			var planet_vel: Vector3 = planet.get("surface_velocity")
			planet_vel.z = 0.0
			planet_lateral = planet_vel - up * planet_vel.dot(up)

		var input := Input.get_axis("move_left", "move_right")
		var move_lateral := state_.transform.basis.x * input * move_speed

		state_.linear_velocity = gravity_vel + planet_lateral + move_lateral

	if state != State.FREE and _gravity_direction != Vector3.ZERO:
		var up := -_gravity_direction
		var reference := Vector3.FORWARD
		if abs(up.dot(reference)) > 0.99:
			reference = Vector3.RIGHT
		var right := reference.cross(up).normalized()
		var forward := up.cross(right).normalized()
		var target_basis := Basis(right, up, -forward)
		state_.transform.basis = state_.transform.basis.slerp(target_basis, 0.2)

	var pos := state_.transform.origin
	pos.z = 0.0
	state_.transform.origin = pos

	var vel := state_.linear_velocity
	vel.z = 0.0
	state_.linear_velocity = vel


# ── Mining ─────────────────────────────────────────────────────────────────

# Drill fires only when: grounded + still + holding mine + planet not dead
func _process_mining(delta: float) -> void:
	_drill_timer -= delta

	#print("mine pressed: ", Input.is_action_pressed("mine"))
	#print("still: ", _is_player_still())
	#print("current_planet: ", current_planet)
	#print("drill_timer: ", _drill_timer)
	#print("state: ", state)
	#print("---")

	if not Input.is_action_pressed("mine"):
		return
	if not _is_player_still():
		return
	if current_planet == null or current_planet.resources_mined >= 1.0:
		return
	if _drill_timer > 0.0:
		return

	_drill_timer = DRILL_COOLDOWN
	print("MINE HIT FIRED")
	current_planet.mine_hit()


# Still = no directional input held
func _is_player_still() -> bool:
	return not Input.is_action_pressed("move_left") \
		and not Input.is_action_pressed("move_right")


# ── Trajectory ─────────────────────────────────────────────────────────────

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

			var planet_shape := planet.get_node("CollisionShape3D")
			var planet_radius: float = (planet_shape.shape as SphereShape3D).radius
			var to_planet: Vector3 = planet.global_position - pos
			var dist: float = to_planet.length()

			if dist < planet_radius * 1.05:
				return points

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
			var mat := _trajectory_dots[i].get_surface_override_material(0)
			if mat:
				var alpha := 1.0 - (float(i) / points.size())
				(mat as StandardMaterial3D).albedo_color.a = alpha
		else:
			_trajectory_dots[i].visible = false


func _build_trajectory_dots() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6

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
