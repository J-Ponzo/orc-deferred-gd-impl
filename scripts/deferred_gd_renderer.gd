extends ORC_RendererBase
class_name ORC_DeferredGDRenderer

const MAIN_OR_XPlus_SHADOW_ATTACH = "Main_Or_+X_Shadow_Attach"
const XMinus_SHADOW_ATTACH = "-X_Shadow_Attach"
const YPlus_SHADOW_ATTACH = "+Y_Shadow_Attach"
const YMinus_SHADOW_ATTACH = "-Y_Shadow_Attach"
const ZPlus_SHADOW_ATTACH = "+Z_Shadow_Attach"
const ZMinus_SHADOW_ATTACH = "-Z_Shadow_Attach"

# TODO : make a c++ Info variant for this so we can access it from both gdscript and c++
var shadow_attach_def : ORC_AttachmentFormat_Def

var current_cam_data : ORC_DeferredGD_CameraData
var opaque_surfaces_data : Array[ORC_DeferredGD_SurfaceData]
var no_shadow_light_data : Array[ORC_DeferredGD_LightData]
var shadow_light_data : Array[ORC_DeferredGD_LightData]

func setup_override() -> void:
	shadow_attach_def = ORC_AttachmentFormat_Def.new()
	shadow_attach_def.format = RenderingDevice.DATA_FORMAT_D32_SFLOAT
	shadow_attach_def.usage_flags = [RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT]
	shadow_attach_def.width = 4096
	shadow_attach_def.height = 4096

	create_attachment(MAIN_OR_XPlus_SHADOW_ATTACH, ORC_RendererFactory.create_texture_attachment(shadow_attach_def))
	create_attachment(XMinus_SHADOW_ATTACH, ORC_RendererFactory.create_texture_attachment(shadow_attach_def))
	create_attachment(YPlus_SHADOW_ATTACH, ORC_RendererFactory.create_texture_attachment(shadow_attach_def))
	create_attachment(YMinus_SHADOW_ATTACH, ORC_RendererFactory.create_texture_attachment(shadow_attach_def))
	create_attachment(ZPlus_SHADOW_ATTACH, ORC_RendererFactory.create_texture_attachment(shadow_attach_def))
	create_attachment(ZMinus_SHADOW_ATTACH, ORC_RendererFactory.create_texture_attachment(shadow_attach_def))

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
	for light_data : ORC_DeferredGD_LightData in shadow_light_data:
		get_render_pass("Shadow").single_render_call(light_data)
		get_render_pass("Shading").single_render_call(light_data)
	get_render_pass("PostProcess").render()

func get_render_target_override() -> RID:
	return get_attachment("PostProcessed")

func cleanup_override() -> void:
	pass
