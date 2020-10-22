tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("ShellFur", "Spatial", preload("shell_fur_manager.gd"), preload("fur_node_icon.png"))
	
func _exit_tree() -> void:
	remove_custom_type("ShellFur")
