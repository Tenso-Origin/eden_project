extends SceneTree

func _init():
	print("--- TESTE DO CUBO MÍSTICO FLUTUANTE (DIA VS NOITE) ---")
	var scene_res = load("res://cena2_4.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena2_4.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames iniciais para compilação e estabilização
	for i in range(40):
		await process_frame

	var svp = root_scene.get_node("SubViewport") as SubViewport
	var day_night = root_scene.find_child("DayNightCycle", true, false)
	var cube = root_scene.find_child("FloatingGlowingCube", true, false)

	if not svp or not day_night or not cube:
		push_error("Nós essenciais não encontrados na cena.")
		quit(1)
		return

	day_night.auto_advance = false

	# 1. TESTE DIURNO (12:00 - Meio-dia com sol pleno)
	day_night.day_of_year = 80
	day_night.current_hour = 12.0
	for i in range(30):
		await process_frame

	var img_dia = svp.get_texture().get_image()
	if img_dia:
		img_dia.save_png("res://screenshot_cubo_dia.png")
		var img_1080 = Image.new()
		img_1080.copy_from(img_dia)
		img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img_1080.save_png("res://screenshot_cubo_dia_1080p.png")
		print("[12:00 Meio-dia] Altura do cubo: %.2fm | Luz: %.2f | Emissão: %.2f" % [
			cube.position.y,
			cube.omni_light.light_energy if cube.omni_light else 0.0,
			cube.cube_material.emission_energy_multiplier if cube.cube_material else 0.0
		])

	# 2. TESTE NOTURNO (22:00 - Noite com glow ativo)
	day_night.current_hour = 22.0
	for i in range(30):
		await process_frame

	var img_noite = svp.get_texture().get_image()
	if img_noite:
		img_noite.save_png("res://screenshot_cubo_noite.png")
		var img_1080 = Image.new()
		img_1080.copy_from(img_noite)
		img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img_1080.save_png("res://screenshot_cubo_noite_1080p.png")
		print("[22:00 Noite] Altura do cubo: %.2fm | Luz: %.2f | Emissão: %.2f" % [
			cube.position.y,
			cube.omni_light.light_energy if cube.omni_light else 0.0,
			cube.cube_material.emission_energy_multiplier if cube.cube_material else 0.0
		])

	print("--- TESTE DO CUBO CONCLUIDO COM SUCESSO ---")
	quit()

