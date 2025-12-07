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
	return null

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