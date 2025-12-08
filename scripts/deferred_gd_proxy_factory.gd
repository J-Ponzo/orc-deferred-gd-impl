extends ORC_ProxyFactory
class_name ORC_DeferredGDProxyFactory

func create_proxy_from_override(node : Node) -> ORC_ProxyObject:
	var proxy_object : ORC_ProxyObject = null
	if node is Camera3D:
		proxy_object = ORC_DeferredGD_CameraProxy.new()
	elif node is MeshInstance3D:
		proxy_object = ORC_DeferredGD_MeshProxy.new()
	return proxy_object
	
func create_data_from_override(node : Node, registry : ORC_ProxyRegistry) -> ORC_PrimaryData:
	var primary_data : ORC_PrimaryData = null
	if node is Camera3D:
		primary_data = create_camera_data_from(node, registry)
	elif node is MeshInstance3D:
		primary_data = create_mesh_data_from(node, registry)
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

	# TODO Handle skeleton & skin

	for i in range(0, mesh_node.mesh.get_surface_count()):
		var surface_data : ORC_DeferredGD_SurfaceData = create_surface_data_from(mesh_node.mesh, mesh_data, i, registry)
		mesh_data.surfaces_data.append(surface_data)

	return mesh_data

func create_surface_data_from(mesh : Mesh, mesh_data : ORC_DeferredGD_MeshData, surface_index : int, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_SurfaceData:
	var surface_data : ORC_DeferredGD_SurfaceData = create_and_register_secondary(ORC_DeferredGD_SurfaceData, registry, mesh_data)
	surface_data.mesh_data = mesh_data
	surface_data.topology_data = create_topology_data_from(mesh, mesh_data, surface_index, registry)
	var material : BaseMaterial3D = mesh.surface_get_material(surface_index)
	surface_data.material_data = create_material_data_from(material, mesh_data, registry)
	
	return surface_data

func create_topology_data_from(mesh : Mesh, mesh_data : ORC_DeferredGD_MeshData, surface_index : int, registry : ORC_ProxyRegistry) -> ORC_DeferredGD_TopologyData:
	var unique_id : int = mesh.get_instance_id()
	var topology_data : ORC_DeferredGD_TopologyData = create_and_register_secondary(ORC_DeferredGD_TopologyData, registry, mesh_data, unique_id)
	if topology_data.is_shared():
		return topology_data
	topology_data.unique_id = unique_id
	
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
	if material.normal_texture != null:
		material_data.normal_tex = RenderingServer.texture_get_rd_texture(material.normal_texture)
		material_data.normal_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	var orm_tex : Texture2D = try_extract_orm_from_material(material)
	if orm_tex != null:
		material_data.orm_tex = RenderingServer.texture_get_rd_texture(orm_tex)
		material_data.orm_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())

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
	return false

func free_mesh_data(mesh_data : ORC_DeferredGD_MeshData, registry : ORC_ProxyRegistry) -> bool:
	return false

func free_surface_data(surface_data : ORC_DeferredGD_SurfaceData, registry : ORC_ProxyRegistry) -> bool:
	return false
	
func free_topology_data(topology_data : ORC_DeferredGD_TopologyData, registry : ORC_ProxyRegistry) -> bool:
	return false
