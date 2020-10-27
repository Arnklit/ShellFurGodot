const ShellFurManager = preload("res://addons/shell_fur/shell_fur_manager.gd")

var _shell_fur_object : ShellFurManager
var _current_LOD : int
var _fur_contract := 0.0

func init(shell_fur_object : ShellFurManager) -> void:
	_shell_fur_object = shell_fur_object

func process(delta : float) -> void:
	var _camera := _shell_fur_object.get_viewport().get_camera()
	if _camera == null:
		return

	var distance := _camera.global_transform.origin.distance_to(_shell_fur_object.global_transform.origin)
	if distance <= _shell_fur_object.lod_LOD0_distance:
		_current_LOD = 0	
	if _shell_fur_object.lod_LOD0_distance < distance and distance <= _shell_fur_object.lod_LOD1_distance:
		_current_LOD = 1
	if distance > _shell_fur_object.lod_LOD1_distance:
		_current_LOD = 2
	
	match _current_LOD:
		0:
			_shell_fur_object.material.set_shader_param("LOD", 1.0)
		1:
			var lod_value = lerp(1.0, 0.25, (distance - _shell_fur_object.lod_LOD0_distance) / (_shell_fur_object.lod_LOD1_distance - _shell_fur_object.lod_LOD0_distance))
			_shell_fur_object.material.set_shader_param("LOD", lod_value)
		2:
			_shell_fur_object.material.set_shader_param("LOD", 0.25)
			_fur_contract = clamp(distance - _shell_fur_object.lod_LOD1_distance - 1, 0.0, 1.1)
			_shell_fur_object.material.set_shader_param("fur_contract", _fur_contract)
			if _shell_fur_object.fur_object == null:
				return
			if _fur_contract > 1.0 and _shell_fur_object.fur_object.visible == true:
				_shell_fur_object.fur_object.visible = false
			if _fur_contract < 1.0 and _shell_fur_object.fur_object.visible == false:
				_shell_fur_object.fur_object.visible = true
