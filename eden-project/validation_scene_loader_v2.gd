@tool
extends Node3D

## Loader de Cenários HD Pixel Art 3D (David Holland Architecture)
@export_file("*.glb") var glb_path: String = "res://lago_ruinas.glb"

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_FOLIAGE = preload("res://pixel_foliage.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const SHADER_METAL = preload("res://pixel_metal_mirror.gdshader")

func _ready() -> void:
	for child in get_children():
		child.queue_free()
		
	var scene_res = load(glb_path) as PackedScene
	if not scene_res:
		push_error("Falha ao carregar " + glb_path)
		return
		
	var instance = scene_res.instantiate()
	add_child(instance)
	
	setup_materials(instance)

func setup_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_name: String = child.name
			
			if mesh_name.begins_with("Tree_Canopy") or mesh_name.begins_with("Grass_Tuft"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_FOLIAGE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.12, 0.10, 0.24, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.12)
				mat.set_shader_parameter("wind_strength", 0.35)
				mat.set_shader_parameter("wind_speed", 2.2)
				child.material_override = mat
				
			elif mesh_name.begins_with("Water_Surface"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_WATER
				mat.set_shader_parameter("shallow_color", Color(0.18, 0.68, 0.82, 0.88))
				mat.set_shader_parameter("deep_color", Color(0.10, 0.42, 0.62, 0.95))
				mat.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))
				mat.set_shader_parameter("depth_fade_distance", 0.65)
				mat.set_shader_parameter("pixel_grid_density", 52.0)
				mat.set_shader_parameter("wave_speed", 2.0)
				mat.set_shader_parameter("wave_height", 0.02)
				mat.set_shader_parameter("shoreline_foam_dist", 0.35)
				mat.set_shader_parameter("shoreline_ripple_rings", 3)
				mat.set_shader_parameter("reflection_strength", 0.35)
				child.material_override = mat
				
			elif mesh_name.begins_with("Ore_Crystals"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_METAL
				mat.set_shader_parameter("metal_base_color", Color(0.35, 0.95, 0.78, 1.0))
				mat.set_shader_parameter("metal_dark_band", Color(0.08, 0.45, 0.42, 1.0))
				mat.set_shader_parameter("metal_highlight", Color(0.92, 1.0, 0.96, 1.0))
				mat.set_shader_parameter("mirror_reflectivity", 0.45)
				mat.set_shader_parameter("emission_energy", 0.35)
				child.material_override = mat
				
			elif mesh_name.begins_with("Soil") or mesh_name.begins_with("Tree_Trunk") or mesh_name.begins_with("Ruin") or mesh_name.begins_with("Rock") or mesh_name.begins_with("Riverbed"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.12)
				child.material_override = mat

		if child.get_child_count() > 0:
			setup_materials(child)
