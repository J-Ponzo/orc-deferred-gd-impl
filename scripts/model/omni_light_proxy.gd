extends ORC_DeferredGD_LightProxy
class_name ORC_DeferredGD_OmniLightProxy

var color_last_frame : Color
var intensity_last_frame : float
var location_last_frame : Vector3
var range_last_frame : float
var attenuation_last_frame : float

func update_override() -> void:
	super()

	var has_changed = false 
	var has_moved = false 
	if node.global_position != location_last_frame:
		primary_data.location = node.global_position
		location_last_frame = node.global_position
		primary_data.light_params_buffer_floats[0] = primary_data.location.x
		primary_data.light_params_buffer_floats[1] = primary_data.location.y
		primary_data.light_params_buffer_floats[2] = primary_data.location.z
		has_changed = true
		has_moved = true

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

	if has_shadow_changed || has_moved:
		# TODO compute that in model
		var view : Array[Projection]
		view.resize(6)		# TODO : Can we do this in 1 line initialization ?
		for i in range(6):
			view[i] = construct_omni_view_face(i, primary_data.location)

		var fov: float = 90.0
		var aspect: float = 1.0
		var near: float = 0.01
		var far: float = primary_data.range
		var proj : Projection = Projection.create_perspective(fov, aspect, near, far)

		# TODO : roll in for loop
		var proj_bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(proj)
		var bytes : PackedByteArray
		for i in range(6):
			bytes = ORC_RDHelper.proj_to_bytes(view[i])
			bytes.append_array(proj_bytes)
			primary_data.shadow_matrices_uniform_buffers[i].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# # X+
		# var proj_bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(proj)
		# var bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(view[0])
		# bytes.append_array(proj_bytes)
		# primary_data.shadow_matrices_uniform_buffers[0].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# # X-
		# bytes = ORC_RDHelper.proj_to_bytes(view[1])
		# bytes.append_array(proj_bytes)
		# primary_data.shadow_matrices_uniform_buffers[1].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# # Y+
		# bytes = ORC_RDHelper.proj_to_bytes(view[2])
		# bytes.append_array(proj_bytes)
		# primary_data.shadow_matrices_uniform_buffers[2].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# # Y-
		# bytes = ORC_RDHelper.proj_to_bytes(view[3])
		# bytes.append_array(proj_bytes)
		# primary_data.shadow_matrices_uniform_buffers[3].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# # Z+
		# bytes = ORC_RDHelper.proj_to_bytes(view[4])
		# bytes.append_array(proj_bytes)
		# primary_data.shadow_matrices_uniform_buffers[4].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# # Z-
		# bytes = ORC_RDHelper.proj_to_bytes(view[5])
		# bytes.append_array(proj_bytes)
		# primary_data.shadow_matrices_uniform_buffers[5].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# All matrices for shading pass
		bytes.clear()
		for i in range(6):
			bytes.append_array(ORC_RDHelper.proj_to_bytes(view[i]))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(proj)) 
		primary_data.packed_shadow_matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

static var omni_view_dirs : Array[Vector3] = [
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, -1, 0),
	Vector3(0, 1, 0),
	Vector3(0, 0, -1),
	Vector3(0, 0, 1),
]

static var omni_view_ups : Array[Vector3] = [
	Vector3(0, -1, 0),
	Vector3(0, -1, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
	Vector3(0, -1, 0),
	Vector3(0, -1, 0),
]

static func construct_omni_view_face(face_index : int, omni_light_position) -> Projection:
	var look : Transform3D = Transform3D(Basis.looking_at(-omni_view_dirs[face_index], omni_view_ups[face_index]), omni_light_position)
	return Projection(look.affine_inverse())
