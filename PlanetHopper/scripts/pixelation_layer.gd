# pixelation_layer.gd
extends CanvasLayer

@export var pixel_size: float = 4.0

func _ready() -> void:
	$PixelationRect.material.set_shader_parameter("pixel_size", pixel_size)

func set_pixel_size(size: float) -> void:
	pixel_size = size
	$PixelationRect.material.set_shader_parameter("pixel_size", pixel_size)
