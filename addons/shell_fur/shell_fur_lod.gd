# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
const ShellFurManager = preload("res://addons/shell_fur/shell_fur_manager.gd")

var current_LOD : int

var _shell_fur : ShellFurManager
var _fur_contract := 0.0

func init(shell_fur_object : ShellFurManager) -> void:
	_shell_fur = shell_fur_object

func process(delta : float) -> void:
	var _camera := _shell_fur.get_viewport().get_camera()
	if _camera == null:
		return
	
	var distance := _camera.global_transform.origin.distance_to(_shell_fur.global_transform.origin)
	if distance <= _shell_fur.lod_LOD0_distance:
		current_LOD = 0	
	if _shell_fur.lod_LOD0_distance < distance and distance <= _shell_fur.lod_LOD1_distance:
		current_LOD = 1
	if distance > _shell_fur.lod_LOD1_distance:
		current_LOD = 2
	
	# To avoid calls to the fur child object before it's been generated
	if _shell_fur.fur_object == null:
		return
	match current_LOD:
		0:
			_shell_fur.set_shader_param("i_LOD", 1.0)
		1:
			var lod_value = lerp(1.0, 0.25, (distance - _shell_fur.lod_LOD0_distance) / (_shell_fur.lod_LOD1_distance - _shell_fur.lod_LOD0_distance))
			_shell_fur.set_shader_param("i_LOD", lod_value)
			_fur_contract = move_toward(_fur_contract, 0.0, delta)
			if _fur_contract < 1.0 and _shell_fur.fur_object.visible == false:
				_shell_fur.fur_object.visible = true
		2:
			_shell_fur.set_shader_param("i_LOD", 0.25)
			_fur_contract = move_toward(_fur_contract, 1.1, delta)
			if _fur_contract > 1.0 and _shell_fur.fur_object.visible == true:
				_shell_fur.fur_object.visible = false
	_shell_fur.set_shader_param("i_fur_contract", _fur_contract)
