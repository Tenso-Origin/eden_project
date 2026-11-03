@tool
extends Node3D

## Loader do Kit de Bioma de Floresta Tropical (David Holland Architecture)
@export_file("*.glb") var glb_path: String = "res://kit_bioma_floresta.glb"

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const TEX_SERRAPILHEIRA = preload("res://tex_serrapilheira.png")

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
			var m_name: String = child.name
			
			if m_name.begins_with("Water_"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_WATER
				mat.set_shader_parameter("enable_3way_blend", false)
				mat.set_shader_parameter("use_voronoi", false)
				mat.set_shader_parameter("shallow_color", Color(0.18, 0.72, 0.82, 0.40))
				mat.set_shader_parameter("deep_color", Color(0.08, 0.32, 0.52, 0.70))
				mat.set_shader_parameter("depth_fade_distance", 1.20)
				mat.set_shader_parameter("pixel_grid_density", 64.0)
				mat.set_shader_parameter("wave_speed", 2.0)
				mat.set_shader_parameter("wave_height", 0.02)
				mat.set_shader_parameter("shoreline_foam_dist", 0.30)
				mat.set_shader_parameter("shoreline_ripple_rings", 3)
				mat.set_shader_parameter("contact_foam_threshold", 0.06)
				mat.set_shader_parameter("reflection_strength", 0.35)
				mat.set_shader_parameter("reflection_distortion_px", 1.8)
				mat.set_shader_parameter("wind_direction", Vector2(0.7071, 0.7071))
				mat.set_shader_parameter("wind_speed", 2.0)
				mat.set_shader_parameter("wind_strength", 1.0)
				mat.set_shader_parameter("refraction_strength", 4.0)
				mat.set_shader_parameter("dash_density", 0.55)
				mat.set_shader_parameter("dash_cycle_speed", 0.55)
				mat.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))
				child.material_override = mat
				
			else:
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				
				if m_name.begins_with("Soil_Organic_"):
					# Aplica o tapete denso de folhas sobrepostas da serrapilheira
					mat.set_shader_parameter("use_top_texture", true)
					mat.set_shader_parameter("top_albedo_texture", TEX_SERRAPILHEIRA)
					mat.set_shader_parameter("top_texture_scale", 0.35)
				else:
					# Latossolo, Areia Branca, Matacão e Leitos usam suas cores puras
					mat.set_shader_parameter("use_top_texture", false)
					
				child.material_override = mat

		if child.get_child_count() > 0:
			setup_materials(child)
