extends Node3D

@export var body_node: Node3D
@export var step_distance: float = 0.4
@export var step_cooldown: float = 0.05
@export var hide_helper_meshes: bool = true

const LEG_NAMES: Array[String] = [
	"GOAL_L1",
	"GOAL_L2",
	"GOAL_L3",
	"GOAL_R1",
	"GOAL_R2",
	"GOAL_R3",
]

const TRIPOD_GROUPS: Array = [
	[0, 4, 2],
	[3, 1, 5],
]

var legs: Array[Node3D] = []
var _active_group_index: int = 0
var _cooldown_timer: float = 0.0

func _ready() -> void:
	if body_node == null:
		body_node = self

	_auto_wire_legs()

func _physics_process(delta: float) -> void:
	if body_node == null:
		return

	if legs.size() < 6:
		return

	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	var active_group: Array = TRIPOD_GROUPS[_active_group_index]

	if _group_is_stepping(active_group):
		return

	if _cooldown_timer > 0.0:
		return

	if _group_needs_step(active_group):
		_start_group_steps(active_group)
		_cooldown_timer = step_cooldown
		return

	var other_group_index: int = (_active_group_index + 1) % TRIPOD_GROUPS.size()
	var other_group: Array = TRIPOD_GROUPS[other_group_index]

	if not _group_is_stepping(other_group) and _group_needs_step(
		other_group
	):
		_active_group_index = other_group_index

func _auto_wire_legs() -> void:
	legs.clear()

	var robot_root: Node3D = get_parent_node_3d()
	if robot_root == null:
		push_error("HexapodGaitController: no robot root found.")
		return

	var goals_root: Node3D = robot_root.get_node_or_null("GOALS") as Node3D
	var steps_root: Node3D = robot_root.get_node_or_null("STEPS") as Node3D

	if goals_root == null:
		push_error("HexapodGaitController: GOALS node not found.")
		return

	if steps_root == null:
		push_error("HexapodGaitController: STEPS node not found.")
		return

	if hide_helper_meshes:
		_hide_mesh_instances(goals_root)
		_hide_mesh_instances(steps_root)

	for goal_name: String in LEG_NAMES:
		var goal_node: Node3D = goals_root.find_child(goal_name, true, false) as Node3D
		var step_name: String = goal_name.replace("GOAL_", "STEP_")
		var step_target: Node3D = steps_root.find_child(step_name, true, false) as Node3D

		if goal_node == null:
			push_warning("Missing goal node: %s" % goal_name)
			continue

		if step_target == null:
			push_warning("Missing step target: %s" % step_name)
			continue

		goal_node.set("step_target", step_target)
		legs.append(goal_node)

func _hide_mesh_instances(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false

		_hide_mesh_instances(child)

func _group_needs_step(group: Array) -> bool:
	for idx in group:
		var leg: Node3D = _get_leg(idx)
		if leg == null:
			continue

		if leg.has_method("needs_step") and leg.needs_step(step_distance):
			return true

	return false

func _group_is_stepping(group: Array) -> bool:
	for idx in group:
		var leg: Node3D = _get_leg(idx)
		if leg == null:
			continue

		var stepping: Variant = leg.get("is_stepping")
		if bool(stepping):
			return true

	return false

func _start_group_steps(group: Array) -> void:
	var up_dir: Vector3 = body_node.global_transform.basis.y

	for idx in group:
		var leg: Node3D = _get_leg(idx)
		if leg == null:
			continue

		if not leg.has_method("needs_step"):
			continue

		if not leg.has_method("step_to"):
			continue

		if leg.needs_step(step_distance):
			var step_target: Node3D = leg.get("step_target") as Node3D
			if step_target == null:
				continue

			leg.step_to(step_target.global_position, up_dir)

func _get_leg(idx: int) -> Node3D:
	if idx < 0 or idx >= legs.size():
		return null

	return legs[idx]
