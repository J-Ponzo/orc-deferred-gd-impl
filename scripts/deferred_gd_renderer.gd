extends ORC_RendererBase
class_name ORC_DeferredGDRenderer

var current_cam_data : ORC_DeferredGD_CameraData
var opaque_surfaces_data : Array[ORC_DeferredGD_SurfaceData]
var no_shadow_light_data : Array[ORC_DeferredGD_LightData]
var shadow_light_data : Array[ORC_DeferredGD_LightData]

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

	no_shadow_light_data.clear()
	var no_shadow_omni_data : Array = scene_proxy.fetch_queue_data("omnis_no_shadow")
	for light_data : ORC_DeferredGD_LightData in no_shadow_omni_data:
		no_shadow_light_data.append(light_data)
	var no_shadow_spot_data : Array = scene_proxy.fetch_queue_data("spots_no_shadow")
	for light_data : ORC_DeferredGD_LightData in no_shadow_spot_data:
		no_shadow_light_data.append(light_data)
	var no_shadow_directional_data : Array = scene_proxy.fetch_queue_data("directionals_no_shadow")
	for light_data : ORC_DeferredGD_LightData in no_shadow_directional_data:
		no_shadow_light_data.append(light_data)

	shadow_light_data.clear()
	var shadow_omni_data : Array = scene_proxy.fetch_queue_data("omnis_shadow")
	for light_data : ORC_DeferredGD_LightData in shadow_omni_data:
		shadow_light_data.append(light_data)
	var shadow_spot_data : Array = scene_proxy.fetch_queue_data("spots_shadow")
	for light_data : ORC_DeferredGD_LightData in shadow_spot_data:
		shadow_light_data.append(light_data)
	var shadow_directional_data : Array = scene_proxy.fetch_queue_data("directionals_shadow")
	for light_data : ORC_DeferredGD_LightData in shadow_directional_data:
		shadow_light_data.append(light_data)
	
func render_override() -> void:
	get_render_pass("Geometry").render()
	get_render_pass("Shading").render()

func get_render_target_override() -> RID:
	return get_attachment("Shaded")

func cleanup_override() -> void:
	pass
