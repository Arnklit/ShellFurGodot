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

const DEFAULT_SHADER_PATH = "res://addons/shell_fur/shell_fur.shader"

const PATTERNS = [
	"res://addons/shell_fur/noise_patterns/fine_hair.png",
	"res://addons/shell_fur/noise_patterns/rough_hair.png",
	"res://addons/shell_fur/noise_patterns/moss.png",
	]

export(int, 4, 100, 0.9) var layers = 40 setget set_layers
export(Texture) var pattern_texture setget set_pattern_texture
export(int, "Fine Hair", "Rough Hair", "Moss") var pattern_selector setget set_pattern_selector
export(float, 0.0, 100.0) var density := 5.0 setget set_density
export(float, 0.0, 5.0) var length := 0.5 setget set_length
export(float, 0.0, 1.0) var length_rand := 0.3 setget set_length_rand
export(Texture) var length_texture setget set_length_texture
export(Vector2) var length_tiling := Vector2(1.0, 1.0) setget set_length_tiling
export(float, 0.0, 1.0) var thickness_base := 0.75 setget set_thickness_base
export(float, 0.0, 1.0) var thickness_tip := 0.3 setget set_thickness_tip

export(Color, RGB) var base_color := Color(0.43, 0.35, 0.29) setget set_base_color
export(Color, RGB) var tip_color := Color(0.78, 0.63, 0.52) setget set_tip_color
export(Texture) var color_texture setget set_color_texture
export(Vector2) var color_tiling := Vector2(1.0, 1.0) setget set_color_tiling
export(Color, RGB) var transmission := Color(0.3, 0.3, 0.3) setget set_transmission
export(float, 0.0, 2.0) var ao := 1.0 setget set_ao
export(float, 0.0, 1.0) var roughness := 1.0 setget set_roughness
export(float, 0.0, 1.0) var normal_adjustment := 0.0 setget set_normal_adjustment

export(NodePath) var custom_physics_pivot : NodePath setget set_custom_physics_pivot
export(float, 0.0, 4.0) var gravity := 0.1 setget set_gravity
export(float, 0.0, 10.0) var spring := 4.0 
export(float, 0.0, 1.0) var damping := 0.1
export(float, 0.0, 5.0) var wind_strength := 0.0 setget set_wind_strength
export(float, 0.0, 5.0) var wind_speed := 1.0 setget set_wind_speed
export(float, 0.0, 5.0) var wind_scale := 1.0 setget set_wind_scale
export(float, 0.0, 360) var wind_angle := 0.0 setget set_wind_angle

export(int) var blendshape_index := -1 setget set_blendshape_index
export(float, 0.0, 1.0) var normal_bias := 0.0 setget set_normal_bias

export(float, 1.0, 100.0) var LOD0_distance := 10.0 setget set_LOD0_distance
export(float, 1.0, 1000.0) var LOD1_distance := 100.0 setget set_LOD1_distance 

export(Shader) var custom_shader : Shader setget set_custom_shader

var _parent_is_mesh_instance = false 
var _parent_has_mesh_assigned = false 
var _parent_has_skin_assigned = false
var _material: ShaderMaterial = null
var _default_shader: Shader = null
var _multimeshInstance : MultiMeshInstance = null
var _first_enter_tree := true
var _fur_object : Spatial
var _parent_object : Spatial
var _skeleton_object
var _trans_momentum : Vector3
var _rot_momentum : Vector3
var _physics_pos : Vector3
var _physics_rot : Quat
var _fur_contract := 0.0
var _current_LOD := 0

# Built-in Methods

func _init() -> void:
	_default_shader = load(DEFAULT_SHADER_PATH) as Shader
	_material = ShaderMaterial.new()
	_material.shader = _default_shader


func _enter_tree() -> void:	
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false

	_analyse_parent()
	_update_physics_object(0.5)
	
	if _parent_has_mesh_assigned:
		# Delaying the fur update to avoid throwing below error on reparenting
		# ERROR "scene/main/node.cpp:1554 - Condition "!owner_valid" is true."
		# Not sure why this is thrown, since it's not a problem when first
		# adding the node.
		_delayed_position_correction()
		set_pattern_texture(load(PATTERNS[pattern_selector]))
		# Force colors
		set_tip_color(tip_color)
		set_base_color(base_color)
	
	# Updates the fur if it's needed, clears the fur if it's not
	_update_fur(0.05)


func _ready() -> void:
	_update_physics_object(0.0)


func _physics_process(delta: float) -> void:
	_process_fur_physics(delta)
	if not Engine.editor_hint:
		_process_LOD(delta)


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
	if _fur_object != null:
		if _fur_object.visible == false:
			return 3
	return _current_LOD

# Setter Methods

func set_layers(new_layers : int) -> void:
	layers = new_layers
	if _first_enter_tree:
		return
	_material.set_shader_param("layers", new_layers)
	_update_fur(0.0)


func set_pattern_texture(texture : Texture) -> void:
	pattern_texture = texture
	_material.set_shader_param("pattern_texture", texture)


func set_pattern_selector(index : int) -> void:
	set_pattern_texture(load(PATTERNS[index]))
	pattern_selector = index


func set_density(new_desity : float) -> void:
	density = new_desity
	_material.set_shader_param("density", new_desity)


func set_length(new_length : float) -> void:
	length = new_length
	_material.set_shader_param("fur_length", new_length)


func set_length_rand(new_length_rand : float) -> void:
	length_rand = new_length_rand
	_material.set_shader_param("length_rand", new_length_rand)


func set_length_texture(texture : Texture) -> void:
	length_texture = texture
	_material.set_shader_param("length_texture", texture)


func set_length_tiling(tiling : Vector2) -> void:
	length_tiling = tiling
	_material.set_shader_param("length_tiling", tiling)


func set_thickness_base(thickness : float) -> void:
	thickness_base = thickness
	_material.set_shader_param("thickness_base", thickness)


func set_thickness_tip(thickness : float) -> void:
	thickness_tip = thickness
	_material.set_shader_param("thickness_tip", thickness)


func set_color_texture(texture : Texture) -> void:
	color_texture = texture
	_material.set_shader_param("color_texture", texture)


func set_color_tiling(tiling : Vector2) -> void:
	color_tiling = tiling
	_material.set_shader_param("color_tiling", tiling)


func set_base_color(new_color : Color) -> void:
	base_color = new_color;
	_material.set_shader_param("base_color", new_color)


func set_tip_color(new_color : Color) -> void:
	tip_color = new_color;
	_material.set_shader_param("tip_color", new_color)


func set_transmission(new_color : Color) -> void:
	transmission = new_color;
	_material.set_shader_param("transmission", new_color)


func set_ao(new_ao : float) -> void:
	ao = new_ao
	_material.set_shader_param("ao", new_ao)


func set_roughness(new_roughness : float) -> void:
	roughness = new_roughness
	_material.set_shader_param("roughness", new_roughness)


func set_normal_adjustment(new_normal_adjustment : float) -> void:
	normal_adjustment = new_normal_adjustment
	_material.set_shader_param("normal_adjustment", new_normal_adjustment)


func set_custom_physics_pivot(path : NodePath) -> void:
	custom_physics_pivot = path
	if _first_enter_tree:
		return
	_physics_pos = _current_physics_object().global_transform.origin
	_physics_rot = _current_physics_object().global_transform.basis.get_rotation_quat()


func set_gravity(new_gravity : float) -> void:
	gravity = new_gravity
	_material.set_shader_param("gravity", new_gravity)


func set_wind_strength(new_wind_strength : float) -> void:
	wind_strength = new_wind_strength
	_material.set_shader_param("wind_strength", wind_strength)


func set_wind_speed(new_wind_speed : float) -> void:
	wind_speed = new_wind_speed
	_material.set_shader_param("wind_speed", wind_speed)


func set_wind_scale(new_wind_scale : float) -> void:
	wind_scale = new_wind_scale
	_material.set_shader_param("wind_scale", wind_scale)


func set_wind_angle(new_wind_angle : float) -> void:
	wind_angle = new_wind_angle
	var angle_vector := Vector2(cos(deg2rad(wind_angle)), sin(deg2rad(wind_angle)))
	_material.set_shader_param("wind_angle", Vector3(angle_vector.x, 0.0, angle_vector.y))


func set_blendshape_index(index: int) -> void:
	if _first_enter_tree:
		blendshape_index = index
		return
	
	if index != -1:
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
					blendshape_index = index
					_update_fur(0.1)
					return
	else:
		blendshape_index = -1
		_update_fur(0.1)
		return
	push_warning("There are no blend shapes on parent mesh.")
	blendshape_index = -1
	_update_fur(0.1)


func set_normal_bias(value : float) -> void:
	if blendshape_index == -1:
		push_warning("Normal Bias only affects fur using blendshape styling.")
		return
	normal_bias = value
	_material.set_shader_param("normal_bias", normal_bias)


func set_LOD0_distance(value : float) -> void:
	if value > LOD1_distance:
		LOD0_distance = LOD1_distance
	else:
		LOD0_distance = value


func set_LOD1_distance(value : float) -> void:
	if value < LOD0_distance:
		LOD1_distance = LOD0_distance
	else:
		LOD1_distance = value

# Private Methods

func _process_fur_physics(delta: float) -> void:
	var position_diff := _current_physics_object().global_transform.origin - _physics_pos
	_trans_momentum += position_diff * spring
	_trans_momentum += Vector3(0.0, -1.0, 0.0) * gravity
	_physics_pos += _trans_momentum * delta
	_trans_momentum *= damping * -1 + 1
	
	_material.set_shader_param("physics_pos_offset", -position_diff)
	
	var rot_diff := _physics_rot.inverse() * _current_physics_object().global_transform.basis.get_rotation_quat()
	_rot_momentum += rot_diff.get_euler() * spring
	_physics_rot *= Quat(_rot_momentum * delta)
	_rot_momentum *= damping * -1 + 1

	_material.set_shader_param("physics_rot_offset", rot_diff)


func _process_LOD(delta : float) -> void:
	var _camera := get_viewport().get_camera()
	if _camera == null:
		return

	var distance := _camera.global_transform.origin.distance_to(global_transform.origin)
	if distance <= LOD0_distance:
		_current_LOD = 0	
	if LOD0_distance < distance and distance <= LOD1_distance:
		_current_LOD = 1
	if distance > LOD1_distance:
		_current_LOD = 2
	
	match _current_LOD:
		0:
			_material.set_shader_param("LOD", 1.0)
		1:
			var lod_value = lerp(1.0, 0.25, (distance - LOD0_distance) / (LOD1_distance - LOD0_distance))
			_material.set_shader_param("LOD", lod_value)
		2:
			_material.set_shader_param("LOD", 0.25)
			_fur_contract = clamp(distance - LOD1_distance - 1, 0.0, 1.1)
			_material.set_shader_param("fur_contract", _fur_contract)
			if _fur_object == null:
				return
			if _fur_contract > 1.0 and _fur_object.visible == true:
				_fur_object.visible = false
			if _fur_contract < 1.0 and _fur_object.visible == false:
				_fur_object.visible = true


func _analyse_parent() -> void:
	var is_arraymesh
	_parent_object = get_parent()
	if _parent_object.get_class() == "MeshInstance":
		_parent_is_mesh_instance = true
		if _parent_object.mesh != null:
			_parent_has_mesh_assigned = true
			
			is_arraymesh = _parent_object.mesh.is_class("ArrayMesh")
			if is_arraymesh:
				if _parent_object.mesh.get_blend_shape_count() - 1 > blendshape_index:
					blendshape_index = -1
			
			if _parent_object.skin != null:
				_parent_has_skin_assigned = true
				_skeleton_object = _parent_object.get_parent()
	
	if not _parent_is_mesh_instance or not _parent_has_mesh_assigned or not is_arraymesh:
		blendshape_index = -1


func _current_physics_object() -> Spatial:
	if custom_physics_pivot.is_empty():
		return self
	else:
		return get_node(custom_physics_pivot) as Spatial


func _update_physics_object(delay : float) -> void:
	yield(get_tree().create_timer(delay), "timeout")
	_physics_pos = _current_physics_object().global_transform.origin
	_physics_rot = _current_physics_object().global_transform.basis.get_rotation_quat()


func _update_fur(delay : float) -> void:
	yield(get_tree().create_timer(delay), "timeout")
	for child in get_children():
		child.free()
	
	if not _parent_is_mesh_instance:
		return
	
	if _parent_has_skin_assigned:
		FurHelperMethods.generate_mesh_shells(self, _parent_object, layers, _material, blendshape_index)
		_fur_object = FurHelperMethods.generate_combined(self, _parent_object, _material)
	else:
		_multimeshInstance = MultiMeshInstance.new()
		add_child(_multimeshInstance)
		# uncomment to debug whether MMI is created
		#_multimeshInstance.set_owner(get_tree().get_edited_scene_root()) 
		FurHelperMethods.generate_mmi(layers, _multimeshInstance, _parent_object.mesh, _material, blendshape_index)
		_fur_object = _multimeshInstance


func _delayed_position_correction() -> void:
	# This is delayed because some transform correction appears to be called
	# internally after _enter_tree and that overrides this value if it's not 
	# delayed
	yield(get_tree().create_timer(0.1), "timeout")
	transform = Transform.IDENTITY


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
