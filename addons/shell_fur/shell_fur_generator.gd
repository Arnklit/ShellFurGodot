tool
extends Spatial
# Fur generator node. Is used to generate the fur objects.
# The node will only generate fur if it is set as a direct child to a Mesh node.
# The node will generate fur in two separate ways based on whether the Mesh
# node is a static mesh a skinned mesh.
# If the mesh is static, the generator with spawn a MultiMeshInstance as a
# child of itself and fill that MultiMeshInstance with instances of the
# parent mesh with varying vertex colors.
# If the mesh is skinned, the generator will manually create copies of the mesh,
# assign them varrying vertex colour and merge the copies to a single mesh,
# and place it as a child of itself.
# Either path will then use the shell_fur.shader for it's material. The shader
# expands the mesh in layers using the vertex color information.
# The shader uses premade noise textures with two channels, one for alpha cutoff
# and one to vary length of strands.
# Under "Custom Shader" you can choose "New Shader" and a copy of the default
# fur shader will be made that you can edit.

const DEFAULT_SHADER_PATH = "res://addons/shell_fur/shell_fur.shader"

const PATTERNS = [
	"res://addons/shell_fur/noise_patterns/fine_hair.png",
	"res://addons/shell_fur/noise_patterns/rough_hair.png",
	"res://addons/shell_fur/noise_patterns/moss.png",
	]

export(Texture) var pattern_texture setget set_pattern_texture
export(int, "Fine Hair", "Rough Hair", "Moss") var pattern_selector setget set_pattern_selector
export(Color, RGB) var base_color := Color(0.43, 0.35, 0.29) setget set_base_color
export(Color, RGB) var tip_color := Color(0.78, 0.63, 0.52) setget set_tip_color
export(Texture) var color_texture setget set_color_texture
export(Texture) var length_texture setget set_length_texture
export(Vector2) var texture_tiling := Vector2(1.0, 1.0) setget set_texture_tiling
export(Color, RGB) var transmission := Color(0.3, 0.3, 0.3) setget set_transmission
export(float, 0.0, 1.0) var roughness := 1.0 setget set_roughness
export(float, 0.0, 1.0) var normal_correction := 1.0 setget set_normal_correction
export(int, 4, 100, 4) var layers = 40 setget set_layers
export(float, 0.0, 20.0) var density := 5.0 setget set_density
export(float, 0.0, 5.0) var length := 0.5 setget set_length
export(float, 0.0, 1.0) var length_rand := 0.3 setget set_length_rand
export(float, 0.0, 1.0) var thickness_base := 0.65 setget set_thickness_base
export(float, 0.0, 1.0) var thickness_tip := 0.3 setget set_thickness_tip
export(float, 0.0, 2.0) var ao := 1.0 setget set_ao
export(float, 0.0, 1.0) var gravity := 0.1 setget set_gravity
export(float, 0.0, 5.0) var wind_strength := 0.0 setget set_wind_strength
export(float, 0.0, 5.0) var wind_speed := 1.0 setget set_wind_speed
export(float, 0.0, 5.0) var wind_scale := 1.0 setget set_wind_scale
export(float, 0.0, 360) var wind_angle := 0.0 setget set_wind_angle
export(Shader) var custom_shader : Shader setget set_custom_shader
export(bool) var use_blendshape := false setget set_use_blendshape
export(int) var blendshape_index := 0 setget set_blendshape_index
export(float, 0.0, 1.0) var normal_bias := 0.0 setget set_normal_bias

var _parent_is_mesh_instance = false 
var _parent_has_mesh_assigned = false 
var _parent_has_skin_assigned = false
var _material: ShaderMaterial = null
var _default_shader: Shader = null
var _multimeshInstance : MultiMeshInstance = null
var _fur_generation_helper
var _first_enter_tree := true
var _parent_object : Spatial
var _skeleton_object


func _init() -> void:
	print("init is run")
	_default_shader = load(DEFAULT_SHADER_PATH)
	_material = ShaderMaterial.new()
	_material.shader = _default_shader
	_fur_generation_helper = preload("res://addons/shell_fur/fur_generation_helper.gd")


func _enter_tree() -> void:	
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false
	
	_analyse_parent()
	
	if _parent_has_mesh_assigned:
		# This should disable use_blendshape if it's enabled and get's moved to 
		# a mesh that doesn't support blend shapes.
		set_use_blendshape(use_blendshape) 
		# Delaying the fur update to avoid throwing below error on reparenting
		# ERROR "scene/main/node.cpp:1554 - Condition "!owner_valid" is true."
		# Not sure why this is thrown, since it's not a problem when first
		# adding the node.
		_update_fur(0.05)
		_delayed_position_correction()
		set_pattern_texture(load(PATTERNS[pattern_selector]))

func _analyse_parent() -> void:
	_parent_object = get_parent()
	if _parent_object.get_class() == "MeshInstance":
		_parent_is_mesh_instance = true
		if _parent_object.mesh != null:
			_parent_has_mesh_assigned = true
			if _parent_object.skin != null:
				_parent_has_skin_assigned = true
				_skeleton_object = _parent_object.get_parent()


func _update_fur(delay : float) -> void:
	yield(get_tree().create_timer(delay), "timeout")
	var b_index : int = blendshape_index if use_blendshape else -1
	for child in get_children():
		remove_child(child)
	
	if _parent_has_skin_assigned:
		_fur_generation_helper.generate_mesh_shells(self, _parent_object, layers, _material, b_index)
		_fur_generation_helper.generate_combined(self, _parent_object, _material)
	else:
		_multimeshInstance = MultiMeshInstance.new()
		add_child(_multimeshInstance)
		_multimeshInstance.set_owner(get_tree().get_edited_scene_root()) 
		_fur_generation_helper.update_mmi(layers, _multimeshInstance, _parent_object.mesh, _material, b_index)

func _exit_tree() -> void:
	print("_exit_tree is called")
	_parent_is_mesh_instance = false
	_parent_has_mesh_assigned = false
	_parent_has_skin_assigned = false


func _delayed_position_correction() -> void:
	# This is delayed because some transform correction appears to be called
	# internall after _enter_tree and that overrides this value if it's not 
	# delayed
	yield(get_tree().create_timer(0.1), "timeout")
	transform = Transform.IDENTITY


func _get_configuration_warning() -> String:
	if not _parent_is_mesh_instance:
		return "Parent must be a MeshInstance node!"
	if not _parent_has_mesh_assigned:
		return "Parent MeshInstance has to have a mesh assigned! Assign a mesh to parent and re-parent this node to recalculate."
	return ""


func set_pattern_selector(var index) -> void:
	set_pattern_texture(load(PATTERNS[index]))
	pattern_selector = index

func set_pattern_texture(var texture) -> void:
	pattern_texture = texture
	_material.set_shader_param("pattern_texture", texture)


func set_color_texture(var texture) -> void:
	color_texture = texture
	_material.set_shader_param("color_texture", texture)


func set_length_texture(var texture) -> void:
	length_texture = texture
	_material.set_shader_param("length_texture", texture)


func set_texture_tiling(tiling : Vector2) -> void:
	texture_tiling = tiling
	_material.set_shader_param("tiling", tiling)


func set_base_color(var new_color) -> void:
	base_color = new_color;
	_material.set_shader_param("base_color", new_color)


func set_tip_color(var new_color) -> void:
	tip_color = new_color;
	_material.set_shader_param("tip_color", new_color)


func set_transmission(var color) -> void:
	transmission = color;
	_material.set_shader_param("transmission", color)


func set_roughness(var new_roughness) -> void:
	roughness = new_roughness
	_material.set_shader_param("roughness", new_roughness)


func set_normal_correction(var new_normal_correction) -> void:
	normal_correction = new_normal_correction
	_material.set_shader_param("normal_correction", new_normal_correction)


func set_layers(var new_layers) -> void:
	if layers == new_layers:
		return
	layers = new_layers
	if _first_enter_tree:
		return
	_material.set_shader_param("layers", new_layers)
	_update_fur(0.0)

func set_density(var new_desity) -> void:
	density = new_desity
	_material.set_shader_param("density", new_desity)


func set_length(var new_length) -> void:
	length = new_length
	_material.set_shader_param("fur_length", new_length)


func set_length_rand(var new_length_rand) -> void:
	length_rand = new_length_rand
	_material.set_shader_param("length_rand", new_length_rand)


func set_thickness_base(var thickness) -> void:
	thickness_base = thickness
	_material.set_shader_param("thickness_base", thickness)


func set_thickness_tip(var thickness) -> void:
	thickness_tip = thickness
	_material.set_shader_param("thickness_tip", thickness)


func set_ao(var new_ao) -> void:
	ao = new_ao
	_material.set_shader_param("ao", new_ao)


func set_gravity(var new_gravity) -> void:
	gravity = new_gravity
	_material.set_shader_param("gravity", new_gravity)


func set_wind_strength(var new_wind_strength) -> void:
	wind_strength = new_wind_strength
	_material.set_shader_param("wind_strength", wind_strength)


func set_wind_speed(var new_wind_speed) -> void:
	wind_speed = new_wind_speed
	_material.set_shader_param("wind_speed", wind_speed)


func set_wind_scale(var new_wind_scale) -> void:
	wind_scale = new_wind_scale
	_material.set_shader_param("wind_scale", wind_scale)


func set_wind_angle(var new_wind_angle) -> void:
	wind_angle = new_wind_angle
	var angle_vector = Vector2(cos(deg2rad(wind_angle)), sin(deg2rad(wind_angle)))
	print("the angle vector is: " + str(angle_vector))
	_material.set_shader_param("wind_angle", Vector3(angle_vector.x, 0.0, angle_vector.y))

func set_custom_shader(shader: Shader) -> void:
	if custom_shader == shader:
		return
	custom_shader = shader
	if custom_shader == null:
		_material.shader = load(DEFAULT_SHADER_PATH)
	else:
		_material.shader = custom_shader
		
		if Engine.editor_hint:
			# Ability to fork default shader
			if shader.code == "":
				shader.code = _default_shader.code


func set_use_blendshape(value: bool) -> void:
	if use_blendshape == value:
		return
	if _first_enter_tree:
		use_blendshape = value
		return
	
	if value:
		if _parent_has_mesh_assigned:
			if _parent_object.mesh.is_class("ArrayMesh"):
				if _parent_object.mesh.get_blend_shape_count() > 0:
					use_blendshape = value
					_update_fur(0.0)
					return
	else:
		use_blendshape = value
		_update_fur(0.0)
		return
	push_warning("There are no blendshapes on the parent mesh.")
	use_blendshape = false

func set_blendshape_index(index: int) -> void:
	if _first_enter_tree:
		blendshape_index = index
		return
	
	if not use_blendshape:
		push_warning("'Use Blendshape' must be enabled before setting the index.")
		return
	var b_shapes = _parent_object.mesh.get_blend_shape_count()
	if index != 0 and b_shapes == 1:
		push_warning("There is only one blend shape, index has to be '0'.")
		return
	if index < 0 or index > b_shapes - 1:
		push_warning("There are only " + str(b_shapes) + " blend shapes on the mesh, index has to be between 0 and " + str(b_shapes - 1) + ".")
		return
	blendshape_index = index
	set_layers(layers)


func set_normal_bias(value: float) -> void:
	if not use_blendshape:
		push_warning("Normal Bias only affects fur using blendshape styling.")
		return
	normal_bias = value
	_material.set_shader_param("normal_bias", normal_bias)
	
