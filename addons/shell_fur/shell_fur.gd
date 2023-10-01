# Copyright © 2023 Kasper Arnklit Frandsen and Contributers - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("ShellFur", "Node3D", preload("shell_fur_manager.gd"), preload("fur_node_icon.svg"))
	
func _exit_tree() -> void:
	remove_custom_type("ShellFur")
