# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends EditorPlugin

const GradientInspector = preload("./inspector_plugin.gd")

var gradient_inspector = GradientInspector.new()

func _enter_tree() -> void:
	add_custom_type("ShellFur", "Spatial", preload("shell_fur_manager.gd"), preload("fur_node_icon.svg"))
	add_inspector_plugin(gradient_inspector)
	
func _exit_tree() -> void:
	remove_custom_type("ShellFur")
	remove_inspector_plugin(gradient_inspector)
