# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
extends EditorInspectorPlugin

const ShellFurManager = preload("res://addons/shell_fur/shell_fur_manager.gd")
var _editor = load("res://addons/shell_fur/editor_property.gd")


func _can_handle(object: Object) -> bool:
	return object is ShellFurManager


func _parse_property(object: Object, type: Variant.Type, path: String, hint: PropertyHint, hint_text: String, usage_flags: int, wide : bool) -> bool:
	if type == TYPE_PROJECTION and "color" in path:
		var editor_property = _editor.new()
		add_property_editor(path, editor_property)
		return true
	return false
