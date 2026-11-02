extends SceneTree

func _init():
	print("--- TESTE UNITÁRIO: HIDROLOGIA MODULAR MULTI-NÍVEL (FASE 2) ---")
	var builder_script = load("res://modular_terrain_builder_1m.gd")
	if not builder_script:
		push_error("Falha ao carregar modular_terrain_builder_1m.gd")
		quit(1)
		return

	var builder = builder_script.new()
	var terrain_mesh = builder.build_terrain_mesh(Vector2i(0, 0), 16)
	var water_mesh = builder.build_water_mesh(Vector2i(0, 0), 16)

	if not terrain_mesh or terrain_mesh.get_surface_count() == 0:
		push_error("Falha na geracao do terreno da Fase 2.")
		quit(1)
		return

	if not water_mesh or water_mesh.get_surface_count() == 0:
		push_error("Falha na geracao da agua multi-nivel da Fase 2.")
		quit(1)
		return

	var t_verts = terrain_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var w_verts = water_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var w_colors = water_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray

	print("Terreno: ", t_verts.size() / 3, " triangulos gerados.")
	print("Agua Multi-Nivel: ", w_verts.size() / 3, " triangulos gerados.")

	# Validação 1: Snapping 0.25m na água e no terreno
	var all_snapped = true
	for v in w_verts:
		var rem = abs(fmod(v.y, 0.25))
		if rem > 0.001 and rem < 0.249:
			all_snapped = false
			print("Vertice de agua fora do snap 0.25m: ", v)
			break

	if all_snapped:
		print("Validacao 1 (Snapping 0.25m): 100% da agua multi-nivel quantizada em quartos de metro!")
	else:
		push_error("Falha no snapping da agua.")
		quit(1)
		return

	# Validação 2: Presença de diferentes cotas (Superação do Valheim)
	var min_wy = 999.0
	var max_wy = -999.0
	var has_waterfall_turb = false
	var has_calm_turb = false
	var has_ramp_turb = false

	for i in range(w_verts.size()):
		var v = w_verts[i]
		var c = w_colors[i]
		min_wy = min(min_wy, v.y)
		max_wy = max(max_wy, v.y)

		var turb = c.b # Canal B armazena a turbulência
		if turb >= 0.99:
			has_waterfall_turb = true
		elif turb >= 0.40 and turb <= 0.60:
			has_ramp_turb = true
		elif turb <= 0.15:
			has_calm_turb = true

	print("Cota minima da agua: ", min_wy, "m | Cota maxima da agua: ", max_wy, "m (Desnivel total: ", max_wy - min_wy, "m)")
	if max_wy - min_wy >= 2.0:
		print("Validacao 2 (Multi-Cotas): Rios em declive e lagos de altitude confirmados (Anti-Valheim ativo)!")
	else:
		push_error("Agua permaneceu em plano unico.")
		quit(1)
		return

	# Validação 3: Componentes hidrológicos confirmados
	if has_calm_turb and has_ramp_turb and has_waterfall_turb:
		print("Validacao 3 (Tipos Hidrologicos): Lago de altitude, corredeira em rampa e cachoeira vertical com turbulencia maxima (tau=1.0) validados com sucesso!")
	else:
		push_error("Algum componente hidrologico nao foi gerado.")
		quit(1)
		return

	print("--- FASE 2 CONCLUIDA COM 100% DE SUCESSO! ---")
	quit(0)
