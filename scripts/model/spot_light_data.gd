extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_SpotLightData

var model_matrix_bytes : PackedByteArray
var color : Color
var intensity : float
var location : Vector3
var range : float
var attenuation : float
var direction : Vector3
var angle : float
var angle_attenuation : float

var shadow_matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()

func get_shadow_framebuffer_name() -> StringName:
	return ORC_DeferredGD_LightData._get_shadow_framebuffer_name(0, shadow_resolution)

func update_location(spot_node : SpotLight3D) -> void:
	location = spot_node.global_position
	light_params_buffer_floats[0] = location.x
	light_params_buffer_floats[1] = location.y
	light_params_buffer_floats[2] = location.z

func update_angle(spot_node : SpotLight3D) -> void:
	angle = deg_to_rad(spot_node.spot_angle)
	light_params_buffer_floats[3] = angle

func update_direction(spot_node : SpotLight3D) -> void:
	direction = -spot_node.global_basis.z
	light_params_buffer_floats[4] = direction.x
	light_params_buffer_floats[5] = direction.y
	light_params_buffer_floats[6] = direction.z

func update_intensity(spot_node : SpotLight3D) -> void:
	intensity = spot_node.light_energy
	light_params_buffer_floats[7] = intensity

func update_color(spot_node : SpotLight3D) -> void:
	color = spot_node.light_color
	var linear_color : Color = color.srgb_to_linear()
	light_params_buffer_floats[8] = linear_color.r
	light_params_buffer_floats[9] = linear_color.g
	light_params_buffer_floats[10] = linear_color.b

func update_angle_attenuation(spot_node : SpotLight3D) -> void:
	angle_attenuation = spot_node.spot_angle_attenuation
	light_params_buffer_floats[11] = angle_attenuation

func update_range(spot_node : SpotLight3D) -> void:
	range = spot_node.spot_range
	light_params_buffer_floats[12] = range

func update_attenuation(spot_node : SpotLight3D) -> void:
	attenuation = spot_node.spot_attenuation
	light_params_buffer_floats[13] = attenuation

func update_model_matrix(spot_node : SpotLight3D) -> void:
	var radius = range * tan(angle)
	var basis : Basis = Basis.IDENTITY
	basis.x = radius * spot_node.global_basis.x.normalized()
	basis.y = radius * spot_node.global_basis.y.normalized()
	basis.z = range * spot_node.global_basis.z.normalized()
	var global_transform : Transform3D
	global_transform.basis = basis
	global_transform.origin = location
	model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(global_transform))

func update_shadow_data(spot_node : SpotLight3D) -> void:
	set_flag("CAST_SHADOW_SPOT", spot_node.shadow_enabled)
	if !spot_node.shadow_enabled:
		return

	var view : Projection = Projection(spot_node.global_transform.affine_inverse())

	var proj : Projection = Projection()
	var fov: float = 2.0 * rad_to_deg(angle)
	var aspect: float = 1.0
	var near: float = 0.01
	var far: float = range
	proj = Projection.create_perspective(fov, aspect, near, far)

	var bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(view)
	bytes.append_array(ORC_RDHelper.proj_to_bytes(proj))
	shadow_matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

func initialize_all(spot_node : SpotLight3D) -> void:
	light_params_buffer_floats.resize(16)
	update_location(spot_node)
	update_angle(spot_node)
	update_direction(spot_node)
	update_intensity(spot_node)
	update_color(spot_node)
	update_angle_attenuation(spot_node)
	update_range(spot_node)
	update_attenuation(spot_node)
	update_model_matrix(spot_node)
	update_shadow_data(spot_node)

	update_light_buffer_bytes()
