# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
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
	custom_ = "Custom"
}

enum SHADER_TYPES {REGULAR, MOBILE, CUSTOM}
const BUILTIN_SHADERS = [
	{
		name = "Regular",
		shader_path = "res://addons/shell_fur/shaders/shell_fur.shader",
	},
	{
		name = "Mobile",
		shader_path = "res://addons/shell_fur/shaders/shell_fur_mobile.shader",
	}
]

const DEFAULT_PARAMETERS = {
	layers = 40,
	pattern_selector = 0,
	cast_shadow = false,
	mat_shader_type = 0,
	mat_custom_shader = null,
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
	lod_LOD1_distance = 100.0
}

var layers := 40 setget set_layers
var pattern_selector := 0 setget set_pattern_selector
var cast_shadow := false setget set_cast_shadow

# Material
var mat_shader_type := 0 setget set_shader_type
var mat_custom_shader : Shader setget set_custom_shader

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
func _get_property_list() -> Array:
	var props = [
		{
			name = "layers",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0, 100",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "pattern_selector",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Very Fine, Fine, Rough, Very Rough, Monster",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "cast_shadow",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "Material",
			type = TYPE_NIL,
			hint_string = "mat_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_shader_type",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Regular, Mobile, Custom",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		},
		{
			name = "mat_custom_shader",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint_string = "Shader"
		}
	]
	
	var props2 = []
	var mat_categories = MATERIAL_CATEGORIES.duplicate(true)
	
	if material.shader != null:
		var shader_params := VisualServer.shader_get_param_list(material.shader.get_rid())
		shader_params = FurHelperMethods.reorder_params(shader_params)
		for p in shader_params:
			if p.name.begins_with("i_"):
				continue
			var hit_category = null
			for category in mat_categories:
				if p.name.begins_with(category):
					props2.append({
						name = str("Material/", mat_categories[category]),
						type = TYPE_NIL,
						hint_string = str("mat_", category),
						usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
					})
					hit_category = category
					break
			if hit_category != null:
				mat_categories.erase(hit_category)
			var cp := {}
			for k in p:
				cp[k] = p[k]
			cp.name = str("mat_", p.name)
			if "curve" in cp.name:
				cp.hint = PROPERTY_HINT_EXP_EASING
				cp.hint_string = "EASE"
			props2.append(cp)
	
	var props3 = [
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
		}
	]
	return props + props2 + props3


func _set(property: String, value) -> bool:
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		material.set_shader_param(param_name, value)
		return true
	return false


func _get(property : String):
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		return  material.get_shader_param(param_name)


func property_can_revert(property : String) -> bool:
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		return material.property_can_revert(str("shader_param/", param_name))

	if not DEFAULT_PARAMETERS.has(property):
		return false
	if get(property) != DEFAULT_PARAMETERS[property]:
		return true
	return false


func property_get_revert(property : String):
	if property.begins_with("mat_"):
		var param_name = property.right(len("mat_"))
		var revert_value = material.property_get_revert(str("shader_param/", param_name))
		return revert_value
	return DEFAULT_PARAMETERS[property]


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
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
		material.set_shader_param("pattern_texture", load(PATTERNS[pattern_selector]))
		# For some reason we have to set some values like colors for them to 
		# show correctly. Even though we are just setting them to themselves.
		# To allow for custom shaders, we simply set all shader params to thier own value.
		var shader_params := VisualServer.shader_get_param_list(material.shader.get_rid())
		for sp in shader_params:
			material.set_shader_param(sp.name, material.get_shader_param(sp.name))
	
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
	layers = new_layers
	if _first_enter_tree:
		return
	material.set_shader_param("i_layers", new_layers)
	_update_fur(0.0)


func set_pattern_selector(index : int) -> void:
	pattern_selector = index
	if _first_enter_tree:
		return
	material.set_shader_param("pattern_texture", load(PATTERNS[index]))
	property_list_changed_notify()


func set_custom_physics_pivot(path : NodePath) -> void:
	physics_custom_physics_pivot = path
	if _first_enter_tree:
		return
	_physics_system.update_physics_object(0.0)


func set_gravity(new_gravity : float) -> void:
	physics_gravity = new_gravity


func set_wind_strength(new_wind_strength : float) -> void:
	physics_wind_strength = new_wind_strength
	material.set_shader_param("i_wind_strength", physics_wind_strength)


func set_wind_speed(new_wind_speed : float) -> void:
	physics_wind_speed = new_wind_speed
	material.set_shader_param("i_wind_speed", physics_wind_speed)


func set_wind_scale(new_wind_scale : float) -> void:
	physics_wind_scale = new_wind_scale
	material.set_shader_param("i_wind_scale", physics_wind_scale)


func set_wind_angle(new_wind_angle : float) -> void:
	physics_wind_angle = new_wind_angle
	var angle_vector := Vector2(cos(deg2rad(physics_wind_angle)), sin(deg2rad(physics_wind_angle)))
	material.set_shader_param("i_wind_angle", Vector3(angle_vector.x, 0.0, angle_vector.y))


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
	material.set_shader_param("i_normal_bias", styling_normal_bias)


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


func set_shader_type(type: int):
	if type == mat_shader_type:
		return
	mat_shader_type = type
	
	if mat_shader_type == SHADER_TYPES.CUSTOM:
		material.shader = mat_custom_shader
	else:
		material.shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path)
	
	property_list_changed_notify()


func set_custom_shader(shader : Shader) -> void:
	if mat_custom_shader == shader:
		return
	mat_custom_shader = shader
	if mat_custom_shader != null:
		material.shader = mat_custom_shader
		
		if Engine.editor_hint:
			# Ability to fork default shader
			if shader.code == "":
				var selected_shader = load(BUILTIN_SHADERS[mat_shader_type].shader_path) as Shader
				shader.code = selected_shader.code
	
	if shader != null:
		set_shader_type(SHADER_TYPES.CUSTOM)
	else:
		set_shader_type(SHADER_TYPES.REGULAR)


func set_shader_param(param : String, value) -> void:
	material.set_shader_param(param, value)


func set_cast_shadow(value : bool) -> void:
	if _first_enter_tree:
		cast_shadow = value
		return
	cast_shadow = value
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
		FurHelperMethods.generate_mesh_shells(self, _parent_object, layers, material, styling_blendshape_index)
		fur_object = FurHelperMethods.generate_combined(self, _parent_object, material, cast_shadow)
	else:
		_multimeshInstance = MultiMeshInstance.new()
		add_child(_multimeshInstance)
		# uncomment to debug whether MMI is created
		#_multimeshInstance.set_owner(get_tree().get_edited_scene_root()) 
		FurHelperMethods.generate_mmi(layers, _multimeshInstance, _parent_object.mesh, material, styling_blendshape_index, cast_shadow)
		fur_object = _multimeshInstance


func _delayed_position_correction() -> void:
	# This is delayed because some transform correction appears to be called
	# internally after _enter_tree and that overrides this value if it's not 
	# delayed
	yield(get_tree().create_timer(0.1), "timeout")
	transform = Transform.IDENTITY
