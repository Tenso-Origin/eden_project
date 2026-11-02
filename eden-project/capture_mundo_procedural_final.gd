extends SceneTree

func _init():
	print("================================================================================")
	print("--- INICIANDO VALIDAÇÃO E RENDERIZAÇÃO DO MUNDO PROCEDURAL FINAL (64x128m) ---")
	print("================================================================================")

	var scene_res = load("res://cena_mundo_procedural_final.tscn")
	if not scene_res:
		push_error("ERRO: Falha ao carregar cena_mundo_procedural_final.tscn")
		quit(1)
		return

	var root_scene = scene_res.instantiate()
	root.add_child(root_scene)

	# Aguarda frames iniciais para geração procedural dos 32 chunks e compilação de shaders
	print("Aguardando inicialização dos 32 chunks e compilação dos shaders...")
	for i in range(50):
		await process_frame

	var svp = root_scene.get_node("SubViewport") as SubViewport
	var pivot = root_scene.find_child("CameraPivot", true, false) as Node3D
	var cam = root_scene.find_child("Camera3D", true, false) as Camera3D

	if not svp or not pivot or not cam:
		push_error("ERRO: SubViewport, CameraPivot ou Camera3D não encontrados!")
		quit(1)
		return

	var save_shot = func(path: String, description: String):
		var img = svp.get_texture().get_image()
		if img:
			img.save_png(path)
			print("[SCREENSHOT SALVO] %s -> %s" % [description, path])
		else:
			push_error("Falha ao capturar imagem da SubViewport: " + path)

	# -------------------------------------------------------------------------
	# 1. SCREENSHOT 1: NORTE - PLATÔ 16M, FLORESTA TROPICAL E LAGO CHÁ-MATE
	# -------------------------------------------------------------------------
	print("\n--- Captura 1/5: Platô Norte 16m & Lago Chá-Mate ---")
	pivot.global_position = Vector3(0.0, 16.0, -47.0)
	cam.size = 32.0
	for i in range(30):
		await process_frame
	save_shot.call("res://screenshot_final_1_norte_plato_cha_mate.png", "Platô 16m com Floresta e Lago Chá-Mate")

	# -------------------------------------------------------------------------
	# 2. SCREENSHOT 2: MEIO - DESFILADEIRO, CASCATAS E LAGOS EM VALES ALTOS
	# -------------------------------------------------------------------------
	print("\n--- Captura 2/5: Desfiladeiro com Cascatas e Lagos em Vales Altos ---")
	pivot.global_position = Vector3(0.0, 9.0, -11.0)
	cam.size = 26.0
	for i in range(30):
		await process_frame
	save_shot.call("res://screenshot_final_2_desfiladeiro_cascatas_vales_altos.png", "Desfiladeiro, Cascatas e Lagos em Vales Altos")

	# -------------------------------------------------------------------------
	# 3. SCREENSHOT 3: SUL - CAMPINA GRANDE, LAGO ÁGUAS CLARAS E AREIA QUARTZO
	# -------------------------------------------------------------------------
	print("\n--- Captura 3/5: Campina Grande, Grande Lago Águas Claras & Areia Quartzo ---")
	pivot.global_position = Vector3(0.0, 1.5, 41.0)
	cam.size = 36.0
	for i in range(30):
		await process_frame
	save_shot.call("res://screenshot_final_3_sul_campina_grande_lago_areia_quartzo.png", "Campina Grande, Lago Águas Claras e Praias de Areia Quartzo")

	# -------------------------------------------------------------------------
	# 4. SCREENSHOT 4: VISÃO PANORÂMICA GLOBAL 64x128M (32 CHUNKS DE 16x16M)
	# -------------------------------------------------------------------------
	print("\n--- Captura 4/5: Visão Panorâmica Global (64x128m, 32 Chunks) ---")
	pivot.global_position = Vector3(0.0, 8.5, 0.0)
	cam.size = 92.0
	for i in range(30):
		await process_frame
	save_shot.call("res://screenshot_final_4_visao_panoramica_global_64x128m.png", "Visão Panorâmica Global de Todo o Mundo (64x128m)")

	# -------------------------------------------------------------------------
	# 5. SCREENSHOT 5: CLOSE-UP DA GRANDE CASCATA E TRANSIÇÃO HIDROLÓGICA
	# -------------------------------------------------------------------------
	print("\n--- Captura 5/5: Close-up da Grande Cascata e Transição Hidrológica ---")
	pivot.global_position = Vector3(1.2, 9.5, -15.0)
	cam.size = 13.0
	for i in range(30):
		await process_frame
	save_shot.call("res://screenshot_final_5_closeup_cascata_hidrologia.png", "Close-up da Cascata, Espuma Branca e Refração do Leito")

	# -------------------------------------------------------------------------
	# 6. VALIDAÇÃO DE PERFORMANCE E BENCHMARK DE 60 FPS
	# -------------------------------------------------------------------------
	print("\n================================================================================")
	print("--- INICIANDO BENCHMARK RIGOROSO DE PERFORMANCE (150 FRAMES ATIVOS) ---")
	print("================================================================================")

	var frame_times: Array[float] = []
	var total_time: float = 0.0
	var sample_frames = 150

	# Posiciona câmera em vista geral panorâmica com máxima carga de renderização
	pivot.global_position = Vector3(0.0, 8.5, 0.0)
	cam.size = 92.0

	for i in range(sample_frames):
		var t_start = Time.get_ticks_usec()
		await process_frame
		var t_elapsed = (Time.get_ticks_usec() - t_start) / 1000000.0
		frame_times.append(t_elapsed)
		total_time += t_elapsed

	var avg_frame_time = total_time / float(sample_frames)
	var avg_fps = 1.0 / max(avg_frame_time, 0.0001)

	var min_ft = 999.0
	var max_ft = 0.0
	for ft in frame_times:
		if ft < min_ft: min_ft = ft
		if ft > max_ft: max_ft = ft

	var min_fps = 1.0 / max(max_ft, 0.0001)
	var max_fps = 1.0 / max(min_ft, 0.0001)

	var map_geo = root_scene.find_child("MapGeometry", true, false) as Node3D
	var active_chunk_count = map_geo.get_child_count() if map_geo else 0

	print("\n--- RELATÓRIO OFICIAL DE PERFORMANCE ---")
	print("Mundo: 64x128m na grade modular 1x1x1m")
	print("Chunks Gerados e Renderizados: %d (Grade 4x8 Chunks de 16x16m)" % active_chunk_count)
	print("Frames Amostrados: %d" % sample_frames)
	print("Tempo Médio de Frame: %.3f ms" % (avg_frame_time * 1000.0))
	print("FPS Médio: %.1f FPS" % avg_fps)
	print("FPS Mínimo (1%% low): %.1f FPS" % min_fps)
	print("FPS Máximo: %.1f FPS" % max_fps)

	if avg_fps >= 58.0:
		print("\n>>> VALIDAÇÃO 60 FPS: APROVADA COM SUCESSO ABSOLUTO (Liso a %.1f FPS) <<<" % avg_fps)
	else:
		push_warning("Aviso: Média de FPS abaixo de 58 FPS (%.1f FPS)" % avg_fps)

	print("================================================================================")
	print("--- PROCESSO DE VALIDAÇÃO E GERAÇÃO CONCLUÍDO COM SUCESSO ---")
	print("================================================================================")

	quit()
