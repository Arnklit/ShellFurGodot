const ShellFurManager = preload("res://addons/shell_fur/shell_fur_manager.gd")

var _shell_fur_object : ShellFurManager
var _trans_momentum : Vector3
var _rot_momentum : Vector3
var _physics_pos : Vector3
var _physics_rot : Quat


func init(shell_fur_object : ShellFurManager) -> void:
	_shell_fur_object = shell_fur_object


func process(delta) -> void:
	var position_diff := _current_physics_object().global_transform.origin - _physics_pos
	_trans_momentum += position_diff * _shell_fur_object.physics_spring
	_trans_momentum += Vector3(0.0, -1.0 * _shell_fur_object.physics_gravity, 0.0)
	_physics_pos += _trans_momentum * delta
	_trans_momentum *= _shell_fur_object.physics_damping * -1 + 1
	
	_shell_fur_object.material.set_shader_param("physics_pos_offset", -position_diff)
	
	var rot_diff := _physics_rot.inverse() * _current_physics_object().global_transform.basis.get_rotation_quat()
	_rot_momentum += rot_diff.get_euler() * _shell_fur_object.physics_spring
	_physics_rot *= Quat(_rot_momentum * delta)
	_rot_momentum *= _shell_fur_object.physics_damping * -1 + 1
	
	_shell_fur_object.material.set_shader_param("physics_rot_offset", rot_diff)


func _current_physics_object() -> Spatial:
	if _shell_fur_object.physics_custom_physics_pivot.is_empty():
		return _shell_fur_object
	else:
		return _shell_fur_object.get_node(_shell_fur_object.physics_custom_physics_pivot) as Spatial


func update_physics_object(delay : float) -> void:
	yield(_shell_fur_object.get_tree().create_timer(delay), "timeout")
	_physics_pos = _current_physics_object().global_transform.origin
	_physics_rot = _current_physics_object().global_transform.basis.get_rotation_quat()
