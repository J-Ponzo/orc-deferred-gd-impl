extends ORC_ProxyObject
class_name ORC_DeferredGD_SpotLightProxy

var color_last_frame : Color
var intensity_last_frame : float
var location_last_frame : Vector3
var range_last_frame : float
var attenuation_last_frame : float
var direction_last_frame : Vector3
var angle_last_frame : float
var angle_attenuation_last_frame : float

func update_override() -> void:
	var has_changed = false 
	if node.global_position != location_last_frame:
		primary_data.location = node.global_position
		location_last_frame = node.global_position
		primary_data.light_params_buffer_floats[0] = primary_data.location.x
		primary_data.light_params_buffer_floats[1] = primary_data.location.y
		primary_data.light_params_buffer_floats[2] = primary_data.location.z
		has_changed = true

	if node.spot_range != range_last_frame:
		primary_data.range = node.spot_range
		range_last_frame = node.spot_range
		primary_data.light_params_buffer_floats[12] = primary_data.range
		has_changed = true

	if -node.global_basis.z != direction_last_frame:
		primary_data.direction = -node.global_basis.z
		direction_last_frame = -node.global_basis.z
		primary_data.light_params_buffer_floats[4] = primary_data.direction.x
		primary_data.light_params_buffer_floats[5] = primary_data.direction.y
		primary_data.light_params_buffer_floats[6] = primary_data.direction.z
		has_changed = true

	if node.spot_angle != angle_last_frame:
		primary_data.angle = deg_to_rad(node.spot_angle)
		angle_last_frame = node.spot_angle
		primary_data.light_params_buffer_floats[3] = primary_data.angle
		has_changed = true

	if has_changed:
		var radius = primary_data.range * tan(primary_data.angle)
		var basis : Basis = Basis.IDENTITY
		basis.x = radius * node.global_basis.x.normalized()
		basis.y = radius * node.global_basis.y.normalized()
		basis.z = primary_data.range * node.global_basis.z.normalized()
		var global_transform : Transform3D
		global_transform.basis = basis
		global_transform.origin = primary_data.location
		primary_data.model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(global_transform))

	if node.light_color != color_last_frame:
		primary_data.color = node.light_color
		color_last_frame = node.light_color
		var linear_color : Color = primary_data.color
		primary_data.light_params_buffer_floats[8] = linear_color.r
		primary_data.light_params_buffer_floats[9] = linear_color.g
		primary_data.light_params_buffer_floats[10] = linear_color.b
		has_changed = true

	if node.light_energy != intensity_last_frame:
		primary_data.intensity = node.light_energy
		intensity_last_frame = node.light_energy
		primary_data.light_params_buffer_floats[7] = primary_data.intensity
		has_changed = true

	if node.spot_attenuation != attenuation_last_frame:
		primary_data.attenuation = node.spot_attenuation
		attenuation_last_frame = node.spot_attenuation
		primary_data.light_params_buffer_floats[13] = primary_data.attenuation
		has_changed = true

	if node.spot_angle_attenuation != angle_attenuation_last_frame:
		primary_data.angle_attenuation = node.spot_angle_attenuation
		angle_attenuation_last_frame = node.spot_angle_attenuation
		primary_data.light_params_buffer_floats[11] = primary_data.angle_attenuation
		has_changed = true

	# TODO handle light_buffer_bytes values directly to improve performance
	if has_changed:
		primary_data.light_buffer_bytes = primary_data.light_params_buffer_floats.to_byte_array()