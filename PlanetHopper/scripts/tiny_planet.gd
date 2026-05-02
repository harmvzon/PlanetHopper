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

@export var height := 1.0:
	set(new_height):
		height = maxf(0.0, new_height)
		update_terrain()
		update_water()

@export var mid_level := 0.5:
	set(new_mid_level):
		mid_level = maxf(0.0, new_mid_level)
		update_terrain()
		update_water()
		
@export_range(0.0, 1.0, 0.05) var noise_mix := 0.5:
	set(new_noise_mix):
		noise_mix = new_noise_mix
		update_water()
		update_terrain()
		
@export var terrain_material: ShaderMaterial:
	set(new_terrain_material):
		terrain_material = new_terrain_material
		if is_node_ready():
			$Terrain.set_surface_override_material(0, terrain_material)
			update_shader_params()

@export var noise_large:= FastNoiseLite.new():
	set(new_noise):
		noise_large = new_noise
		if noise_large:
			noise_large.changed.connect(update_terrain)

@export var noise_small:= FastNoiseLite.new():
	set(new_noise):
		noise_small = new_noise
		if noise_small:
			noise_small.changed.connect(update_terrain)

@export var playable_band_smoothness := 0.8:
	set(new_smoothness):
		playable_band_smoothness = clampf(new_smoothness, 0.0, 1.0)
		update_terrain()


	
@export_group("Water")
@export_range(0.0, 1.0, 0.05) var water_level := 0.0:
	set(new_water_level):
		water_level = new_water_level
		update_water()
@export var water_detail := 32:
	set(new_water_detail):
		water_detail = maxi(1, new_water_detail)
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
	var normalized := vertex.normalized()
	
	# Large deformation (macro shape)
	var large := (noise_large.get_noise_3dv(normalized * 2.0) + 1.0) / 2.0
	
	# Small detail (surface roughness)
	var small := (noise_small.get_noise_3dv(normalized * 2.0) + 1.0) / 2.0
	
	# Blend: 70% macro, 30% detail (tune to taste)
	var combined := lerpf(large, small, noise_mix)
	
	combined = combined * 2.0 - (mid_level*2)
	
	# Playable band mask: assume Y-axis is player's walking plane
	# Suppress noise near Y ≈ 0 (equator strip)
	#var band_mask := 1.0 - pow(1.0 - abs(normalized.x), playable_band_smoothness)
	
	var disp := combined * height
	
	return disp

	
	

func update_terrain() -> void:
	if !terrain or !noise_large or !noise_small:
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
	
	var water_radius := lerpf(radius, radius + (height/2), water_level)
	
	var mesh_arrays := create_sphere(water_radius, water_detail)
	
	
	water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	
	water.clear_surfaces()
	water.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	water.surface_set_material(0, water_material)
	$Water.mesh = water
