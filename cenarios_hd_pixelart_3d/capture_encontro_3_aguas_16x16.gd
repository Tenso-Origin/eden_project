extends SceneTree

func _init():
	print("--- INICIANDO VALIDAÇÃO E RENDERIZAÇÃO DA CENA DE ENCONTRO DAS 3 ÁGUAS 16X16M ---")
	var scene_res = load("res://cena_encontro_3_aguas_16x16.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena_encontro_3_aguas_16x16.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames para geração da malha e compilação dos shaders
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
	# Mostra os 3 braços ao Norte, a confluência central e o rio principal ao Sul
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.2, 0.0)
		cam.size = 20.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_encontro_3_aguas_geral.png")

	# 2. Captura 2: Close-up Focado na Confluência Central das 3 Águas
	# Enquadra o ponto exato onde Turquesa, Barrenta e Preta se encontram
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.0, -2.0)
		cam.size = 10.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_encontro_3_aguas_confluencia.png")

	# 3. Captura 3: Close-up Focado nas Faixas de Mistura Contínua do Rio Principal
	# Enquadra o leito inferior com as faixas correndo lado a lado (Turquesa - Barrenta - Preta)
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 0.8, 3.2)
		cam.size = 10.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_encontro_3_aguas_faixas_mistura.png")

	# 4. Captura 4: Close-up do Flanco Oeste (Água Turquesa Cristalina e Margem de Calcário)
	if pivot and cam:
		pivot.global_position = Vector3(-3.5, 1.0, 1.0)
		cam.size = 5.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_encontro_3_aguas_turquesa.png")

	print("--- TODAS AS VALIDAÇÕES E CAPTURAS DO ENCONTRO DAS 3 ÁGUAS CONCLUÍDAS COM SUCESSO! ---")
	quit(0)
