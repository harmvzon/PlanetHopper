extends CharacterBody3D

@export var move_speed: float = 5.0
@export var gravity_strength: float = 25.0

var planet: AnimatableBody3D
var _last_planet_pos: Vector3


func _ready() -> void:
	planet = get_parent().get_node("PlanetA")
	_last_planet_pos = planet.global_position


func _physics_process(delta: float) -> void:
	var down: Vector3 = (planet.global_position - global_position).normalized()
	var up: Vector3 = -down

	up_direction = up

	# Gravity only — nothing else
	velocity += down * gravity_strength * delta
	velocity.z = 0.0

	move_and_slide()
