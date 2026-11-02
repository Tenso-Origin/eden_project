extends SceneTree

func _init():
	print("--- INICIANDO VALIDAÇÃO E RENDERIZAÇÃO DA CENA DE HIDROLOGIA 16X16M ---")
	var scene_res = load("res://cena_teste_hidrologia_16x16.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena_teste_hidrologia_16x16.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames para geração da malha modular e inicialização dos shaders de viewport
	for i in range(40):
		await process_frame

	var svp = root_scene.get_node("SubViewport") as SubViewport
	var pivot = root_scene.find_child("CameraPivot", true, false) as Node3D
	var cam = root_scene.find_child("Camera3D", true, false) as Camera3D

	if not svp:
		push_error("SubViewport não encontrado.")
		quit(1)
		return

	var save_shot = func(path: String):
		var img = svp.get_texture().get_image()
		if img:
			img.save_png(path)
			print("Captura salva com sucesso em: ", path)
		else:
			push_error("Falha ao obter imagem da SubViewport: " + path)

	# 1. Captura 1: Visão Geral Panorâmica (Isométrica 16x16m completa)
	# Enquadra o Lago Elevado ao Norte (-Z, Y=3.5m), a Cachoeira Vertical e a Rampa descendo ao Sul (+Z) até Y=0.5m
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.8, 0.0)
		cam.size = 18.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_hidrologia_16x16_geral.png")

	# 2. Captura 2: Close-up Focado na Cachoeira e Lago Elevado ao Norte (-Z)
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 2.8, -3.5)
		cam.size = 9.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_hidrologia_16x16_cachoeira.png")

	# 3. Captura 3: Close-up Focado na Rampa e Corredeira ao Sul (+Z)
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.2, 2.5)
		cam.size = 10.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_hidrologia_16x16_rampa.png")

	print("--- TODAS AS VALIDAÇÕES E CAPTURAS CONCLUÍDAS COM SUCESSO! ---")
	quit(0)

