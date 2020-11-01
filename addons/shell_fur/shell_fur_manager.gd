# Copyright © 2020 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Spatial
# Fur manager node. Is used to generate the fur objects and control it.
# The node will only generate fur if it is set as a direct child to a 
# MeshInstance node.
# The node will generate fur in two separate ways based on whether the 
# MeshInstance node is a static mesh a skinned mesh.
# For static meshes it use a MultiMeshInstance for skinned meshes it will create
# a multi-layered mesh of its own MeshInstance mesh and place either as a child.
# The node also manages the material of the fur, using a custom shader.

const FurHelperMethods = preload("res://addons/shell_fur/fur_helper_methods.gd")

const DEFAULT_SHADER_PATH = "res://addons/shell_fur/shaders/shell_fur.shader"

const PATTERNS = [
	"res://addons/shell_fur/noise_patterns/very_fine.png",
	"res://addons/shell_fur/noise_patterns/fine.png",
	"res://addons/shell_fur/noise_patterns/rough.png",
	"res://addons/shell_fur/noise_patterns/very_rough.png",
	"res://addons/shell_fur/noise_patterns/monster.png",
	]

const DEFAULT_PARAMETERS = {
	shape_layers = 40,
	shape_pattern_selector = 0,
	shape_density = 5.0,
	shape_length = 0.5,
	shape_length_rand = 0.3,
	shape_length_texture = null,
	shape_length_tiling = Vector2(1.0, 1.0),
	shape_thickness_base = 0.75,
	shape_thickness_tip = 0.3,
	mat_base_color = Color(0.43, 0.35, 0.29),
	mat_tip_color = Color(0.78, 0.63, 0.52),
	mat_color_texture = null,
	mat_color_tiling = Vector2(1.0, 1.0),
	mat_transmission = Color(0.3, 0.3, 0.3),
	mat_ao = 1.0,
	mat_roughness = 1.0,
	mat_normal_adjustment = 0.0,
	physics_custom_physics_pivot = NodePath(),
	physics_gravity = 0.1,
	physics_spring = 4.0,
	physics_damping = 0.1,
	physics_wind_strength = 0.0,
	physics_wind_speed = 1.0,
	physics_wind_scale = 1.0,
	physics_wind_angle = 0.0,
	styling_blendshape_index = -1,
	styling_normal_bias = 0.0,
	lod_LOD0_distance = 10.0,
	lod_LOD1_distance = 100.0,
	adv_cast_shadow = false,
	adv_custom_shader = null
}

# Shape
var shape_layers := 40 setget set_layers
var shape_pattern_texture : Texture setget set_pattern_texture
var shape_pattern_selector : int setget set_pattern_selector
var shape_density := 5.0 setget set_density
var shape_length := 0.5 setget set_length
var shape_length_rand := 0.3 setget set_length_rand
var shape_length_texture : Texture setget set_length_texture
var shape_length_tiling := Vector2(1.0, 1.0) setget set_length_tiling
var shape_thickness_base := 0.75 setget set_thickness_base
var shape_thickness_tip := 0.3 setget set_thickness_tip

# Material
var mat_base_color := Color(0.43, 0.35, 0.29) setget set_base_color
var mat_tip_color := Color(0.78, 0.63, 0.52) setget set_tip_color
var mat_color_texture : Texture setget set_color_texture
var mat_color_tiling := Vector2(1.0, 1.0) setget set_color_tiling
var mat_transmission := Color(0.3, 0.3, 0.3) setget set_transmission
var mat_ao := 1.0 setget set_ao
var mat_roughness := 1.0 setget set_roughness
var mat_normal_adjustment := 0.0 setget set_normal_adjustment

# Physics
var physics_custom_physics_pivot : NodePath setget set_custom_physics_pivot
var physics_gravity := 0.1 setget set_gravity
var physics_spring := 4.0 
var physics_damping := 0.1
var physics_wind_strength := 0.0 setget set_wind_strength
var physics_wind_speed := 1.0 setget set_wind_speed
var physics_wind_scale := 1.0 setget set_wind_scale
var physics_wind_angle := 0.0 setget set_wind_angle

# Blendshape Styling
var styling_blendshape_index := -1 setget set_blendshape_index
var styling_normal_bias := 0.0 setget set_normal_bias

# Level of Detail
var lod_LOD0_distance := 10.0 setget set_LOD0_distance
var lod_LOD1_distance := 100.0 setget set_LOD1_distance 

# Advanced
var adv_cast_shadow : bool setget set_cast_shadow
var adv_custom_shader : Shader setget set_custom_shader


var material: ShaderMaterial = null
var fur_object : Spatial

var _lod_system
var _physics_system
var _parent_is_mesh_instance = false 
var _parent_has_mesh_assigned = false 
var _parent_has_skin_assigned = false
var _default_shader: Shader = null
var _multimeshInstance : MultiMeshInstance = null
var _first_enter_tree := true
var _parent_object : Spatial
var _skeleton_object


# Built-in Methods
func property_can_revert(p_name: String) -> bool:
	if not DEFAULT_PARAMETERS.has(p_name):
		return false
	if get(p_name) != DEFAULT_PARAMETERS[p_name]:
		return true
	return false


func property_get_revert(p_name: String): # returns Variant
	return DEFAULT_PARAMETERS[p_name]


func _get_property_list() -> Array:
	return [
		{
			name = "Shape",
			type = TYPE_NIL,
			hint_string = "shape_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0, 100",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_pattern_texture",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Texture"
		},
		{
			name = "shape_pattern_selector",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Very Fine, Fine, Rough, Very Rough, Monster",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_density",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 100.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_length",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
				{
			name = "shape_length_rand",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_length_texture",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Texture"
		},
		{
			name = "shape_length_tiling",
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_thickness_base",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "shape_thickness_tip",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Material",
			type = TYPE_NIL,
			hint_string = "mat_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_base_color",
			type = TYPE_COLOR,
			hint = PROPERTY_HINT_COLOR_NO_ALPHA,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_tip_color",
			type = TYPE_COLOR,
			hint = PROPERTY_HINT_COLOR_NO_ALPHA,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_color_texture",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Texture"
		},
		{
			name = "mat_color_tiling",
			type = TYPE_VECTOR2,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_transmission",
			type = TYPE_COLOR,
			hint = PROPERTY_HINT_COLOR_NO_ALPHA,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_ao",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 2.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_roughness",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_normal_adjustment",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Physics",
			type = TYPE_NIL,
			hint_string = "physics_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_custom_physics_pivot",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_gravity",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 4.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_spring",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 10.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_damping",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_wind_strength",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
			{
			name = "physics_wind_speed",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_wind_scale",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "physics_wind_angle",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 360.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
				{
			name = "Blendshape Styling",
			type = TYPE_NIL,
			hint_string = "styling_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "styling_blendshape_index",
			type = TYPE_INT,
			hint_string = "0.0, 360.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "styling_normal_bias",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Lod",
			type = TYPE_NIL,
			hint_string = "lod_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "lod_LOD0_distance",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 100.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "lod_LOD1_distance",
			type = TYPE_REAL,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1000.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Advanced",
			type = TYPE_NIL,
			hint_string = "adv_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "adv_cast_shadow",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "adv_custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Shader"
		},
	]


func _init() -> void:
	_default_shader = load(DEFAULT_SHADER_PATH) as Shader
	material = ShaderMaterial.new()
	material.shader = _default_shader
	_lod_system = load("res://addons/shell_fur/shell_fur_lod.gd").new()
	_lod_system.init(self)
	_physics_system = load("res://addons/shell_fur/shell_fur_physics.gd").new()
	_physics_system.init(self)
	

func _enter_tree() -> void:	
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false

	_analyse_parent()
	_physics_system.update_physics_object(0.5)
	
	if _parent_has_mesh_assigned:
		# Delaying the fur update to avoid throwing below error on reparenting
		# ERROR "scene/main/node.cpp:1554 - Condition "!owner_valid" is true."
		# Not sure why this is thrown, since it's not a problem when first
		# adding the node.
		_delayed_position_correction()
		if shape_pattern_texture != null:
			set_pattern_texture(shape_pattern_texture)
		else:
			set_pattern_texture(load(PATTERNS[shape_pattern_selector]))
		# Force colors
		set_tip_color(mat_tip_color)
		set_base_color(mat_base_color)
	
	# Updates the fur if it's needed, clears the fur if it's not
	_update_fur(0.05)


func _ready() -> void:
	_physics_system.update_physics_object(0.0)


func _physics_process(delta: float) -> void:
	_physics_system.process(delta)
	if not Engine.editor_hint:
		_lod_system.process(delta)


func _get_configuration_warning() -> String:
	if not _parent_is_mesh_instance:
		return "Parent must be a MeshInstance node!"
	if not _parent_has_mesh_assigned:
		return "Parent MeshInstance has to have a mesh assigned! Assign a mesh to parent and re-parent this node to recalculate."
	return ""


func _exit_tree() -> void:
	_parent_is_mesh_instance = false
	_parent_has_mesh_assigned = false
	_parent_has_skin_assigned = false


# Getter Methods
func get_current_LOD() -> int:
	return _lod_system.current_LOD


# Setter Methods
func set_layers(new_layers : int) -> void:
	shape_layers = new_layers
	if _first_enter_tree:
		return
	material.set_shader_param("layers", new_layers)
	_update_fur(0.0)


func set_pattern_texture(texture : Texture) -> void:
	shape_pattern_texture = texture
	material.set_shader_param("pattern_texture", texture)


func set_pattern_selector(index : int) -> void:
	shape_pattern_selector = index
	if _first_enter_tree:
		return
	set_pattern_texture(load(PATTERNS[index]))


func set_density(new_desity : float) -> void:
	shape_density = new_desity
	material.set_shader_param("density", new_desity)


func set_length(new_length : float) -> void:
	shape_length = new_length
	material.set_shader_param("fur_length", new_length)


func set_length_rand(new_length_rand : float) -> void:
	shape_length_rand = new_length_rand
	material.set_shader_param("length_rand", new_length_rand)


func set_length_texture(texture : Texture) -> void:
	shape_length_texture = texture
	material.set_shader_param("length_texture", texture)


func set_length_tiling(tiling : Vector2) -> void:
	shape_length_tiling = tiling
	material.set_shader_param("length_tiling", tiling)


func set_thickness_base(thickness : float) -> void:
	shape_thickness_base = thickness
	material.set_shader_param("thickness_base", thickness)


func set_thickness_tip(thickness : float) -> void:
	shape_thickness_tip = thickness
	material.set_shader_param("thickness_tip", thickness)


func set_color_texture(texture : Texture) -> void:
	mat_color_texture = texture
	material.set_shader_param("color_texture", texture)


func set_color_tiling(tiling : Vector2) -> void:
	mat_color_tiling = tiling
	material.set_shader_param("color_tiling", tiling)


func set_base_color(new_color : Color) -> void:
	mat_base_color = new_color;
	material.set_shader_param("base_color", new_color)


func set_tip_color(new_color : Color) -> void:
	mat_tip_color = new_color;
	material.set_shader_param("tip_color", new_color)


func set_transmission(new_color : Color) -> void:
	mat_transmission = new_color;
	material.set_shader_param("transmission", new_color)


func set_ao(new_ao : float) -> void:
	mat_ao = new_ao
	material.set_shader_param("ao", new_ao)


func set_roughness(new_roughness : float) -> void:
	mat_roughness = new_roughness
	material.set_shader_param("roughness", new_roughness)


func set_normal_adjustment(new_normal_adjustment : float) -> void:
	mat_normal_adjustment = new_normal_adjustment
	material.set_shader_param("normal_adjustment", new_normal_adjustment)


func set_custom_physics_pivot(path : NodePath) -> void:
	physics_custom_physics_pivot = path
	if _first_enter_tree:
		return
	_physics_system.update_physics_object(0.0)


func set_gravity(new_gravity : float) -> void:
	physics_gravity = new_gravity
	material.set_shader_param("gravity", new_gravity)


func set_wind_strength(new_wind_strength : float) -> void:
	physics_wind_strength = new_wind_strength
	material.set_shader_param("wind_strength", physics_wind_strength)


func set_wind_speed(new_wind_speed : float) -> void:
	physics_wind_speed = new_wind_speed
	material.set_shader_param("wind_speed", physics_wind_speed)


func set_wind_scale(new_wind_scale : float) -> void:
	physics_wind_scale = new_wind_scale
	material.set_shader_param("wind_scale", physics_wind_scale)


func set_wind_angle(new_wind_angle : float) -> void:
	physics_wind_angle = new_wind_angle
	var angle_vector := Vector2(cos(deg2rad(physics_wind_angle)), sin(deg2rad(physics_wind_angle)))
	material.set_shader_param("wind_angle", Vector3(angle_vector.x, 0.0, angle_vector.y))


func set_blendshape_index(index: int) -> void:
	if _first_enter_tree:
		styling_blendshape_index = index
		return
	
	if index == -1:
		styling_blendshape_index = -1
		_update_fur(0.1)
		return
	
	if _parent_has_mesh_assigned:
		if _parent_object.mesh.is_class("ArrayMesh"):
			if _parent_object.mesh.get_blend_shape_count() > 0:
				var b_shapes = _parent_object.mesh.get_blend_shape_count()
				if index != 0 and b_shapes == 1:
					push_warning("There is only one blend shape, index has to be '0', or '-1' to disable blend shape styling.")
					return
				if index < 0 or index > b_shapes - 1:
					push_warning("There are only " + str(b_shapes) + " blend shapes on the mesh, index has to be between '0' and '" + str(b_shapes - 1) + "', or '-1' to disable blend shape styling.")
					return
				styling_blendshape_index = index
				_update_fur(0.1)
				return
	
	push_warning("There are no blend shapes on parent mesh.")
	styling_blendshape_index = -1
	_update_fur(0.1)


func set_normal_bias(value : float) -> void:
	if styling_blendshape_index == -1 and value != 0.0:
		push_warning("Normal Bias only affects fur using blendshape styling.")
		return
	styling_normal_bias = value
	material.set_shader_param("normal_bias", styling_normal_bias)


func set_LOD0_distance(value : float) -> void:
	if value > lod_LOD1_distance:
		lod_LOD0_distance = lod_LOD1_distance
	else:
		lod_LOD0_distance = value


func set_LOD1_distance(value : float) -> void:
	if value < lod_LOD0_distance:
		lod_LOD1_distance = lod_LOD0_distance
	else:
		lod_LOD1_distance = value


func set_custom_shader(shader : Shader) -> void:
	if adv_custom_shader == shader:
		return
	adv_custom_shader = shader
	if adv_custom_shader == null:
		material.shader = load(DEFAULT_SHADER_PATH)
	else:
		material.shader = adv_custom_shader
		
		if Engine.editor_hint:
			# Ability to fork default shader
			if shader.code == "":
				shader.code = _default_shader.code


func set_cast_shadow(value : bool) -> void:
	if _first_enter_tree:
		adv_cast_shadow = value
		return
	adv_cast_shadow = value
	fur_object.cast_shadow = value


func _analyse_parent() -> void:
	var is_arraymesh
	_parent_object = get_parent()
	if _parent_object.get_class() == "MeshInstance":
		_parent_is_mesh_instance = true
		if _parent_object.mesh != null:
			_parent_has_mesh_assigned = true
			is_arraymesh = _parent_object.mesh.is_class("ArrayMesh")
			if is_arraymesh:
				if _parent_object.mesh.get_blend_shape_count() - 1 < styling_blendshape_index:
					push_warning("Blendshape index is higher than new mesh's amount of blendshapes. Disabling blendshape styling.")
					styling_blendshape_index = -1
			
			if _parent_object.skin != null:
				_parent_has_skin_assigned = true
				_skeleton_object = _parent_object.get_parent()
	
	if not _parent_is_mesh_instance or not _parent_has_mesh_assigned or not is_arraymesh:
		if styling_blendshape_index != -1:
			push_warning("Fur is no longer assigned to a valid mesh. Disabling blendshape styling.")
			styling_blendshape_index = -1


func _update_fur(delay : float) -> void:
	yield(get_tree().create_timer(delay), "timeout")
	for child in get_children():
		child.free()
	
	if not _parent_is_mesh_instance:
		return
	
	if _parent_has_skin_assigned:
		FurHelperMethods.generate_mesh_shells(self, _parent_object, shape_layers, material, styling_blendshape_index)
		fur_object = FurHelperMethods.generate_combined(self, _parent_object, material, adv_cast_shadow)
	else:
		_multimeshInstance = MultiMeshInstance.new()
		add_child(_multimeshInstance)
		# uncomment to debug whether MMI is created
		#_multimeshInstance.set_owner(get_tree().get_edited_scene_root()) 
		FurHelperMethods.generate_mmi(shape_layers, _multimeshInstance, _parent_object.mesh, material, styling_blendshape_index, adv_cast_shadow)
		fur_object = _multimeshInstance


func _delayed_position_correction() -> void:
	# This is delayed because some transform correction appears to be called
	# internally after _enter_tree and that overrides this value if it's not 
	# delayed
	yield(get_tree().create_timer(0.1), "timeout")
	transform = Transform.IDENTITY
