extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_DirectionalLightData

static func get_max_dist_based_corners(cam: Camera3D, max_dist : float) -> Array[Vector3]:
	var near = cam.global_position + cam.global_basis.z * max_dist
	var far = cam.global_position - cam.global_basis.z * max_dist
	var left = cam.global_position - cam.global_basis.x * max_dist
	var right = cam.global_position + cam.global_basis.x * max_dist
	var up = cam.global_position - cam.global_basis.y * max_dist
	var down = cam.global_position + cam.global_basis.y * max_dist

	var corners: Array[Vector3] = []
	corners.append(near)
	corners.append(far)
	corners.append(left)
	corners.append(right)
	corners.append(up)
	corners.append(down)

	return corners

var color : Color
var intensity : float
var direction : Vector3
var shadow_max_distance : float
var view_box_margin_percent : float = 0.0

var shadow_matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()
var faked_light_range : float       # to compute shadows
var faked_light_position : Vector3  # to compute shadows

func get_shadow_framebuffer_name() -> StringName:
	return ORC_DeferredGD_LightData._get_shadow_framebuffer_name(0, shadow_resolution)

func update_direction(directional_light_node : DirectionalLight3D) -> void:
	direction = -directional_light_node.global_basis.z
	light_params_buffer_floats[0] = direction.x
	light_params_buffer_floats[1] = direction.y
	light_params_buffer_floats[2] = direction.z

func update_intensity(directional_light_node : DirectionalLight3D) -> void:
	intensity = directional_light_node.light_energy
	light_params_buffer_floats[3] = intensity

func update_color(directional_light_node : DirectionalLight3D) -> void:
	color = directional_light_node.light_color
	var linear_color : Color = color.srgb_to_linear()
	light_params_buffer_floats[4] = linear_color.r
	light_params_buffer_floats[5] = linear_color.g
	light_params_buffer_floats[6] = linear_color.b

func update_max_shadow_distance(directional_light_node : DirectionalLight3D) -> void:
	shadow_max_distance = directional_light_node.directional_shadow_max_distance

func update_shadow_data(directional_light_node : DirectionalLight3D, current_cam : ORC_DeferredGD_CameraData) -> void: 
	set_flag("CAST_SHADOW_DIRECTIONAL", directional_light_node.shadow_enabled)
	if !directional_light_node.shadow_enabled:
		return

	var light_proj : Projection
	var light_view : Projection
	if current_cam != null:
		var corners : Array = get_max_dist_based_corners(current_cam.proxy_object.node, shadow_max_distance)
		var light_view_transform : Transform3D = construct_directional_view_transform(corners, direction)
		light_view = Projection(light_view_transform)
		light_proj = construct_directional_proj(corners, light_view_transform)

	var bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(Projection(light_view))
	bytes.append_array(ORC_RDHelper.proj_to_bytes(light_proj))
	shadow_matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

func construct_directional_view_transform(frustum_corners : Array[Vector3], diretional_light_direction : Vector3) -> Transform3D:
	var z_axis : Vector3 = -diretional_light_direction
	var tmp_up = Vector3.UP
	if abs(z_axis.dot(tmp_up)) > 0.99:
		tmp_up = Vector3.RIGHT
	var x_axis : Vector3 = tmp_up.cross(z_axis).normalized()
	var y_axis : Vector3 = z_axis.cross(x_axis).normalized()
	var light_basis : Basis = Basis(x_axis, y_axis, z_axis)     # x,y,z columns

	var light_transform_tmp : Transform3D = Transform3D(light_basis, Vector3.ZERO)
	var light_view_tmp : Transform3D = light_transform_tmp.affine_inverse()

	
	var min_x : float = INF; var min_y : float = INF; var min_z : float = INF
	var max_x : float = -INF; var max_y : float = -INF; var max_z : float = -INF
	for c : Vector3 in frustum_corners:
		var v : Vector3 = light_view_tmp * c
		min_x = min(min_x, v.x); max_x = max(max_x, v.x)
		min_y = min(min_y, v.y); max_y = max(max_y, v.y)
		min_z = min(min_z, v.z); max_z = max(max_z, v.z)

	var dx : float = (max_x - min_x) * view_box_margin_percent
	var dy : float = (max_y - min_y) * view_box_margin_percent
	var dz : float = (max_z - min_z) * view_box_margin_percent
	min_x -= dx
	max_x += dx
	min_y -= dy
	max_y += dy
	min_z -= dz
	max_z += dz

	var center_ls : Vector3 = Vector3((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, max_z)
	var world_center : Vector3 = light_transform_tmp * center_ls

	var light_transform : Transform3D = Transform3D(light_basis, world_center)
	var light_view : Transform3D = light_transform.affine_inverse()

	faked_light_position = world_center
	faked_light_range = max_z - min_z;

	return light_view

func construct_directional_proj(frustum_corners : Array[Vector3], light_view_transform : Transform3D) -> Projection:
	var min_x : float = INF; var min_y : float = INF; var min_z : float = INF
	var max_x : float = -INF; var max_y : float = -INF; var max_z : float = -INF
	for c : Vector3 in frustum_corners:
		var v : Vector3 = light_view_transform * c
		min_x = min(min_x, v.x); max_x = max(max_x, v.x)
		min_y = min(min_y, v.y); max_y = max(max_y, v.y)
		min_z = min(min_z, v.z); max_z = max(max_z, v.z)

	var dx : float = (max_x - min_x) * view_box_margin_percent
	var dy : float = (max_y - min_y) * view_box_margin_percent
	var dz : float = (max_z - min_z) * view_box_margin_percent
	min_x -= dx
	max_x += dx
	min_y -= dy
	max_y += dy
	min_z -= dz
	max_z += dz

	if min_z < 0.0:
		var shift : float = -min_z
		min_z += shift
		max_z += shift

	var light_proj : Projection = Projection.create_orthogonal(min_x, max_x, min_y, max_y, -max_z, max_z)
	return light_proj	

func initialize_all(directional_light_node : DirectionalLight3D) -> void:
	light_params_buffer_floats.resize(8)
	update_direction(directional_light_node)
	update_intensity(directional_light_node)
	update_color(directional_light_node)
	update_max_shadow_distance(directional_light_node)
	update_shadow_data(directional_light_node, null)

	update_light_buffer_bytes()