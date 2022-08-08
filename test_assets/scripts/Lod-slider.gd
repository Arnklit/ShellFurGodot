extends HSlider


export var fur_path : NodePath
export var lod : String

onready var fur = get_node(fur_path)
onready var label = get_parent().get_node("ValueLabel")

func _ready() -> void:
	var _result = connect("value_changed", self, "_set_lod")
	_set_lod(value)


func _set_lod(value) -> void:
	fur.set_LOD0_distance(value)
	fur.call("set_" + lod + "_distance", value)
	label.text = str(value)
