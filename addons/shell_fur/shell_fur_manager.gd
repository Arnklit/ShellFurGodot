# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Node3D
# Fur manager node. Is used to generate the fur objects and control it.
# The node will only generate fur if it is set as a direct child to a 
# MeshInstance node.
# The node will generate fur in two separate ways based on whether the 
# MeshInstance node is a static mesh a skinned mesh.
# For static meshes it use a MultiMeshInstance for skinned meshes it will create
# a multi-layered mesh of its own MeshInstance mesh and place either as a child.
# The node also manages the material of the fur, using a custom shader.

const FurHelperMethods = preload("res://addons/shell_fur/fur_helper_methods.gd")

const PATTERNS = [
	"res://addons/shell_fur/noise_patterns/very_fine.png",
	"res://addons/shell_fur/noise_patterns/fine.png",
	"res://addons/shell_fur/noise_patterns/rough.png",
	"res://addons/shell_fur/noise_patterns/very_rough.png",
	"res://addons/shell_fur/noise_patterns/monster.png",
]

const MATERIAL_CATEGORIES = {
	shape_ = "Shape",
	albedo_ = "Albedo",
	custom_ = "Custom",
}

enum SHADER_TYPES {REGULAR, MOBILE, CUSTOM}
const BUILTIN_SHADERS = [
	{
		name = "Regular",
		shader_path = "res://addons/shell_fur/shaders/shell_fur.gdshader",
	},
	{
		name = "Mobile",
		shader_path = "res://addons/shell_fur/shaders/shell_fur_mobile.gdshader",
	},
]

const DEFAULT_PARAMETERS = {
	shader_type = SHADER_TYPES.REGULAR,
	layers = 40,
	pattern_selector = 0,
	pattern_uv_scale = 5.0,
	cast_shadow = false,
	mat_shader_type = 0,
	mat_transmission = Color(0.3, 0.3, 0.3, 1.0),
	mat_ao = 1.0,
	mat_ao_light_affect = 0.0,
	mat_roughness = 1.0,
	mat_albedo_color = Projection(Vector4(0.43, 0.35, 0.29, 1.0), Vector4(0.78, 0.63, 0.520, 1.0), Vector4(0,0,1,0), Vector4.ZERO),
	mat_albedo_uv_scale = Vector3(1.0, 1.0, 0.0),
	mat_shape_length = 0.5,
	mat_shape_length_rand = 0.3,
	mat_shape_density = 1.0,
	mat_shape_thickness_base = 0.75,
	mat_shape_thickness_tip = 0.3,
	mat_shape_thickness_rand = 0.0,
	mat_shape_growth = 1.0,
	mat_shape_growth_rand = 0.0,
	mat_shape_ldtg_uv_scale = Vector3(1.0, 1.0, 0.0),
	physics_custom_physics_pivot = NodePath(),
	physics_gravity = 0.1,
	physics_spring = 4.0,
	physics_damping = 0.1,
	physics_wind_strength = 0.0,
	physics_wind_speed = 1.0,
	physics_wind_scale = 1.0,
	physics_wind_angle = 0.0,
	styling_blendshape = 0,
	styling_normal_bias = 0.0,
	lod_LOD0_distance = 10.0,
	lod_LOD1_distance = 100.0,
}

var shader_type := 0 : set = set_shader_type
var custom_shader : Shader : set = set_custom_shader
var layers := 40 : set = set_layers
var pattern_selector := 0 : set = set_pattern_selector
var pattern_texture : Texture :		# Need to do it this way as Godot 4 doesn't support optional parameters in getter/setters
	get: return _pattern_texture
	set(value): set_pattern_texture(value)
var pattern_uv_scale = 5.0 : set = set_pattern_uv_scale
var cast_shadow := false : set = set_cast_shadow

# Material - Note the material inspector gets generated from the shader

# Physics
var physics_custom_physics_pivot : NodePath : set = set_custom_physics_pivot
var physics_gravity := 0.1
var physics_spring := 4.0 
var physics_damping := 0.1
var physics_wind_strength := 0.0 : set = set_wind_strength
var physics_wind_speed := 1.0 : set = set_wind_speed
var physics_wind_scale := 1.0 : set = set_wind_scale
var physics_wind_angle := 0.0 : set = set_wind_angle

# Blendshape Styling
var styling_blendshape := 0 : set = set_blendshape
var styling_normal_bias := 0.0 : set = set_normal_bias

# Level of Detail
var lod_LOD0_distance := 10.0 : set = set_LOD0_distance
var lod_LOD1_distance := 100.0 : set = set_LOD1_distance

# Public variables
var fur_object : Node3D

# Private variables
var _material: ShaderMaterial = null
var _lod_system
var _physics_system
var _parent_is_mesh_instance = false 
var _parent_has_mesh_assigned = false 
var _parent_has_skin_assigned = false
var _default_shader: Shader = null
var _multimeshInstance : MultiMeshInstance3D = null
var _first_enter_tree := true
var _parent_object : Node3D
var _skeleton_object
var _custom_pattern := false
var _pattern_texture : Texture

# Built-in Methods
func _get_property_list() -> Array:
	var props = []
	
	var shader_type_hint_string = "Regular, Mobile"
	if custom_shader != null:
		shader_type_hint_string += str(", Custom")
	
	props.append({
			name = "shader_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = shader_type_hint_string,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Shader"
		})
	
	props.append({
			name = "layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "4, 100",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	
	var pattern_selector_hint_string = "Very Fine, Fine, Rough, Very Rough, Monster"
	if _custom_pattern or pattern_selector == PATTERNS.size():
		pattern_selector_hint_string += str(", Custom")
	
	props.append({
			name = "pattern_selector",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = pattern_selector_hint_string,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "pattern_texture",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "Texture",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	props.append({
			name = "pattern_uv_scale",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0, 100",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	})
	props.append({
			name = "cast_shadow",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "Material",
			type = TYPE_NIL,
			hint_string = "mat_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	
	var mat_categories = MATERIAL_CATEGORIES.duplicate(true)
	if _material.shader != null:
		var unordered_shader_params := RenderingServer.get_shader_parameter_list(_material.shader.get_rid())
		var shader_params = FurHelperMethods.reorder_params(unordered_shader_params)
		for shader_param in shader_params:
			# Ignore internal shader uniforms
			if shader_param.name.begins_with("i_"):
				continue
			var hit_category = null
			for category in mat_categories:
				if shader_param.name.begins_with(category):
					props.append({
						name = str("Material/", mat_categories[category]),
						type = TYPE_NIL,
						hint_string = str("mat_", category),
						usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
					})
					hit_category = category
					break
			if hit_category != null:
				mat_categories.erase(hit_category)
			# Put the shader parameter properties in the editor
			var editor_property := {}
			for shader_param_property in shader_param:
				editor_property[shader_param_property] = shader_param[shader_param_property]
			editor_property.name = str("mat_", shader_param.name)
			props.append(editor_property)
	
	props.append({
			name = "Physics",
			type = TYPE_NIL,
			hint_string = "physics_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_custom_physics_pivot",
			type = TYPE_NODE_PATH,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_gravity",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 4.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_spring",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 10.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_damping",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_wind_strength",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_wind_speed",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_wind_scale",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 5.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "physics_wind_angle",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 360.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "Blendshape Styling",
			type = TYPE_NIL,
			hint_string = "styling_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	
	var blendshapes_string := "Disabled"
	if _parent_has_mesh_assigned:
		if _parent_object.mesh.is_class("ArrayMesh"):
			if _parent_object.mesh.get_blend_shape_count() > 0:
				var b_shapes = _parent_object.mesh.get_blend_shape_count()
				for b in b_shapes:
					blendshapes_string += str(", ") + str(_parent_object.mesh.get_blend_shape_name(b))
		
	props.append({
			name = "styling_blendshape",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = blendshapes_string,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	
	if styling_blendshape != 0:
		props.append({
				name = "styling_normal_bias",
				type = TYPE_FLOAT,
				hint = PROPERTY_HINT_RANGE,
				hint_string = "0.0, 1.0",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			})
	
	props.append({
			name = "Lod",
			type = TYPE_NIL,
			hint_string = "lod_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "lod_LOD0_distance",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 100.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	props.append({
			name = "lod_LOD1_distance",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0, 1000.0",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		})
	
	return props


func _set(property: StringName, value) -> bool:
	if property.begins_with("mat_"):
		var param_name = property.right(-len("mat_"))
		set_shader_parameter(param_name, value)
		return true
	return false


func _get(property : StringName):
	if property.begins_with("mat_"):
		var param_name = property.right(-len("mat_"))
		var value = get_shader_parameter(param_name)
		# Godot 4 returns null if the shader uniform hasn't been set, even if the uniform has a default value in the shader
		if not value and DEFAULT_PARAMETERS.has(property):
			value = DEFAULT_PARAMETERS[property]
		return value


func _property_can_revert(property : StringName) -> bool:
	if not DEFAULT_PARAMETERS.has(property):
		return false
	if get(property) != DEFAULT_PARAMETERS[property]:
		return true
	return false


func _property_get_revert(property : StringName):
	if DEFAULT_PARAMETERS.has(property):
		return DEFAULT_PARAMETERS[property]


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load(BUILTIN_SHADERS[shader_type].shader_path) as Shader
	_lod_system = load("res://addons/shell_fur/shell_fur_lod.gd").new()
	_lod_system.init(self)
	_physics_system = load("res://addons/shell_fur/shell_fur_physics.gd").new()
	_physics_system.init(self)
	

func _enter_tree() -> void:
	if Engine.is_editor_hint() and _first_enter_tree:
		_first_enter_tree = false

	_analyse_parent()
	_physics_system.update_physics_object(0.5)
	
	if _parent_has_mesh_assigned:
		# Delaying the fur update to avoid throwing below error on reparenting
		# ERROR "scene/main/node.cpp:1554 - Condition "!owner_valid" is true."
		# Not sure why this is thrown, since it's not a problem when first
		# adding the node.
		_delayed_position_correction()
		# We have to manually set the texture as that cannot be defaulted on the
		# material, so if it's a new object is has to be set to standard (0)
		# otherwise it should be set to something useful already and we can just
		# set it.
		if _pattern_texture == null:
			_pattern_texture = load(PATTERNS[0])
		set_shader_parameter("i_pattern_texture", _pattern_texture)
		# For some reason we have to set some values like colors for them to 
		# show correctly. Even though we are just setting them to themselves.
		# To allow for custom shaders, we simply set all shader params to thier own value.
		var shader_params := RenderingServer.get_shader_parameter_list(_material.shader.get_rid())
		for sp in shader_params:
			set_shader_parameter(sp.name, get_shader_parameter(sp.name))
	
	# Updates the fur if it's needed, clears the fur if it's not
	_update_fur(0.05)


func _ready() -> void:
	_physics_system.update_physics_object(0.0)


func _physics_process(delta: float) -> void:
	_physics_system.process(delta)
	if not Engine.is_editor_hint():
		_lod_system.process(delta)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if not _parent_is_mesh_instance:
		warnings.append("Parent must be a MeshInstance3D node!")
	if not _parent_has_mesh_assigned:
		warnings.append("Parent MeshInstance3D has to have a mesh assigned! Assign a mesh to parent and re-parent fur node to recalculate.")
	return warnings


func _exit_tree() -> void:
	_parent_is_mesh_instance = false
	_parent_has_mesh_assigned = false
	_parent_has_skin_assigned = false


# Getter Methods
func get_current_LOD() -> int:
	return _lod_system.current_LOD


func get_shader_parameter(param : String):
	return _material.get_shader_parameter(param)


# Setter Methods
func set_shader_parameter(param : String, value) -> void:
	_material.set_shader_parameter(param, value)


func set_layers(new_layers : int) -> void:
	layers = new_layers
	if _first_enter_tree:
		return
	set_shader_parameter("i_layers", new_layers)
	_update_fur(0.0)


func set_pattern_selector(index : int) -> void:
	pattern_selector = index
	if _first_enter_tree:
		return
	if index != PATTERNS.size():
		set_pattern_texture(load(PATTERNS[index]), false)
	else:
		set_shader_parameter("i_pattern_texture", _pattern_texture)
	notify_property_list_changed()

func set_pattern_texture(texture : Texture, custom : bool = true) -> void:
	_pattern_texture = texture
	if _first_enter_tree:
		return
	_custom_pattern = custom
	
	set_shader_parameter("i_pattern_texture", texture)
	if custom:
		set_pattern_selector(PATTERNS.size())


func set_pattern_uv_scale(value : float) -> void:
	pattern_uv_scale = value
	set_shader_parameter("i_pattern_uv_scale", value)
	

func set_cast_shadow(value : bool) -> void:
	cast_shadow = value
	if _first_enter_tree:
		return
	fur_object.cast_shadow = value


func set_shader_type(type: int):
	if type == shader_type:
		return
	shader_type = type
	
	if shader_type == SHADER_TYPES.CUSTOM:
		_material.shader = custom_shader
	else:
		_material.shader = load(BUILTIN_SHADERS[shader_type].shader_path)
	
	notify_property_list_changed()


func set_custom_shader(shader : Shader) -> void:
	if custom_shader == shader:
		return
	custom_shader = shader
	if custom_shader != null:
		_material.shader = custom_shader
		
		if Engine.is_editor_hint():
			# Ability to fork default shader
			if shader.code == "":
				var selected_shader = load(BUILTIN_SHADERS[shader_type].shader_path) as Shader
				shader.code = selected_shader.code
	
	if shader != null:
		set_shader_type(SHADER_TYPES.CUSTOM)
	else:
		set_shader_type(SHADER_TYPES.REGULAR)
	
	notify_property_list_changed()


func set_custom_physics_pivot(path : NodePath) -> void:
	physics_custom_physics_pivot = path
	if _first_enter_tree:
		return
	_physics_system.update_physics_object(0.0)


func set_wind_strength(new_wind_strength : float) -> void:
	physics_wind_strength = new_wind_strength
	set_shader_parameter("i_wind_strength", physics_wind_strength)


func set_wind_speed(new_wind_speed : float) -> void:
	physics_wind_speed = new_wind_speed
	set_shader_parameter("i_wind_speed", physics_wind_speed)


func set_wind_scale(new_wind_scale : float) -> void:
	physics_wind_scale = new_wind_scale
	set_shader_parameter("i_wind_scale", physics_wind_scale)


func set_wind_angle(new_wind_angle : float) -> void:
	physics_wind_angle = new_wind_angle
	var angle_vector := Vector2(cos(deg_to_rad(physics_wind_angle)), sin(deg_to_rad(physics_wind_angle)))
	set_shader_parameter("i_wind_angle", Vector3(angle_vector.x, 0.0, angle_vector.y))


func set_blendshape(index: int) -> void:
	styling_blendshape = index
	if _first_enter_tree:
		return
	
	notify_property_list_changed()
	_update_fur(0.1)


func set_normal_bias(value : float) -> void:
	styling_normal_bias = value
	set_shader_parameter("i_normal_bias", styling_normal_bias)


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


# Private functions
func _analyse_parent() -> void:
	var is_arraymesh
	_parent_object = get_parent()
	if _parent_object.get_class() == "MeshInstance3D":
		_parent_is_mesh_instance = true
		if _parent_object.mesh != null:
			_parent_has_mesh_assigned = true
			is_arraymesh = _parent_object.mesh.is_class("ArrayMesh")
			if is_arraymesh:
				if _parent_object.mesh.get_blend_shape_count() < styling_blendshape:
					push_warning("Blendshape selection is higher than new mesh's amount of blendshapes. Disabling blendshape styling.")
					styling_blendshape = 0
			
			if _parent_object.skin != null:
				_parent_has_skin_assigned = true
				_skeleton_object = _parent_object.get_parent()
	
	if not _parent_is_mesh_instance or not _parent_has_mesh_assigned or not is_arraymesh:
		if styling_blendshape != 0:
			push_warning("Fur is no longer assigned to a valid mesh. Disabling blendshape styling.")
			styling_blendshape = 0


func _update_fur(delay : float) -> void:
	await get_tree().create_timer(delay).timeout
	for child in get_children():
		child.free()


	if not _parent_is_mesh_instance:
		return

	
	if _parent_has_skin_assigned:
		FurHelperMethods.generate_mesh_shells(self, _parent_object, layers, _material, styling_blendshape - 1)
		fur_object = FurHelperMethods.generate_combined(self, _parent_object, _material, cast_shadow)
	else:
		_multimeshInstance = MultiMeshInstance3D.new()
		add_child(_multimeshInstance)
		# Uncomment to debug whether MMI is created
		#_multimeshInstance.set_owner(get_tree().get_edited_scene_root()) 
		FurHelperMethods.generate_mmi(layers, _multimeshInstance, _parent_object.mesh, _material, styling_blendshape - 1, cast_shadow)
		fur_object = _multimeshInstance


func _delayed_position_correction() -> void:
	# This is delayed because some transform correction appears to be called
	# internally after _enter_tree and that overrides this value if it's not 
	# delayed
	await get_tree().create_timer(0.1).timeout
	transform = Transform3D.IDENTITY
