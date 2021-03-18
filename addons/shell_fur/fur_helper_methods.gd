# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.

# Static functions used for generation of fur shells

static func generate_mmi(layers : int, mmi : MultiMeshInstance, mesh : Mesh, material : Material, blendshape_index : int, cast_shadow : bool) -> void:
	var mdt = MeshDataTool.new()
	
	if mmi.multimesh == null:
		mmi.multimesh = MultiMesh.new()
		mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		mmi.multimesh.color_format = MultiMesh.COLOR_FLOAT
		mmi.multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_NONE
	
	var new_mesh : Mesh = mesh.duplicate(true) as Mesh
	
	if blendshape_index != -1:
		new_mesh = _blendshape_to_vertex_color(new_mesh, material, blendshape_index)
	else:
		new_mesh = _normals_to_vertex_color(new_mesh, material)
	
	mmi.multimesh.mesh = new_mesh
	mmi.multimesh.instance_count = layers
	mmi.multimesh.visible_instance_count = layers
	for surface in new_mesh.get_surface_count():
		mmi.multimesh.mesh.surface_set_material(surface, material)
	
	for i in layers:
		mmi.multimesh.set_instance_transform(i, Transform(Basis(), Vector3()))
		var grey = float(i) / float(layers)
		mmi.multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, grey))
	
	mmi.cast_shadow = 1 if cast_shadow else 0


# This function compares the base mesh and the chosen blendshape and saves out
# the differences / extrusion vector as vertex colors to be used by the shader
static func _blendshape_to_vertex_color(mesh: Mesh, material : Material, blendshape_index: int) -> Mesh:
	var mdt = MeshDataTool.new()
	var base_mesh_array : PoolVector3Array
	var fur_blend_shape_mesh_array : PoolVector3Array
	
	for m in mesh.get_surface_count():
		base_mesh_array += mesh.surface_get_arrays(m)[0]
		fur_blend_shape_mesh_array += mesh.surface_get_blend_shape_arrays(m)[blendshape_index][0]

	var compare_array = []
	var compare_array_adjusted = []
	var longest_diff_length = 0.0
	var longest_diff_vec

	for i in base_mesh_array.size():
		var diffvec = fur_blend_shape_mesh_array[i] - base_mesh_array[i]
		compare_array.append(diffvec)

		if abs(diffvec.x) > longest_diff_length:
			longest_diff_length = abs(diffvec.x)
			longest_diff_vec = diffvec
		if abs(diffvec.y) > longest_diff_length:
			longest_diff_length = abs(diffvec.y)
			longest_diff_vec = diffvec
		if abs(diffvec.z) > longest_diff_length:
			longest_diff_length = abs(diffvec.z)
			longest_diff_vec = diffvec

	for i in compare_array.size():
		var newx = _vertex_diff_to_vertex_color_value(compare_array[i].x, longest_diff_length)
		var newy = _vertex_diff_to_vertex_color_value(compare_array[i].y, longest_diff_length)
		var newz = _vertex_diff_to_vertex_color_value(compare_array[i].z, longest_diff_length)
		compare_array_adjusted.append( Vector3(newx, newy, newz))

	material.set_shader_param("i_blend_shape_multiplier", longest_diff_length)

	mdt.create_from_surface(_multiple_surfaces_to_single(mesh), 0)
	for i in range(mdt.get_vertex_count()):
		mdt.set_vertex_color(i, Color(compare_array_adjusted[i].x, compare_array_adjusted[i].y, compare_array_adjusted[i].z))
	var new_mesh = Mesh.new()
	mdt.commit_to_surface(new_mesh)
	
	return new_mesh


# This function is used when no blendshape stying will be used, to simply save
# the normals direction as vertex colors, so the same shader code can be used
# regardless of whether a custom extrusion vector is set.
static func _normals_to_vertex_color(mesh: Mesh, material : Material) -> Mesh:
	var mdt = MeshDataTool.new()
	material.set_shader_param("i_blend_shape_multiplier", 1.0)
	
	mdt.create_from_surface(_multiple_surfaces_to_single(mesh), 0)
	for i in range(mdt.get_vertex_count()):
		var normal_scaled = mdt.get_vertex_normal(i) * 0.5 + Vector3(0.5, 0.5, 0.5)
		mdt.set_vertex_color(i, Color(normal_scaled.x, normal_scaled.y, normal_scaled.z))
	var new_mesh = Mesh.new()
	mdt.commit_to_surface(new_mesh)
	
	return new_mesh


static func reorder_params(unordered_params : Array) -> Array:
	var ordered = []
	
	for param in unordered_params:
		if param.hint_string != "Texture":
			ordered.append(param)
		else:
			#find the last index in ordered with the same
			var prefix = param.name.rsplit("_")[0]
			var index = last_prefix_occurence(ordered, prefix)
			if index != -1:
				ordered.insert(index, param)
			else:
				ordered.append(param)
	return ordered


static func last_prefix_occurence(array : Array, search : String) -> int:
	
	var inverted_array = array.duplicate(true)
	inverted_array.invert()
	
	for i in array.size():
		var prefix = inverted_array[i].name.rsplit("_")[0]
		if prefix ==  search:
			return array.size() - i
	
	return -1


static func _multiple_surfaces_to_single(mesh : Mesh) -> Mesh:
	var st := SurfaceTool.new()
	var merging_mesh = Mesh.new()
	
	for surface in mesh.get_surface_count():
		st.append_from(mesh, surface, Transform.IDENTITY)
	merging_mesh = st.commit()
	
	return merging_mesh


static func _vertex_diff_to_vertex_color_value(value : float, factor : float) -> float:
	return (value / factor) * 0.5 + 0.5


static func generate_mesh_shells(shell_fur_object : Spatial, parent_object : Spatial, layers : int, material : Material, blendshape_index : int):
	var mdt = MeshDataTool.new()
	var copy_mesh : Mesh = parent_object.mesh.duplicate(true)
	
	if blendshape_index != -1:
		copy_mesh = _blendshape_to_vertex_color(copy_mesh, material, blendshape_index)
	else:
		copy_mesh = _normals_to_vertex_color(copy_mesh, material)
	
	var merged_mesh = _multiple_surfaces_to_single(copy_mesh)

	for layer in layers:
		var new_object = MeshInstance.new()
		new_object.name = "fur_layer_" + str(layer)
		shell_fur_object.add_child(new_object)
		# Uncomment to debug whether shells are getting created
		#new_object.set_owner(shell_fur_object.get_tree().get_edited_scene_root())
		mdt.create_from_surface(merged_mesh, 0)
		for i in range(mdt.get_vertex_count()):
			var c = mdt.get_vertex_color(i)
			c.a = float(layer) / float(layers)
			mdt.set_vertex_color(i, c)
		var new_mesh := Mesh.new()
		mdt.commit_to_surface(new_mesh)
		new_object.mesh = new_mesh


static func generate_combined(shell_fur_object : Spatial, parent_object : Spatial, material : Material, cast_shadow : bool) -> Spatial:
	var st = SurfaceTool.new()
	
	for child in shell_fur_object.get_children():
		st.append_from(child.mesh, 0, Transform.IDENTITY)
		child.free()
	
	st.index()
	var combined_obj := MeshInstance.new()
	
	combined_obj.name = "CombinedFurMesh"
	combined_obj.mesh = st.commit()
	shell_fur_object.add_child(combined_obj)
	# Uncomment to check whether the object is getting created
	#combined_obj.set_owner(shell_fur_object.get_tree().get_edited_scene_root())
	combined_obj.set_surface_material(0, material)
	combined_obj.set_skin(parent_object.get_skin())
	combined_obj.set_skeleton_path("../../..")
	combined_obj.cast_shadow = 1 if cast_shadow else 0
	
	return combined_obj
