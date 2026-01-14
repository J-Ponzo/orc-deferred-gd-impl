extends ORC_ProxyObject
class_name ORC_DeferredGD_OmniLightProxy

var color_last_frame : Color
var intensity_last_frame : float
var location_last_frame : Vector3
var range_last_frame : float
var attenuation_last_frame : float

func update_override() -> void:
	var has_changed = false 
	if node.global_position != location_last_frame:
		primary_data.location = node.global_position
		location_last_frame = node.global_position
		primary_data.light_params_buffer_floats[0] = primary_data.location.x
		primary_data.light_params_buffer_floats[1] = primary_data.location.y
		primary_data.light_params_buffer_floats[2] = primary_data.location.z
		has_changed = true

	if node.omni_range != range_last_frame:
		primary_data.range = node.omni_range
		range_last_frame = node.omni_range
		primary_data.light_params_buffer_floats[7] = primary_data.range
		has_changed = true

	if has_changed:
		var global_transform : Transform3D
		var basis : Basis
		basis = basis.scaled(Vector3(primary_data.range, primary_data.range, primary_data.range))
		global_transform.basis = basis
		global_transform.origin = primary_data.location
		primary_data.model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(global_transform))

	if node.light_color != color_last_frame:
		primary_data.color = node.light_color
		color_last_frame = node.light_color
		var linear_color : Color = primary_data.color.srgb_to_linear()
		primary_data.light_params_buffer_floats[4] = linear_color.r
		primary_data.light_params_buffer_floats[5] = linear_color.g
		primary_data.light_params_buffer_floats[6] = linear_color.b
		has_changed = true

	if node.light_energy != intensity_last_frame:
		primary_data.intensity = node.light_energy
		intensity_last_frame = node.light_energy
		primary_data.light_params_buffer_floats[3] = primary_data.intensity
		has_changed = true

	if node.omni_attenuation != attenuation_last_frame:
		primary_data.attenuation = node.omni_attenuation
		attenuation_last_frame = node.omni_attenuation
		primary_data.light_params_buffer_floats[11] = primary_data.attenuation
		has_changed = true

	# TODO handle light_buffer_bytes values directly to improve performance
	if has_changed:
		primary_data.light_buffer_bytes = primary_data.light_params_buffer_floats.to_byte_array()