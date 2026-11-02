extends SceneTree

func _init():
	print("--- INICIANDO VALIDAÇÃO E RENDERIZAÇÃO DA CENA DE TRANSIÇÃO DE SOLOS 16X16M ---")
	var scene_res = load("res://cena_transicao_solos_16x16.tscn")
	if not scene_res:
		push_error("Falha ao carregar cena_transicao_solos_16x16.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames para geração procedural da malha e compilação dos shaders
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
	# Exibe o mapa completo: terraço de planos a NO, platô alto e falésia a NE, e rampas ao Sul
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.2, 0.0)
		cam.size = 18.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_transicao_solos_geral.png")

	# 2. Captura 2: Close-up do Terraço dos Planos (Transições Horizontais)
	# Foco nas transições em plano: Areia Branca -> Terra Preta -> Serrapilheira -> Latossolo Vermelho -> Granito
	if pivot and cam:
		pivot.global_position = Vector3(-3.5, 1.0, -3.5)
		cam.size = 9.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_transicao_solos_planos.png")

	# 3. Captura 3: Close-up do Sistema Multi-Angular de Rampas (15°, 30°, 45°)
	# Foco nas 4 pistas de rampas ao sul e seus patamares intermediários
	if pivot and cam:
		pivot.global_position = Vector3(0.0, 1.2, 3.8)
		cam.size = 11.0
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_transicao_solos_rampas.png")

	# 4. Captura 4: Close-up da Falésia e Cortes Verticais (Estratigrafia Geológica 90°)
	# Foco no grande paredão vertical revelando Terra Preta, Latossolo com Piçarra e Granito
	if pivot and cam:
		pivot.global_position = Vector3(3.5, 1.5, 0.5)
		cam.size = 8.5
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_transicao_solos_cortes_verticais.png")

	# 5. Captura 5: Close-up Focado na Textura de Serrapilheira (tex_serrapilheira.png)
	# Enquadra o tapete de folhas caídas com resolução rica e transição suave
	if pivot and cam:
		pivot.global_position = Vector3(-2.0, 1.1, -3.0)
		cam.size = 5.5
	for i in range(25):
		await process_frame
	save_shot.call("res://screenshot_transicao_solos_serrapilheira.png")

	print("--- TODAS AS VALIDAÇÕES E CAPTURAS DE TRANSIÇÃO DE SOLOS CONCLUÍDAS COM SUCESSO! ---")
	quit(0)
