extends ORC_RendererBase
class_name ORC_DeferredGDRenderer

var current_cam_data : ORC_DeferredGD_CameraData
var opaque_surfaces_data : Array[ORC_DeferredGD_SurfaceData]

func setup_override() -> void:
	pass

func pre_render_override() -> void:
	super_pre_render()
	var cameras_data : Array[ORC_ProxyData] = scene_proxy.fetch_queue_data("cameras")
	for camera_data : ORC_DeferredGD_CameraData in cameras_data:
		if camera_data.proxy_object.node.current:
			current_cam_data = camera_data
			break
	
	var non_casted_surfaces_data : Array = scene_proxy.fetch_queue_data("opaque_surfaces")
	opaque_surfaces_data.clear()
	for surface_data : ORC_DeferredGD_SurfaceData in non_casted_surfaces_data:
		opaque_surfaces_data.append(surface_data)
	
func render_override() -> void:
	get_render_pass("Geometry").render()

func get_render_target_override() -> RID:
	return get_attachment("Albedo")

func cleanup_override() -> void:
	pass
