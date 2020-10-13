tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("ShellFur", "Spatial", preload("shell_fur_generator.gd"), preload("icon.png"))
	
func _exit_tree() -> void:
	remove_custom_type("ShellFur")
