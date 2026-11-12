extends SceneTree

func _init():
	print("--- TESTE DA ÁGUA NA FONTE (DIA, CREPÚSCULO E NOITE) ---")
	var scene_res = load("res://cena2_4.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena2_4.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames iniciais para compilação e estabilização de shaders
	for i in range(50):
		await process_frame

	var svp = root_scene.get_node("SubViewport") as SubViewport
	var day_night = root_scene.find_child("DayNightCycle", true, false)
	var cube = root_scene.find_child("FloatingGlowingCube", true, false)

	if not svp or not day_night:
		push_error("Nós essenciais não encontrados na cena.")
		quit(1)
		return

	day_night.auto_advance = false

	# 1. TESTE DIURNO (12:00 - Sol Pleno, lâmina d'água cristalina turquesa)
	day_night.day_of_year = 80
	day_night.current_hour = 12.0
	for i in range(40):
		await process_frame

	var img_dia = svp.get_texture().get_image()
	if img_dia:
		img_dia.save_png("res://screenshot_agua_dia.png")
		var img_1080 = Image.new()
		img_1080.copy_from(img_dia)
		img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img_1080.save_png("res://screenshot_agua_dia_1080p.png")
		print("[12:00 Meio-dia] Água capturada sob sol pleno!")

	# 2. TESTE CREPÚSCULO (18:00 - Pôr do sol dourado refletindo na água)
	day_night.current_hour = 18.0
	for i in range(40):
		await process_frame

	var img_crep = svp.get_texture().get_image()
	if img_crep:
		img_crep.save_png("res://screenshot_agua_crepusculo.png")
		var img_1080 = Image.new()
		img_1080.copy_from(img_crep)
		img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img_1080.save_png("res://screenshot_agua_crepusculo_1080p.png")
		print("[18:00 Crepúsculo] Água capturada sob iluminação poente!")

	# 3. TESTE NOTURNO (22:00 - Glow do cubo refletindo na água e projetando luz na bacia)
	day_night.current_hour = 22.0
	for i in range(40):
		await process_frame

	var img_noite = svp.get_texture().get_image()
	if img_noite:
		img_noite.save_png("res://screenshot_agua_noite.png")
		var img_1080 = Image.new()
		img_1080.copy_from(img_noite)
		img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
		img_1080.save_png("res://screenshot_agua_noite_1080p.png")
		print("[22:00 Noite] Água capturada sob glow do cubo e escuridão noturna!")

	print("--- TESTE DA ÁGUA NA FONTE CONCLUÍDO COM SUCESSO ---")
	quit()

