extends Node3D

@export var step_target: Node3D
@export var step_distance: float = 3.0
@export var leg_index: int = 0
@export var creature_root: Node3D
@onready var body_node = $"../../MAIN"


var is_stepping := false
const LEG_COUNT := 6

func _process(_delta: float) -> void:
	if is_stepping:
		return

	if step_target == null or creature_root == null or body_node == null:
		return

	if global_position.distance_to(step_target.global_position) <= step_distance:
		return

	if _can_step_now():
		step()

func _can_step_now() -> bool:
	# Wait for the previous leg in the ripple sequence
	var prev_idx := (leg_index - 1 + LEG_COUNT) % LEG_COUNT
	var prev_leg := creature_root.get_child(prev_idx)

	return not prev_leg.is_stepping

func step() -> void:
	var target_pos := step_target.global_position
	var half_way := (global_position + target_pos) * 0.5

	is_stepping = true

	var t := get_tree().create_tween()
	t.tween_property(
		self,
		"global_position",
		half_way + body_node.global_transform.basis.y,
		0.1
	)
	t.tween_property(self, "global_position", target_pos, 0.1)
	t.tween_callback(func(): is_stepping = false)
