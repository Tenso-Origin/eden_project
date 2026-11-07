@tool
extends Node3D
## =========================================================================
## SHADOW CLEANER — @tool para Godot 4
## =========================================================================
## Utilitário de limpeza de cena que desliga as sombras de todos os
## MeshInstance3D filhos de um nó, resolvendo "z-fighting" de sombras e
## sobreposição visual em grupos de meshes modulares (pedras, vegetação, etc).
##
## CONVENÇÃO DE PROTEÇÃO:
##   Nós cujo nome terminar com '_ShadowCaster' NÃO serão afetados.
##   Use este sufixo nos meshes que DEVEM continuar projetando sombra.
##   Exemplo: "RockBase_ShadowCaster" → sombra mantida.
##            "RockDetail"            → sombra desligada.
##
## USO:
##   1. Anexe este script ao Node3D raiz do grupo.
##   2. No Inspetor, marque "Disable Internal Shadows" para executar.
##   3. A variável retorna automaticamente para false após a execução.
##   4. Para restaurar, use "Restore All Shadows" ou redefina manualmente.
## =========================================================================

## BOTÃO PRINCIPAL: Desliga sombras em todos os filhos MeshInstance3D,
## exceto os que terminam com '_ShadowCaster'.
@export var disable_internal_shadows: bool = false:
	set(val):
		if val and Engine.is_editor_hint():
			_run_disable_shadows()
		# Retorna para false imediatamente, comportando-se como um botão.
		disable_internal_shadows = false

## BOTÃO DE RESTAURAÇÃO: Religa as sombras em todos os filhos (modo padrão).
@export var restore_all_shadows: bool = false:
	set(val):
		if val and Engine.is_editor_hint():
			_run_restore_shadows()
		restore_all_shadows = false

## Se verdadeiro, exibe no console o nome de cada nó processado.
@export var verbose_log: bool = true


func _run_disable_shadows() -> void:
	# -----------------------------------------------------------------------
	# PASSO 1: Validação — garante que o nó está ativo na árvore do editor.
	# -----------------------------------------------------------------------
	if not is_inside_tree():
		push_error("[ShadowCleaner] Nó não está na árvore. Operação cancelada.")
		return

	print("[ShadowCleaner] Desligando sombras internas em: ", name)

	var count_disabled: int = 0
	var count_protected: int = 0

	# -----------------------------------------------------------------------
	# PASSO 2: Percorre toda a hierarquia de filhos recursivamente.
	# -----------------------------------------------------------------------
	var all_meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, all_meshes)

	for mi in all_meshes:
		# PASSO 3: Verifica o sufixo de proteção '_ShadowCaster'.
		# Nós protegidos mantêm suas sombras intactas.
		if mi.name.ends_with("_ShadowCaster"):
			if verbose_log:
				print("  [PROTEGIDO] Mantendo sombra em: ", mi.name)
			count_protected += 1
			continue

		# PASSO 4: Desliga a sombra do MeshInstance não protegido.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		if verbose_log:
			print("  → Sombra desligada: ", mi.name)

		count_disabled += 1

	# -----------------------------------------------------------------------
	# PASSO 5: Relatório final no console do editor.
	# -----------------------------------------------------------------------
	print("[ShadowCleaner] ✓ Concluído!")
	print("  Sombras desligadas : ", count_disabled)
	print("  Nós protegidos     : ", count_protected, " (sufixo '_ShadowCaster')")
	print("  Total processado   : ", count_disabled + count_protected)


func _run_restore_shadows() -> void:
	## Restaura o modo de sombra padrão (ON) em todos os filhos MeshInstance3D.
	## Útil para desfazer a operação de limpeza caso precise reconfigurar.
	if not is_inside_tree():
		push_error("[ShadowCleaner] Nó não está na árvore. Operação cancelada.")
		return

	print("[ShadowCleaner] Restaurando sombras em todos os filhos de: ", name)

	var all_meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, all_meshes)

	for mi in all_meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if verbose_log:
			print("  ↑ Sombra restaurada: ", mi.name)

	print("[ShadowCleaner] ✓ ", all_meshes.size(), " mesh(es) restaurados para SHADOW_CASTING_SETTING_ON.")


## Coleta recursivamente todos os MeshInstance3D na hierarquia de filhos.
func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		# Recursão para grupos aninhados.
		if child.get_child_count() > 0:
			_collect_mesh_instances(child, result)
