extends Camera3D

@export var follow_speed: float = 5.0
@export var zoom_distance: float = 10.0

var target: Node3D


func _ready() -> void:
	target = get_parent().get_node("Player")


func _process(delta: float) -> void:
	var goal := target.global_position + Vector3(0.0, 0.0, zoom_distance)
	global_position = global_position.lerp(goal, follow_speed * delta)
