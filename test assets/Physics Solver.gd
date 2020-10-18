extends Spatial

export var spring = 1.0
export var damping = .2

onready var target_pos = get_node("Target Pos")
onready var current_pos = get_node("Current Pos")

var momentum : Vector3
var rotation_momentum : Vector3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	var position_diff = target_pos.translation - current_pos.translation
	momentum += position_diff * spring
	current_pos.translation += momentum * delta
	momentum *= damping

	var rotation_diff = target_pos.rotation - current_pos.rotation
	rotation_momentum += rotation_diff * spring
	current_pos.rotation += rotation_momentum * delta
	rotation_momentum *= damping

	#var transform_diff : Transform = target_pos.global_transform - current_pos.global_transform
	#momentum += transform_diff * spring
	#current_pos.transform += momentum * delta
	#momentum *= damping
