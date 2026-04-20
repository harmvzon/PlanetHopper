extends Node3D

@onready var mesh = $MeshInstance3D
var target_camera: Camera3D

func _ready() -> void:
	target_camera = get_viewport().get_camera_3d()
	print("Camera: ", target_camera)
	print("Mesh position: ", mesh.global_position)
	
func _process(_delta: float) -> void:
	if target_camera:
		global_position = target_camera.global_position
		global_rotation = target_camera.global_rotation
