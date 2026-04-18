extends Node3D

func _ready() -> void:
	# Verify planets are in group — add programmatically as fallback
	for child in get_children():
		if child is AnimatableBody3D:
			if not child.is_in_group("planets"):
				child.add_to_group("planets")
