extends ORC_ProxyObject
class_name ORC_DeferredGD_DirectionalLightProxy

var color_last_frame : Color
var intensity_last_frame : float
var direction_last_frame : Vector3
var shadow_max_distancen_last_frame : float

func update_override() -> void:
	var has_changed = false 
	if node.light_color != color_last_frame:
		primary_data.color = node.light_color
		color_last_frame = node.light_color
		var linear_color : Color = primary_data.color
		primary_data.light_params_buffer_floats[4] = linear_color.r
		primary_data.light_params_buffer_floats[5] = linear_color.g
		primary_data.light_params_buffer_floats[6] = linear_color.b
		has_changed = true

	if node.light_energy != intensity_last_frame:
		primary_data.intensity = node.light_energy
		intensity_last_frame = node.light_energy
		primary_data.light_params_buffer_floats[3] = primary_data.intensity
		has_changed = true

	if -node.global_basis.z != direction_last_frame:
		primary_data.direction = -node.global_basis.z
		direction_last_frame = -node.global_basis.z
		primary_data.light_params_buffer_floats[0] = primary_data.direction.x
		primary_data.light_params_buffer_floats[1] = primary_data.direction.y
		primary_data.light_params_buffer_floats[2] = primary_data.direction.z
		has_changed = true

	# TODO handle light_buffer_bytes values directly to improve performance
	if has_changed:
		primary_data.light_buffer_bytes = primary_data.light_params_buffer_floats.to_byte_array()