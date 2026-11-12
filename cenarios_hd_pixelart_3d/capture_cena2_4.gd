extends SceneTree

func _init():
	var root_scene = load("res://cena2_4.tscn").instantiate()
	root.add_child(root_scene)
	
	# Aguarda frames para estabilização, inicialização de shaders e renderização
	for i in range(50):
		await process_frame
		
	var svp = root_scene.get_node("SubViewport") as SubViewport
	if svp:
		var img = svp.get_texture().get_image()
		if img:
			var save_path = "res://screenshot_cena2_4.png"
			img.save_png(save_path)
			print("Screenshot cena2_4 salva com sucesso em: ", save_path)
			
			var img_1080 = Image.new()
			img_1080.copy_from(img)
			img_1080.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
			img_1080.save_png("res://screenshot_cena2_4_1080p.png")
			print("Screenshot 1080p salva com sucesso em: res://screenshot_cena2_4_1080p.png")
		else:
			print("Falha ao obter imagem da viewport de cena2_4")
			
	quit()

