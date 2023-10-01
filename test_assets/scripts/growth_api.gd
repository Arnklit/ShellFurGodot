@tool
extends MeshInstance3D


@export var enable_growth := false
var _timer := 0.0


func _process(delta : float) -> void:
	if not enable_growth:
		return
	
	_timer += delta
	if _timer > 2.0:
		_timer -= 2.0
	
	get_node("ShellFur").set_shader_parameter("shape_growth", _timer)

