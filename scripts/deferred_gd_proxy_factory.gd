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
	elif node is OmniLight3D:
		proxy_object = ORC_DeferredGD_OmniLightProxy.new()
	elif node is SpotLight3D:
		proxy_object = ORC_DeferredGD_SpotLightProxy.new()
	elif node is DirectionalLight3D:
		proxy_object = ORC_DeferredGD_DirectionalLightProxy.new()
	return proxy_object
	
func create_data_from_override(node : Node, registry : ORC_ProxyRegistry) -> ORC_PrimaryData:
	var primary_data : ORC_PrimaryData = null
	if node is Camera3D:
		primary_data = create_camera_data_from(node, registry)
	elif node is MeshInstance3D:
		primary_data = create_mesh_data_from(node, registry)
	elif node is Skeleton3D:
		primary_data = create_skeleton_data_from(node, registry)
	elif node is OmniLight3D:
		primary_data = create_omni_light_data_from(node, registry)
	elif node is SpotLight3D:
		primary_data = create_spot_light_data_from(node, registry)
	elif node is DirectionalLight3D:
		primary_data = create_directional_light_data_from(node, registry)
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

	mesh_data.set_flag("CAST_SHADOW_MESH", mesh_node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	mesh_data.set_flag("SHADOW_ONLY_MESH", mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)

	return mesh_data

# TODO : support variable bone counts ?
func create_skin_data_from(skin : Skin, mesh_data : ORC_DeferredGD_MeshData, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_SkinData:
	var unique_id : int = skin.get_instance_id()
	var skin_data : ORC_DeferredGD_SkinData = create_and_register_secondary(ORC_DeferredGD_SkinData, registry, mesh_data, unique_id)
	if skin_data.is_shared():
		return skin_data
	skin_data.unique_id = unique_id

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
	skeleton_data.unique_id = unique_id

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
	surface_data.vertex_format = vf

	var buffers : Array[RID]
	buffers.append(surface_data.topology_data.position_buffer)

	# TODO : find special shadow mesh if set
	var shadow_vf_info : ORC_VertexFormatInfo = ORC_VertexFormatInfo.new()
	var shadow_buffers : Array[RID]
	shadow_buffers.append(surface_data.topology_data.position_buffer)

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
		shadow_buffers.append(surface_data.topology_data.bones_buffer)
		shadow_vf_info.has_bones = true
	if vf_info.has_weights:
		buffers.append(surface_data.topology_data.weights_buffer)
		shadow_buffers.append(surface_data.topology_data.weights_buffer)
		shadow_vf_info.has_weights = true

	var shadow_vf : int = ORC_RDHelper.create_vertex_format(shadow_vf_info)
	surface_data.shadow_vertex_array = ORC_RDHelper.get_rd().vertex_array_create(surface_data.topology_data.vertex_count, shadow_vf, shadow_buffers)
	surface_data.vertex_array = ORC_RDHelper.get_rd().vertex_array_create(surface_data.topology_data.vertex_count, vf, buffers)

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
		material_data.albedo_tex = RenderingServer.texture_get_rd_texture(material.albedo_texture, true)
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

func create_omni_light_data_from(omni_node : OmniLight3D, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_OmniLightData:
	var omni_data : ORC_DeferredGD_OmniLightData = create_and_register_primary(ORC_DeferredGD_OmniLightData, registry)
	omni_data.set_flag("OMNI", true)
	omni_data.set_flag("CAST_SHADOW_OMNI", omni_node.shadow_enabled)
	omni_data.color = omni_node.light_color
	omni_data.intensity = omni_node.light_energy
	omni_data.location = omni_node.global_position
	omni_data.range = omni_node.omni_range
	omni_data.attenuation = omni_node.omni_attenuation

	var global_transform : Transform3D
	var basis : Basis
	basis = basis.scaled(Vector3(omni_data.range, omni_data.range, omni_data.range))
	global_transform.basis = basis
	global_transform.origin = omni_data.location
	omni_data.model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(global_transform))

	omni_data.light_params_buffer_floats.append(omni_data.location.x)
	omni_data.light_params_buffer_floats.append(omni_data.location.y)
	omni_data.light_params_buffer_floats.append(omni_data.location.z)
	omni_data.light_params_buffer_floats.append(omni_data.intensity)
	var linear_color : Color = omni_data.color.srgb_to_linear()
	omni_data.light_params_buffer_floats.append(linear_color.r)
	omni_data.light_params_buffer_floats.append(linear_color.g)
	omni_data.light_params_buffer_floats.append(linear_color.b)
	omni_data.light_params_buffer_floats.append(omni_data.range)
	omni_data.light_params_buffer_floats.append(0.0)
	omni_data.light_params_buffer_floats.append(0.0)
	omni_data.light_params_buffer_floats.append(0.0)
	omni_data.light_params_buffer_floats.append(omni_data.attenuation)

	omni_data.light_buffer_bytes = omni_data.light_params_buffer_floats.to_byte_array()

	return omni_data

func create_spot_light_data_from(spot_node : SpotLight3D, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_SpotLightData:
	var spot_data : ORC_DeferredGD_SpotLightData = create_and_register_primary(ORC_DeferredGD_SpotLightData, registry)
	spot_data.set_flag("SPOT", true)
	spot_data.set_flag("CAST_SHADOW_SPOT", spot_node.shadow_enabled)
	spot_data.color = spot_node.light_color
	spot_data.intensity = spot_node.light_energy
	spot_data.location = spot_node.global_position
	spot_data.direction = -spot_node.global_basis.z
	spot_data.angle = deg_to_rad(spot_node.spot_angle)
	spot_data.angle_attenuation = spot_node.spot_angle_attenuation
	spot_data.range = spot_node.spot_range
	spot_data.attenuation = spot_node.spot_attenuation

	var radius = spot_data.range * tan(spot_data.angle)
	var basis : Basis = Basis.IDENTITY
	basis.x = radius * spot_node.global_basis.x.normalized()
	basis.y = radius * spot_node.global_basis.y.normalized()
	basis.z = spot_data.range * spot_node.global_basis.z.normalized()
	var global_transform : Transform3D
	global_transform.basis = basis
	global_transform.origin = spot_data.location
	spot_data.model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(global_transform))

	spot_data.light_params_buffer_floats.append(spot_data.location.x)
	spot_data.light_params_buffer_floats.append(spot_data.location.y)
	spot_data.light_params_buffer_floats.append(spot_data.location.z)
	spot_data.light_params_buffer_floats.append(spot_data.angle)
	spot_data.light_params_buffer_floats.append(spot_data.direction.x)
	spot_data.light_params_buffer_floats.append(spot_data.direction.y)
	spot_data.light_params_buffer_floats.append(spot_data.direction.z)
	spot_data.light_params_buffer_floats.append(spot_data.intensity)
	var linear_color : Color = spot_data.color.srgb_to_linear()
	spot_data.light_params_buffer_floats.append(linear_color.r)
	spot_data.light_params_buffer_floats.append(linear_color.g)
	spot_data.light_params_buffer_floats.append(linear_color.b)
	spot_data.light_params_buffer_floats.append(spot_data.angle_attenuation)
	spot_data.light_params_buffer_floats.append(spot_data.range)
	spot_data.light_params_buffer_floats.append(spot_data.attenuation)
	spot_data.light_params_buffer_floats.append(0.0)
	spot_data.light_params_buffer_floats.append(0.0)

	spot_data.light_buffer_bytes = spot_data.light_params_buffer_floats.to_byte_array()

	return spot_data

func create_directional_light_data_from(directional_node : DirectionalLight3D, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_DirectionalLightData:
	var directional_data : ORC_DeferredGD_DirectionalLightData = create_and_register_primary(ORC_DeferredGD_DirectionalLightData, registry)
	directional_data.set_flag("DIRECTIONAL", true)
	directional_data.set_flag("CAST_SHADOW_DIRECTIONAL", directional_node.shadow_enabled)
	directional_data.color = directional_node.light_color
	directional_data.intensity = directional_node.light_energy
	directional_data.direction = -directional_node.global_basis.z
	directional_data.shadow_max_distance = directional_node.directional_shadow_max_distance

	directional_data.light_params_buffer_floats.append(directional_data.direction.x)
	directional_data.light_params_buffer_floats.append(directional_data.direction.y)
	directional_data.light_params_buffer_floats.append(directional_data.direction.z)
	directional_data.light_params_buffer_floats.append(directional_data.intensity)
	var linear_color : Color = directional_data.color.srgb_to_linear()
	directional_data.light_params_buffer_floats.append(linear_color.r)
	directional_data.light_params_buffer_floats.append(linear_color.g)
	directional_data.light_params_buffer_floats.append(linear_color.b)
	directional_data.light_params_buffer_floats.append(0.0)

	directional_data.light_buffer_bytes = directional_data.light_params_buffer_floats.to_byte_array()

	return directional_data

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
	elif data is ORC_DeferredGD_SkinData:
		return free_skin_data(data, registry)
	elif data is ORC_DeferredGD_SkeletonData:
		return free_skeleton_data(data, registry)
	elif data is ORC_DeferredGD_OmniLightData:
		return free_omni_light_data(data, registry)
	elif data is ORC_DeferredGD_SpotLightData:
		return free_spot_light_data(data, registry)
	elif data is ORC_DeferredGD_DirectionalLightData:
		return free_directional_light_data(data, registry)
	
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

func free_skin_data(skin_data : ORC_DeferredGD_SkinData, registry : ORC_ProxyRegistry) -> bool:
	if !skin_data.is_shared():
		if skin_data.invert_bind_pose_array_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(skin_data.invert_bind_pose_array_buffer)
			skin_data.invert_bind_pose_array_buffer = RID()
	return destroy_and_unregister_data(skin_data, registry, skin_data.unique_id)

func free_skeleton_data(skeleton_data : ORC_DeferredGD_SkeletonData, registry : ORC_ProxyRegistry) -> bool:
	if !skeleton_data.is_shared():
		if skeleton_data.invert_bind_pose_array_buffer != RID():
			ORC_RDHelper.get_rd().free_rid(skeleton_data.global_bone_pose_array_buffer)
			skeleton_data.global_bone_pose_array_buffer = RID()
	return destroy_and_unregister_data(skeleton_data, registry, skeleton_data.unique_id)

func free_omni_light_data(omni_light_data : ORC_DeferredGD_OmniLightData, registry : ORC_ProxyRegistry) -> bool:
	return destroy_and_unregister_data(omni_light_data, registry)

func free_spot_light_data(spot_light_data : ORC_DeferredGD_SpotLightData, registry : ORC_ProxyRegistry) -> bool:
	return destroy_and_unregister_data(spot_light_data, registry)

func free_directional_light_data(directional_light_data : ORC_DeferredGD_DirectionalLightData, registry : ORC_ProxyRegistry) -> bool:
	return destroy_and_unregister_data(directional_light_data, registry)
