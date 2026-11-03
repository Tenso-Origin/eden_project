@tool
extends Node3D
class_name ModularHydrology16x16Geometry

## Geometria da Cena de Teste de Hidrologia Modular 16x16m
## Lago Elevado ao Norte (-Z, Y=3.5m) -> Cachoeira Vertical (tau=1.0) -> Rio em Rampa ao Sul (+Z) até Y=0.5m
## Grade 1x1x1m, Snapping Vertical 0.25m, Shaders pixel_water / pixel_surface

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER_SURFACE = preload("res://pixel_water_surface.gdshader")
const SHADER_WATERFALL = preload("res://pixel_waterfall.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const ModularTerrainBuilder1mClass = preload("res://modular_terrain_builder_1m.gd")

var terrain_instance: MeshInstance3D
var water_instance: MeshInstance3D

func _ready() -> void:
	generate_scene()

func generate_scene() -> void:
	for child in get_children():
		child.queue_free()

	var builder = ModularTerrainBuilder1mClass.new()
	var terrain_mesh = builder.build_terrain_mesh(Vector2i(0, 0), 16)
	var water_mesh = builder.build_water_mesh(Vector2i(0, 0), 16)

	if terrain_mesh:
		terrain_instance = MeshInstance3D.new()
		terrain_instance.name = "TerrainMesh16x16"
		terrain_instance.mesh = terrain_mesh
		
		var mat_surface = ShaderMaterial.new()
		mat_surface.shader = SHADER_SURFACE
		mat_surface.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
		mat_surface.set_shader_parameter("shadow_tint", Color(0.14, 0.11, 0.26, 1.0))
		mat_surface.set_shader_parameter("light_bands", 3)
		mat_surface.set_shader_parameter("dither_spread", 0.0)

		var tex_serra = load("res://tex_serrapilheira.png")
		if tex_serra:
			mat_surface.set_shader_parameter("use_top_texture", true)
			mat_surface.set_shader_parameter("top_albedo_texture", tex_serra)
			mat_surface.set_shader_parameter("top_texture_scale", 0.35)
		else:
			mat_surface.set_shader_parameter("use_top_texture", false)

		terrain_instance.material_override = mat_surface

		# Centraliza na cena: X em [-8m, +8m], Z em [-8m (Norte), +8m (Sul)]
		terrain_instance.position = Vector3(-8.0, 0.0, -8.0)
		add_child(terrain_instance)

	if water_mesh:
		water_instance = MeshInstance3D.new()
		water_instance.name = "WaterMesh16x16"
		water_instance.mesh = water_mesh

		var mat_water_surf = ShaderMaterial.new()
		mat_water_surf.shader = SHADER_WATER
		mat_water_surf.set_shader_parameter("enable_3way_blend", false)
		mat_water_surf.set_shader_parameter("use_voronoi", false)
		mat_water_surf.set_shader_parameter("shallow_color", Color(0.18, 0.72, 0.82, 0.40))
		mat_water_surf.set_shader_parameter("deep_color", Color(0.08, 0.32, 0.52, 0.70))
		mat_water_surf.set_shader_parameter("depth_fade_distance", 1.20)
		mat_water_surf.set_shader_parameter("pixel_grid_density", 64.0)
		mat_water_surf.set_shader_parameter("wave_speed", 2.0)
		mat_water_surf.set_shader_parameter("wave_height", 0.015) # Leve redução para evitar que o topo da onda descole da rampa
		mat_water_surf.set_shader_parameter("shoreline_foam_dist", 0.30)
		mat_water_surf.set_shader_parameter("shoreline_ripple_rings", 3)
		mat_water_surf.set_shader_parameter("contact_foam_threshold", 0.06)
		mat_water_surf.set_shader_parameter("reflection_strength", 0.35)
		mat_water_surf.set_shader_parameter("reflection_distortion_px", 1.8)
		mat_water_surf.set_shader_parameter("wind_direction", Vector2(0.7071, 0.7071))
		mat_water_surf.set_shader_parameter("wind_speed", 2.0)
		mat_water_surf.set_shader_parameter("wind_strength", 1.0)
		mat_water_surf.set_shader_parameter("refraction_strength", 4.0)
		mat_water_surf.set_shader_parameter("dash_density", 0.55)
		mat_water_surf.set_shader_parameter("dash_cycle_speed", 0.55)
		mat_water_surf.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))

		var mat_fall = ShaderMaterial.new()
		mat_fall.shader = SHADER_WATERFALL
		mat_fall.set_shader_parameter("pixel_grid_density", 64.0)
		mat_fall.set_shader_parameter("wave_speed", 1.8)
		mat_fall.set_shader_parameter("shallow_color", Color(0.18, 0.82, 0.78, 0.70))
		mat_fall.set_shader_parameter("deep_color", Color(0.05, 0.38, 0.48, 0.90))
		mat_fall.set_shader_parameter("foam_color", Color(0.96, 0.98, 1.0))

		water_instance.set_surface_override_material(0, mat_water_surf)
		if water_mesh.get_surface_count() > 1:
			water_instance.set_surface_override_material(1, mat_fall)

		# Alinhamento exato com a malha do terreno
		water_instance.position = Vector3(-8.0, 0.0, -8.0)
		add_child(water_instance)

	print("Cena de teste de Hidrologia 16x16m gerada com sucesso (com correção de borda de rampa)!")
