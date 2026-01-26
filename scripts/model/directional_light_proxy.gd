extends ORC_DeferredGD_LightProxy
class_name ORC_DeferredGD_DirectionalLightProxy

var color_last_frame : Color
var intensity_last_frame : float
var direction_last_frame : Vector3
var shadow_max_distance_last_frame : float

func update_override() -> void:
	super()

	var has_changed = false 
	if node.light_color != color_last_frame:
		color_last_frame = node.light_color
		primary_data.update_color(node)
		has_changed = true

	if node.light_energy != intensity_last_frame:
		intensity_last_frame = node.light_energy
		primary_data.update_intensity(node)
		has_changed = true

	var has_moved = false 
	if -node.global_basis.z != direction_last_frame:
		direction_last_frame = -node.global_basis.z
		primary_data.update_direction(node)
		has_changed = true
		has_moved = true

	if node.directional_shadow_max_distance != shadow_max_distance_last_frame:
		shadow_max_distance_last_frame = node.directional_shadow_max_distance
		primary_data.update_max_shadow_distance(node)
		has_shadow_changed = true

	if has_changed:
		primary_data.update_light_buffer_bytes()

	var current_cam : ORC_DeferredGD_CameraData = ORC_RendererBase.get_instance().current_cam_data
	if has_shadow_changed || has_moved || current_cam != null && current_cam.proxy_object.has_cam_changed:
		primary_data.update_shadow_data(node, current_cam)
