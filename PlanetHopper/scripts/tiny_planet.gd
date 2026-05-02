@tool
extends Node3D

@export_group("Sphere")
@export var radius := 8.0:
	set(new_radius):
		radius = maxf(1.0, new_radius)
		if is_node_ready():
			update_shader_params()  # Update shader first
			update_terrain()
			update_water()

@export var detail := 64:
	set(new_detail):
		detail = maxi(1, new_detail)
		if is_node_ready():
			update_terrain()
			update_water()

@export_group("Terrain")
@export var noise := FastNoiseLite.new():
	set(new_noise):
		noise = new_noise
		if noise: 
			noise.changed.connect(update_terrain)
@export var height := 1.0:
	set(new_height):
		height = maxf(0.0, new_height)
		update_terrain()
		update_water()
@export var terrain_material: ShaderMaterial:
	set(new_terrain_material):
		terrain_material = new_terrain_material
		if is_node_ready():
			$Terrain.set_surface_override_material(0, terrain_material)
			update_shader_params()


	
@export_group("Water")
@export_range(0.0, 1.0, 0.05) var water_level := 0.0:
	set(new_water_level):
		water_level = new_water_level
		update_water()
@export var water_detail := 32:
	set(new_water_level):
		water_detail = maxi(1, new_water_level)
		update_water()
@export var water_material: ShaderMaterial:
	set(new_water_material):
		water_material = new_water_material
		if is_node_ready():
			$Water.set_surface_override_material(0, water_material)
			update_shader_params()

var terrain: ArrayMesh
var water: ArrayMesh

func update_shader_params() -> void:
	if not terrain_material:
		return
	terrain_material.set_shader_parameter("radius", radius)
	terrain_material.set_shader_parameter("height", height)
	
	water_material.set_shader_parameter("radius", radius)
	var level: float = radius + (height/2)
	water_material.set_shader_parameter("level", level)
	
	

func _ready() -> void:
	terrain = ArrayMesh.new()
	water = ArrayMesh.new()
	$Terrain.mesh = terrain
	$Water.mesh = water
	update_terrain()
	update_water()

func create_sphere(sphere_radius: float, sphere_detail: int) -> Array:
	var sphere := CubeSphereMesh.new()
	sphere.radius = sphere_radius
	sphere.height = sphere_radius * 2.0
	sphere.edge_count = sphere_detail
	# Extract the mesh arrays from surface 0
	return sphere.surface_get_arrays(0)

func get_noise(vertex: Vector3) -> float:
	return (noise.get_noise_3dv(vertex.normalized() * 2.0) + 1.0) / 2.0 * height
	
	

func update_terrain() -> void:
	if !terrain or !noise:
		return
	
	var mesh_arrays := create_sphere(radius, detail)
	var vertices: PackedVector3Array = mesh_arrays[ArrayMesh.ARRAY_VERTEX]
	
	# Apply noise distortion
	for i: int in vertices.size():
		var vertex := vertices[i]
		vertex += vertex.normalized() * get_noise(vertex)
		vertices[i] = vertex
	
	# Update the mesh arrays with modified vertices
	mesh_arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	
	# Create the final mesh
	terrain.clear_surfaces()
	terrain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	terrain.surface_set_material(0, terrain_material)
	$Terrain.mesh = terrain

func update_water() -> void:
	if !water:
		return
	
	if water_level == 0.0:
		$Water.visible = false
		return
		
	$Water.visible = true
	
	var water_radius := lerpf(radius, radius + height, water_level)
	
	var mesh_arrays := create_sphere(water_radius, water_detail)
	
	
	water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	
	water.clear_surfaces()
	water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	water.surface_set_material(0, water_material)
	$Water.mesh = water
