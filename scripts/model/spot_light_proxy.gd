extends ORC_DeferredGD_LightProxy
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
	super()
	
	var has_changed = false 
	if node.global_position != location_last_frame:
		location_last_frame = node.global_position
		primary_data.update_location(node)
		has_changed = true

	if node.spot_range != range_last_frame:
		range_last_frame = node.spot_range
		primary_data.update_range(node)
		has_changed = true

	if -node.global_basis.z != direction_last_frame:
		direction_last_frame = -node.global_basis.z
		primary_data.update_direction(node)
		has_changed = true

	if node.spot_angle != angle_last_frame:
		angle_last_frame = node.spot_angle
		primary_data.update_angle(node)
		has_changed = true

	if node.light_color != color_last_frame:
		color_last_frame = node.light_color
		primary_data.update_color(node)
		has_changed = true

	if node.light_energy != intensity_last_frame:
		intensity_last_frame = node.light_energy
		primary_data.update_intensity(node)
		has_changed = true

	if node.spot_attenuation != attenuation_last_frame:
		attenuation_last_frame = node.spot_attenuation
		primary_data.update_attenuation(node)
		has_changed = true

	if node.spot_angle_attenuation != angle_attenuation_last_frame:
		angle_attenuation_last_frame = node.spot_angle_attenuation
		primary_data.update_angle_attenuation(node)
		has_changed = true

	var has_moved = false 
	if has_changed:
		primary_data.update_model_matrix(node)
		has_moved = true 

	if has_changed:
		primary_data.update_light_buffer_bytes()

	if has_shadow_changed || has_moved:
		primary_data.update_shadow_data(node)
