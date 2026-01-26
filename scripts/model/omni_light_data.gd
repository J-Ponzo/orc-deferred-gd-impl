extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_OmniLightData

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

var model_matrix_bytes : PackedByteArray
var color : Color
var intensity : float
var location : Vector3
var range : float
var attenuation : float

var shadow_matrices_uniform_buffers : Array[ORC_BufferRID] = [
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(),
]

var packed_shadow_matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()

func get_shadow_framebuffer_name(face_idx : int) -> StringName:
	return ORC_DeferredGD_LightData._get_shadow_framebuffer_name(face_idx, shadow_resolution)

func update_location(omni_node : OmniLight3D) -> void:
	location = omni_node.global_position
	light_params_buffer_floats[0] = location.x
	light_params_buffer_floats[1] = location.y
	light_params_buffer_floats[2] = location.z

func update_range(omni_node : OmniLight3D) -> void:
	range = omni_node.omni_range
	light_params_buffer_floats[7] = range

func update_color(omni_node : OmniLight3D) -> void:
	color = omni_node.light_color
	var linear_color : Color = color.srgb_to_linear()
	light_params_buffer_floats[4] = linear_color.r
	light_params_buffer_floats[5] = linear_color.g
	light_params_buffer_floats[6] = linear_color.b

func update_intensity(omni_node : OmniLight3D) -> void:
	intensity = omni_node.light_energy
	light_params_buffer_floats[3] = intensity

func update_attenuation(omni_node : OmniLight3D) -> void:
	attenuation = omni_node.omni_attenuation
	light_params_buffer_floats[11] = attenuation

func update_model_matrix() -> void:
	var global_transform : Transform3D
	var basis : Basis
	basis = basis.scaled(Vector3(range, range, range))
	global_transform.basis = basis
	global_transform.origin = location
	model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(global_transform))

# TODO handle light_buffer_bytes values directly to improve performance
func update_light_buffer_bytes() -> void:
	light_buffer_bytes = light_params_buffer_floats.to_byte_array()

func update_shadow_data() -> void:
	# TODO compute that in model
	var view : Array[Projection]
	view.resize(6)
	for i in range(6):
		view[i] = construct_omni_view_face(i, location)

	var fov: float = 90.0
	var aspect: float = 1.0
	var near: float = 0.01
	var far: float = range
	var proj : Projection = Projection.create_perspective(fov, aspect, near, far)

	var proj_bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(proj)
	var bytes : PackedByteArray
	for i in range(6):
		bytes = ORC_RDHelper.proj_to_bytes(view[i])
		bytes.append_array(proj_bytes)
		shadow_matrices_uniform_buffers[i].rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

	# All matrices for shading pass
	bytes.clear()
	for i in range(6):
		bytes.append_array(ORC_RDHelper.proj_to_bytes(view[i]))
	bytes.append_array(ORC_RDHelper.proj_to_bytes(proj)) 
	packed_shadow_matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

func initialize_all(omni_node : OmniLight3D) -> void:
	light_params_buffer_floats.resize(12)
	update_location(omni_node)
	update_range(omni_node)
	update_color(omni_node)
	update_intensity(omni_node)
	update_attenuation(omni_node)
	update_model_matrix()
	update_light_buffer_bytes()
	update_shadow_data()
