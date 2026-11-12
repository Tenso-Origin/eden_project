extends SceneTree

func _init():
	print("--- TESTE DO CICLO DIA E NOITE EM CENA2_4 (RUINAS) ---")
	var scene_res = load("res://cena2_4.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena2_4.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	for i in range(40):
		await process_frame

	var svp = root_scene.get_node("SubViewport") as SubViewport
	var day_night = root_scene.find_child("DayNightCycle", true, false)

	if not svp or not day_night:
		push_error("SubViewport ou DayNightCycle não encontrado.")
		quit(1)
		return

	day_night.auto_advance = false

	var capture_point = func(hour: float, day: int, filename: String, label: String):
		day_night.day_of_year = day
		day_night.current_hour = hour
		for i in range(20):
			await process_frame

		var img = svp.get_texture().get_image()
		if img:
			var save_path = "res://" + filename
			img.save_png(save_path)
			var img_1080 = Image.new()
			img_1080.copy_from(img)
			img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
			img_1080.save_png("res://" + filename.replace(".png", "_1080p.png"))
			print("[%s] Captura salva: %s" % [label, filename])

	# 1. Alvorada (06:30)
	await capture_point.call(6.5, 80, "screenshot_ruinas_ciclo_1_alvorada.png", "06:30 Alvorada")
	# 2. Meio-dia (12:00)
	await capture_point.call(12.0, 80, "screenshot_ruinas_ciclo_2_meiodia.png", "12:00 Meio-dia")
	# 3. Pôr do sol (17:45)
	await capture_point.call(17.75, 80, "screenshot_ruinas_ciclo_3_crepusculo.png", "17:45 Crepúsculo")
	# 4. Noite (22:00)
	await capture_point.call(22.0, 80, "screenshot_ruinas_ciclo_4_noite.png", "22:00 Noite")

	print("--- TESTE DE CICLO CONCLUIDO COM SUCESSO ---")
	quit()

