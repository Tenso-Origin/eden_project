extends SceneTree

func _init():
	print("--- INICIANDO TESTE E VALIDAÇÃO AUTOMATIZADA DO CICLO DE DIA E NOITE ---")
	var scene_res = load("res://cena2_3.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena2_3.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames iniciais para compilação de shaders e posicionamento de nós
	for i in range(40):
		await process_frame

	var svp = root_scene.get_node("SubViewport") as SubViewport
	var day_night = root_scene.find_child("DayNightCycle", true, false)

	if not svp or not day_night:
		push_error("SubViewport ou DayNightCycleController não encontrado.")
		quit(1)
		return

	# Desativa o avanço automático para capturar pontos estáticos congelados
	day_night.auto_advance = false

	var capture_point = func(hour: float, day: int, filename: String, label: String):
		day_night.day_of_year = day
		day_night.current_hour = hour
		# Aguarda alguns frames para atualização de iluminação e render da viewport
		for i in range(15):
			await process_frame

		var img = svp.get_texture().get_image()
		if img:
			var save_path = "res://" + filename
			img.save_png(save_path)
			var sim_info = day_night.get_sim_date()
			print("[%s] Captura salva: %s | %s" % [label, filename, sim_info.full_str])
		else:
			push_error("Falha ao capturar imagem para: " + filename)

	# 1. Madrugada (03:00 - Luar noturno e sombras suaves da Lua)
	await capture_point.call(3.0, 80, "screenshot_ciclo_1_madrugada_03h.png", "03:00 Madrugada")

	# 2. Alvorada (06:15 - Sol nascendo a Leste, luz dourada, sombras compridas a Oeste)
	await capture_point.call(6.25, 80, "screenshot_ciclo_2_alvorada_06h.png", "06:15 Alvorada")

	# 3. Manhã (09:30 - Luz amarela viva subindo)
	await capture_point.call(9.5, 80, "screenshot_ciclo_3_manha_09h.png", "09:30 Manhã")

	# 4. Meio-dia Equinócio (12:00 - Sol no Zênite a pino, sombras curtas)
	await capture_point.call(12.0, 80, "screenshot_ciclo_4_meiodia_12h_equinocio.png", "12:00 Meio-dia Equinócio")

	# 5. Tarde (16:00 - Sol descendo a Oeste)
	await capture_point.call(16.0, 80, "screenshot_ciclo_5_tarde_16h.png", "16:00 Tarde")

	# 6. Pôr do Sol / Golden Hour (18:00 - Tons avermelhados, sombras longas a Leste)
	await capture_point.call(18.0, 80, "screenshot_ciclo_6_crepusculo_18h.png", "18:00 Crepúsculo")

	# 7. Solstício de Junho (12:00 - Dia 172, leve inclinação solar ao Norte)
	await capture_point.call(12.0, 172, "screenshot_ciclo_7_meiodia_solsticio_junho.png", "12:00 Solstício Junho")

	# 8. Solstício de Dezembro (12:00 - Dia 355, leve inclinação solar ao Sul)
	await capture_point.call(12.0, 355, "screenshot_ciclo_8_meiodia_solsticio_dezembro.png", "12:00 Solstício Dezembro")

	print("--- TESTE TEMPORAL DO CICLO DE DIA E NOITE CONCLUÍDO COM SUCESSO! ---")
	quit(0)
