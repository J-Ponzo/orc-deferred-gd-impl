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
		var view : Dictionary[StringName, Projection]		# Might be better with an array. But it's more readable like this
		view[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH] = construct_omni_view_face(ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH, primary_data.location)
		view[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH] = construct_omni_view_face(ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH, primary_data.location)
		view[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH] = construct_omni_view_face(ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH, primary_data.location)
		view[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH] = construct_omni_view_face(ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH, primary_data.location)
		view[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH] = construct_omni_view_face(ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH, primary_data.location)
		view[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH] = construct_omni_view_face(ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH, primary_data.location)

		var fov: float = 90.0
		var aspect: float = 1.0
		var near: float = 0.01
		var far: float = primary_data.range
		var proj : Projection = Projection.create_perspective(fov, aspect, near, far)

		# X+
		var proj_bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(proj)
		var bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH])
		bytes.append_array(proj_bytes)
		primary_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH] = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# X-
		bytes = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH])
		bytes.append_array(proj_bytes)
		primary_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH] = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# Y+
		bytes = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH])
		bytes.append_array(proj_bytes)
		primary_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH] = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# Y-
		bytes = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH])
		bytes.append_array(proj_bytes)
		primary_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH] = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# Z+
		bytes = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH])
		bytes.append_array(proj_bytes)
		primary_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH] = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# Z-
		bytes = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH])
		bytes.append_array(proj_bytes)
		primary_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH] = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

		# All matrices for shading pass
		bytes = ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH])
		bytes.append_array(ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH]))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH]))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH]))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH]))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(view[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH]))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(proj))
		primary_data.shading_matrices_uniform_buffer = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

static var omni_view_dirs : Dictionary[StringName, Vector3] = {
	ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH : Vector3(1, 0, 0),
	ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH :  Vector3(-1, 0, 0),
	ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH :  Vector3(0, 1, 0),
	ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH :  Vector3(0, -1, 0),
	ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH :  Vector3(0, 0, 1),
	ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH :  Vector3(0, 0, -1),
}

static var omni_view_ups : Dictionary[StringName, Vector3] = {
	ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH :  Vector3(0, -1, 0),
	ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH :  Vector3(0, -1, 0),
	ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH :  Vector3(0, 0, 1),
	ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH :  Vector3(0, 0, -1),
	ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH :  Vector3(0, -1, 0),
	ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH :  Vector3(0, -1, 0),
}

static func construct_omni_view_face(face_key : StringName, omni_light_position) -> Projection:
	var look : Transform3D = Transform3D(Basis.looking_at(-omni_view_dirs[face_key], omni_view_ups[face_key]), omni_light_position)
	return Projection(look.affine_inverse())