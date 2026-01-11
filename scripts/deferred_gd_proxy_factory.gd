extends ORC_ProxyFactory
class_name ORC_DeferredGDProxyFactory

func create_proxy_from_override(node : Node) -> ORC_ProxyObject:
	var proxy_object : ORC_ProxyObject = null
	if node is Camera3D:
		proxy_object = ORC_DeferredGD_CameraProxy.new()
	elif node is MeshInstance3D:
		proxy_object = ORC_DeferredGD_MeshProxy.new()
	elif node is Skeleton3D:
		proxy_object = ORC_DeferredGD_SkeletonProxy.new()
	return proxy_object
	
func create_data_from_override(node : Node, registry : ORC_ProxyRegistry) -> ORC_PrimaryData:
	var primary_data : ORC_PrimaryData = null
	if node is Camera3D:
		primary_data = create_camera_data_from(node, registry)
	elif node is MeshInstance3D:
		primary_data = create_mesh_data_from(node, registry)
	elif node is Skeleton3D:
		primary_data = create_skeleton_data_from(node, registry)
	return primary_data;

func create_camera_data_from(cam_node : Camera3D, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_CameraData:
	var cam_data : ORC_DeferredGD_CameraData = create_and_register_primary(ORC_DeferredGD_CameraData, registry)
	cam_data.view_transform = cam_node.get_camera_transform().affine_inverse()
	cam_data.view_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(cam_data.view_transform))
	cam_data.projection_matrix_bytes = ORC_RDHelper.proj_to_bytes(cam_node.get_camera_projection().flipped_y())

	var bytes = cam_data.view_matrix_bytes
	bytes.append_array(cam_data.projection_matrix_bytes)

	cam_data.matrices_uniform_buffer = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)
	return cam_data
	
func create_mesh_data_from(mesh_node : MeshInstance3D, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_MeshData:
	var mesh_data : ORC_DeferredGD_MeshData = create_and_register_primary(ORC_DeferredGD_MeshData, registry)
	mesh_data.bounding_box = mesh_node.get_aabb()
	mesh_data.model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(mesh_node.global_transform))

	var skin : Skin = mesh_node.skin
	var node_at_skeleton_path = mesh_node.get_node_or_null(mesh_node.skeleton)
	var skeleton : Skeleton3D = null
	if node_at_skeleton_path != null and node_at_skeleton_path is Skeleton3D:
		skeleton = node_at_skeleton_path
	if skeleton != null && skin != null:
		mesh_data.skin_data = create_skin_data_from(skin, mesh_data, registry)
		mesh_data.skeleton_data = create_skeleton_data_from(skeleton, registry)
		mesh_data.set_flag("SKELETAL", true)

	for i in range(0, mesh_node.mesh.get_surface_count()):
		var surface_data : ORC_DeferredGD_SurfaceData = create_surface_data_from(mesh_node.mesh, mesh_data, i, registry)
		mesh_data.surfaces_data.append(surface_data)

	mesh_data.set_flag("SHADOW", mesh_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	mesh_data.set_flag("SHADOW_ONLY", mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)

	return mesh_data

# TODO : support variable bone counts ?
func create_skin_data_from(skin : Skin, mesh_data : ORC_DeferredGD_MeshData, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_SkinData:
	var unique_id : int = skin.get_instance_id()
	var skin_data : ORC_DeferredGD_SkinData = create_and_register_secondary(ORC_DeferredGD_SkinData, registry, mesh_data, unique_id)
	if skin_data.is_shared():
		return skin_data
	skin_data.instance_id = unique_id

	var invert_bind_poses : Array[Projection] = []
	invert_bind_poses.resize(128)
	for bind_idx in range(skin.get_bind_count()):
		invert_bind_poses[bind_idx] = Projection(skin.get_bind_pose(bind_idx))
	for i in range(invert_bind_poses.size(), 128):
		invert_bind_poses[i] = Projection()

	var byte_array : PackedByteArray = ORC_RDHelper.projs_to_bytes(invert_bind_poses)
	skin_data.invert_bind_pose_array_buffer = ORC_RDHelper.get_rd().uniform_buffer_create(byte_array.size(), byte_array)

	return skin_data

# TODO : support variable bone counts ?
func create_skeleton_data_from(skeleton : Skeleton3D, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_SkeletonData:
	var unique_id : int = skeleton.get_instance_id()
	var skeleton_data : ORC_DeferredGD_SkeletonData = create_and_register_primary(ORC_DeferredGD_SkeletonData, registry, unique_id)
	if skeleton_data.is_shared():
		return skeleton_data
	skeleton_data.instance_id = unique_id

	var global_bone_poses : Array[Projection] = []
	global_bone_poses.resize(128)
	for bone_idx in range(skeleton.get_bone_count()):
		var global_bone_pose : Projection = Projection(skeleton.get_bone_global_pose(bone_idx))
		global_bone_poses[bone_idx] = global_bone_pose
	for i in range(skeleton.get_bone_count(), 128):
		global_bone_poses[i] = Projection()

	var global_bone_pose_array : PackedByteArray = ORC_RDHelper.projs_to_bytes(global_bone_poses)
	skeleton_data.global_bone_pose_array_buffer = ORC_RDHelper.get_rd().uniform_buffer_create(global_bone_pose_array.size(), global_bone_pose_array)

	return skeleton_data

func create_surface_data_from(mesh : Mesh, mesh_data : ORC_DeferredGD_MeshData, surface_index : int, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_SurfaceData:
	var material : BaseMaterial3D = mesh.surface_get_material(surface_index)
	var is_skeletal : bool = mesh_data.has_flag("SKELETAL")
	var vf_info : ORC_VertexFormatInfo = get_vf_info_from_material(material, is_skeletal)
	if !is_vf_compatible_with_mesh_surf(vf_info, mesh, surface_index):
		return null
	
	var surface_data : ORC_DeferredGD_SurfaceData = create_and_register_secondary(ORC_DeferredGD_SurfaceData, registry, mesh_data)
	surface_data.mesh_data = mesh_data
	surface_data.topology_data = create_topology_data_from(mesh, mesh_data, surface_index, registry)
	surface_data.material_data = create_material_data_from(material, mesh_data, registry)
	surface_data.register_flag_sources([mesh_data,surface_data.topology_data, surface_data.material_data])

	var vf : int = ORC_RDHelper.create_vertex_format(vf_info)
	var buffers : Array[RID]
	buffers.append(surface_data.topology_data.position_buffer)
	if vf_info.has_normal:
		buffers.append(surface_data.topology_data.normal_buffer)
	if vf_info.has_tangent:
		buffers.append(surface_data.topology_data.tangent_buffer)
	if vf_info.has_color:
		buffers.append(surface_data.topology_data.color_buffer)
	if vf_info.has_uv:
		buffers.append(surface_data.topology_data.uv_buffer)
	if vf_info.has_uv2:
		buffers.append(surface_data.topology_data.uv2_buffer)
	if vf_info.has_bones:
		buffers.append(surface_data.topology_data.bones_buffer)
	if vf_info.has_weights:
		buffers.append(surface_data.topology_data.weights_buffer)
	surface_data.vertex_array = ORC_RDHelper.get_rd().vertex_array_create(surface_data.topology_data.vertex_count, vf, buffers)
	surface_data.vertex_format = vf

	return surface_data

func is_transparent(render_mode : ORC_PSODef.ERenderMode) -> bool:
	return render_mode == ORC_PSODef.ERenderMode.Transparent_Mix or render_mode == ORC_PSODef.ERenderMode.Transparent_Add or render_mode == ORC_PSODef.ERenderMode.Transparent_Subtract or render_mode == ORC_PSODef.ERenderMode.Transparent_Multiply or render_mode == ORC_PSODef.ERenderMode.Transparent_PremultAlpha

func get_vf_info_from_material(material : BaseMaterial3D, is_skeletal : bool) -> ORC_VertexFormatInfo:
	var vf_info : ORC_VertexFormatInfo = ORC_VertexFormatInfo.new()
	vf_info.is_2d = false
	vf_info.has_normal = material.shading_mode != BaseMaterial3D.ShadingMode.SHADING_MODE_UNSHADED
	vf_info.has_tangent = material.shading_mode != BaseMaterial3D.ShadingMode.SHADING_MODE_UNSHADED
	vf_info.has_color = false
	vf_info.has_uv = material.albedo_texture != null or material.normal_texture != null or try_extract_orm_from_material(material) != null
	vf_info.has_uv2 = false
	vf_info.has_bones = is_skeletal
	vf_info.has_weights = is_skeletal
	return vf_info

# TODO : put in Helper
func surf_array_has(arrays : Array, type : int) -> bool:
	return arrays.size() > type and arrays[type] != null

# TODO : put in helper
func is_vf_compatible_with_mesh_surf(vf_info : ORC_VertexFormatInfo, mesh : Mesh, surface_index : int) -> bool:
	var arrays = mesh.surface_get_arrays(surface_index)
	if vf_info.has_normal && !surf_array_has(arrays, Mesh.ARRAY_NORMAL):
		return false
	if vf_info.has_tangent && !surf_array_has(arrays, Mesh.ARRAY_TANGENT):
		return false
	if vf_info.has_color && !surf_array_has(arrays, Mesh.ARRAY_COLOR):
		return false
	if vf_info.has_uv && !surf_array_has(arrays, Mesh.ARRAY_TEX_UV):
		return false
	if vf_info.has_uv2 && !surf_array_has(arrays, Mesh.ARRAY_TEX_UV2):
		return false
	if vf_info.has_bones && !surf_array_has(arrays, Mesh.ARRAY_BONES):
		return false
	if vf_info.has_weights && !surf_array_has(arrays, Mesh.ARRAY_WEIGHTS):
		return false
	return true

func create_topology_data_from(mesh : Mesh, mesh_data : ORC_DeferredGD_MeshData, surface_index : int, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_TopologyData:
	var unique_id : int = hash(str(mesh.get_instance_id()) + str(surface_index))
	var topology_data : ORC_DeferredGD_TopologyData = create_and_register_secondary(ORC_DeferredGD_TopologyData, registry, mesh_data, unique_id)
	if topology_data.is_shared():
		return topology_data
	topology_data.unique_id = unique_id
	
	var arrays = mesh.surface_get_arrays(surface_index)
	topology_data.index_count = arrays[Mesh.ARRAY_INDEX].size()
	var byte_array = arrays[Mesh.ARRAY_INDEX].to_byte_array()
	topology_data.index_buffer = ORC_RDHelper.get_rd().index_buffer_create(arrays[Mesh.ARRAY_INDEX].size(), RenderingDevice.INDEX_BUFFER_FORMAT_UINT32, byte_array)
	topology_data.index_array = ORC_RDHelper.get_rd().index_array_create(topology_data.index_buffer, 0, topology_data.index_count)

	topology_data.vertex_count = arrays[Mesh.ARRAY_VERTEX].size()
	byte_array = arrays[Mesh.ARRAY_VERTEX].to_byte_array()
	topology_data.position_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)
	
	if  surf_array_has(arrays, Mesh.ARRAY_NORMAL):
		byte_array = arrays[Mesh.ARRAY_NORMAL].to_byte_array()
		topology_data.normal_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)

	if surf_array_has(arrays, Mesh.ARRAY_TANGENT):
		byte_array = arrays[Mesh.ARRAY_TANGENT].to_byte_array()
		topology_data.tangent_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)

	if surf_array_has(arrays, Mesh.ARRAY_COLOR):
		byte_array = arrays[Mesh.ARRAY_COLOR].to_byte_array()
		topology_data.color_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)

	if surf_array_has(arrays, Mesh.ARRAY_TEX_UV):
		byte_array = arrays[Mesh.ARRAY_TEX_UV].to_byte_array()
		topology_data.uv_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)

	if surf_array_has(arrays, Mesh.ARRAY_TEX_UV2):
		byte_array = arrays[Mesh.ARRAY_TEX_UV].to_byte_array()
		topology_data.uv2_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)

	if surf_array_has(arrays, Mesh.ARRAY_BONES):
		byte_array = arrays[Mesh.ARRAY_BONES].to_byte_array()
		topology_data.bones_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)

	if surf_array_has(arrays, Mesh.ARRAY_WEIGHTS):
		byte_array = arrays[Mesh.ARRAY_WEIGHTS].to_byte_array()
		topology_data.weights_buffer = ORC_RDHelper.get_rd().vertex_buffer_create(byte_array.size(), byte_array)
	
	return topology_data

func create_material_data_from(material : BaseMaterial3D, mesh_data : ORC_DeferredGD_MeshData, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_MaterialData:
	var unique_id : int = material.get_instance_id()
	var material_data : ORC_DeferredGD_MaterialData = create_and_register_secondary(ORC_DeferredGD_MaterialData, registry, mesh_data, unique_id)
	if material_data.is_shared():
		return material_data
	material_data.unique_id = unique_id

	var albedo_floats_array : PackedFloat32Array = [material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, material.albedo_color.a]
	var bytes : PackedByteArray =  albedo_floats_array.to_byte_array()
	material_data.albedo_buffer = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

	if material.albedo_texture != null:
		material_data.albedo_tex = RenderingServer.texture_get_rd_texture(material.albedo_texture)
		material_data.albedo_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
		material_data.set_flag("ALBEDO_MAP", true)
	if material.normal_texture != null:
		material_data.normal_tex = RenderingServer.texture_get_rd_texture(material.normal_texture)
		material_data.normal_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
		material_data.set_flag("NORMAL_MAP", true)
	var orm_tex : Texture2D = try_extract_orm_from_material(material)
	if orm_tex != null:
		material_data.orm_tex = RenderingServer.texture_get_rd_texture(orm_tex)
		material_data.orm_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
		material_data.set_flag("ORM_MAP", true)

	if material.cull_mode == BaseMaterial3D.CullMode.CULL_BACK:
		material_data.cull_mode = RenderingDevice.PolygonCullMode.POLYGON_CULL_BACK
	elif material.cull_mode == BaseMaterial3D.CullMode.CULL_DISABLED:
		material_data.cull_mode = RenderingDevice.PolygonCullMode.POLYGON_CULL_DISABLED
	elif material.cull_mode == BaseMaterial3D.CullMode.CULL_FRONT:
		material_data.cull_mode = RenderingDevice.PolygonCullMode.POLYGON_CULL_FRONT

	if material.transparency == BaseMaterial3D.Transparency.TRANSPARENCY_DISABLED:
		material_data.render_mode = ORC_PSODef.ERenderMode.Opaque
	elif material.transparency == BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA_SCISSOR:
		material_data.render_mode = ORC_PSODef.ERenderMode.AlphaScissor
	elif material.transparency == BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA_HASH:
		material_data.render_mode = ORC_PSODef.ERenderMode.AlphaHash
	elif material.transparency == BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA or material.transparency == BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		if material.blend_mode == BaseMaterial3D.BlendMode.BLEND_MODE_MIX:
			material_data.render_mode = ORC_PSODef.ERenderMode.Transparent_Mix
		elif material.blend_mode == BaseMaterial3D.BlendMode.BLEND_MODE_ADD:
			material_data.render_mode = ORC_PSODef.ERenderMode.Transparent_Add
		elif material.blend_mode == BaseMaterial3D.BlendMode.BLEND_MODE_SUB:
			material_data.render_mode = ORC_PSODef.ERenderMode.Transparent_Subtract
		elif material.blend_mode == BaseMaterial3D.BlendMode.BLEND_MODE_MUL:
			material_data.render_mode = ORC_PSODef.ERenderMode.Transparent_Multiply
		elif material.blend_mode == BaseMaterial3D.BlendMode.BLEND_MODE_PREMULT_ALPHA:
			material_data.render_mode = ORC_PSODef.ERenderMode.Transparent_PremultAlpha

	material_data.set_flag("LIT", material.shading_mode != BaseMaterial3D.ShadingMode.SHADING_MODE_UNSHADED)
	material_data.set_flag("IS_TRANSPARENT", is_transparent(material_data.render_mode))

	return material_data

# TODO maybe not in the right place
static func try_extract_orm_from_material(material : BaseMaterial3D) -> Texture2D:
	if material.orm_texture != null:
		return material.orm_texture
	
	var textures : Array[Texture2D]
	if material.ao_texture != null and material.ao_texture_channel == BaseMaterial3D.TextureChannel.TEXTURE_CHANNEL_RED:
		textures.append(material.ao_texture)
	if material.roughness_texture != null and material.roughness_texture_channel == BaseMaterial3D.TextureChannel.TEXTURE_CHANNEL_GREEN:
		textures.append(material.roughness_texture)
	if material.metallic_texture != null and material.metallic_texture_channel == BaseMaterial3D.TextureChannel.TEXTURE_CHANNEL_BLUE:
		textures.append(material.roughness_texture)

	if textures.size() == 0:
		return null
	var texture = textures[0]
	for i in range(1, textures.size()):
		if texture != textures[i]:
			return null

	return texture

func free_proxy_override(proxy_object : ORC_ProxyObject) -> bool:
		return true
		
func free_data_override(data : ORC_ProxyData, registry : ORC_ProxyRegistry) -> bool:
	if data is ORC_DeferredGD_CameraData:
		return free_camera_data(data, registry)
	elif data is ORC_DeferredGD_MaterialData:
		return free_material_data(data, registry)
	elif data is ORC_DeferredGD_MeshData:
		return free_mesh_data(data, registry)
	elif data is ORC_DeferredGD_SurfaceData:
		return free_surface_data(data, registry)
	elif data is ORC_DeferredGD_TopologyData:
		return free_topology_data(data, registry)
	
	return false

func free_camera_data(cam_data : ORC_DeferredGD_CameraData, registry : ORC_ProxyRegistry) -> bool:
	if cam_data.matrices_uniform_buffer != RID():
		ORC_RDHelper.get_rd().free_rid(cam_data.matrices_uniform_buffer)
		cam_data.matrices_uniform_buffer = RID()

	return destroy_and_unregister_data(cam_data, registry)

func free_material_data(mat_data : ORC_DeferredGD_MaterialData, registry : ORC_ProxyRegistry) -> bool:
	if !mat_data.is_shared():
		if mat_data.albedo_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(mat_data.albedo_buffer)
			mat_data.albedo_buffer = RID()
		if mat_data.albedo_sampler != RID():
			ORC_RDHelper.get_rd().free_rid(mat_data.albedo_sampler)
			mat_data.albedo_sampler = RID()
		if mat_data.normal_sampler != RID():
			ORC_RDHelper.get_rd().free_rid(mat_data.normal_sampler)	
			mat_data.normal_sampler = RID()
		if mat_data.orm_sampler != RID():
			ORC_RDHelper.get_rd().free_rid(mat_data.orm_sampler)
			mat_data.orm_sampler = RID()

	return destroy_and_unregister_data(mat_data, registry, mat_data.unique_id)

func free_mesh_data(mesh_data : ORC_DeferredGD_MeshData, registry : ORC_ProxyRegistry) -> bool:
	if mesh_data.invert_bind_pose_array_buffer != RID():
		ORC_RDHelper.get_rd().free_rid(mesh_data.invert_bind_pose_array_buffer)
		mesh_data.invert_bind_pose_array_buffer = RID()
	if mesh_data.instance_storage_buffer != RID():
		ORC_RDHelper.get_rd().free_rid(mesh_data.instance_storage_buffer)
		mesh_data.instance_storage_buffer = RID()
	
	var success : bool = true
	for surface_data in mesh_data.surfaces_data:
		if !destroy_and_unregister_data(surface_data, registry):
			success = false
	
	return success &&  destroy_and_unregister_data(mesh_data, registry)

func free_surface_data(surface_data : ORC_DeferredGD_SurfaceData, registry : ORC_ProxyRegistry) -> bool:
	if surface_data.vertex_array != RID():
		ORC_RDHelper.get_rd().free_rid(surface_data.vertex_array)
		surface_data.vertex_array = RID()
	if surface_data.shadow_vertex_array != RID():
		ORC_RDHelper.get_rd().free_rid(surface_data.shadow_vertex_array)
		surface_data.shadow_vertex_array = RID()
	
	var success : bool = true
	if !destroy_and_unregister_data(surface_data.material_data, registry):
		success = false
	if !destroy_and_unregister_data(surface_data.topology_data, registry):
		success = false
	
	return success && destroy_and_unregister_data(surface_data, registry)

# TODO add try_free_rid in helper
func free_topology_data(topology_data : ORC_DeferredGD_TopologyData, registry : ORC_ProxyRegistry) -> bool:
	if !topology_data.is_shared():
		if topology_data.index_array != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.index_array)
			topology_data.index_array = RID()
		if topology_data.index_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.index_buffer)
			topology_data.index_buffer = RID()
		if topology_data.position_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.position_buffer)
			topology_data.position_buffer = RID()
		if topology_data.normal_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.normal_buffer)
			topology_data.normal_buffer = RID()
		if topology_data.tangent_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.tangent_buffer)
			topology_data.tangent_buffer = RID()
		if topology_data.color_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.color_buffer)
			topology_data.color_buffer = RID()
		if topology_data.uv_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.uv_buffer)
			topology_data.uv_buffer = RID()
		if topology_data.uv2_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.uv2_buffer)
			topology_data.uv2_buffer = RID()
		if topology_data.bones_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.bones_buffer)
			topology_data.bones_buffer = RID()
		if topology_data.weights_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(topology_data.weights_buffer)
			topology_data.weights_buffer = RID()
	
	return destroy_and_unregister_data(topology_data, registry, topology_data.unique_id)
