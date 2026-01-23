extends ORC_DeferredGD_LightProxy
class_name ORC_DeferredGD_DirectionalLightProxy

var color_last_frame : Color
var intensity_last_frame : float
var direction_last_frame : Vector3
var shadow_max_distance_last_frame : float

# TODO : try to factorise this and initialisation in proxy factory
func update_override() -> void:
	super()

	var has_changed = false 
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

	var has_moved = false 
	if -node.global_basis.z != direction_last_frame:
		primary_data.direction = -node.global_basis.z
		direction_last_frame = -node.global_basis.z
		primary_data.light_params_buffer_floats[0] = primary_data.direction.x
		primary_data.light_params_buffer_floats[1] = primary_data.direction.y
		primary_data.light_params_buffer_floats[2] = primary_data.direction.z
		has_changed = true
		has_moved = true

	if node.directional_shadow_max_distance != shadow_max_distance_last_frame:
		primary_data.shadow_max_distance = node.directional_shadow_max_distance
		shadow_max_distance_last_frame = node.directional_shadow_max_distance
		has_shadow_changed = true

	# TODO handle light_buffer_bytes values directly to improve performance
	if has_changed:
		primary_data.light_buffer_bytes = primary_data.light_params_buffer_floats.to_byte_array()

	var deferred_gd_renderer : ORC_DeferredGDRenderer = ORC_RendererBase.get_instance() as ORC_DeferredGDRenderer
	var current_cam : ORC_DeferredGD_CameraData = deferred_gd_renderer.current_cam_data

	if has_shadow_changed || has_moved || current_cam.proxy_object.changed_last_frame:
		var light_proj : Projection
		var light_view : Projection

		if current_cam != null:
			var corners : Array = get_max_dist_based_corners(current_cam.proxy_object.node, primary_data.shadow_max_distance)
			var light_view_transform : Transform3D = construct_directional_view_transform(corners, primary_data.direction)
			light_view = Projection(light_view_transform)
			light_proj = construct_directional_proj(corners, light_view_transform)
			primary_data.faked_light_position = dirty_fake_position_return
			primary_data.faked_light_range = dirty_fake_range_return
			print(dirty_fake_position_return, dirty_fake_range_return)

		var bytes : PackedByteArray = ORC_RDHelper.proj_to_bytes(Projection(light_view))
		bytes.append_array(ORC_RDHelper.proj_to_bytes(light_proj))
		primary_data.shadow_matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

static func get_camera_frustum_corners(cam: Camera3D) -> Array[Vector3]:
	var near = cam.near
	var far = cam.far
	var fov = deg_to_rad(cam.fov)
	# # TODO replace those hard coded values
	# var width : float = 1152
	# var height : float = 648
	# var aspect = width / height 
	var aspect = cam.get_viewport().get_visible_rect().size.x / cam.get_viewport().get_visible_rect().size.y


	var h_near = tan(fov * 0.5) * near
	var w_near = h_near * aspect
	var h_far = tan(fov * 0.5) * far
	var w_far = h_far * aspect

	var forward = -cam.global_transform.basis.z
	var right   = cam.global_transform.basis.x
	var up      = cam.global_transform.basis.y
	var pos     = cam.global_transform.origin

	var center_near = pos + forward * near
	var center_far  = pos + forward * far

	var corners: Array[Vector3] = []
	# Near plane
	corners.append(center_near + up  *h_near - right *w_near)
	corners.append(center_near + up * h_near + right * w_near)
	corners.append(center_near - up * h_near - right * w_near)
	corners.append(center_near - up * h_near + right * w_near)
	# Far plane
	corners.append(center_far + up * h_far - right * w_far)
	corners.append(center_far + up * h_far + right * w_far)
	corners.append(center_far - up * h_far - right * w_far)
	corners.append(center_far - up * h_far + right * w_far)

	return corners

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

const DIRECTONAL_DRAWPASS_MARGIN_PERCENT = 0.0

static var dirty_fake_position_return : Vector3
static var dirty_fake_range_return : float
static func construct_directional_view_transform(frustum_corners : Array[Vector3], diretional_light_direction : Vector3) -> Transform3D:
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

	var dx : float = (max_x - min_x) * DIRECTONAL_DRAWPASS_MARGIN_PERCENT
	var dy : float = (max_y - min_y) * DIRECTONAL_DRAWPASS_MARGIN_PERCENT
	var dz : float = (max_z - min_z) * DIRECTONAL_DRAWPASS_MARGIN_PERCENT
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

	dirty_fake_position_return = world_center
	dirty_fake_range_return = max_z - min_z;

	return light_view

static func construct_directional_proj(frustum_corners : Array[Vector3], light_view_transform : Transform3D) -> Projection:
	var min_x : float = INF; var min_y : float = INF; var min_z : float = INF
	var max_x : float = -INF; var max_y : float = -INF; var max_z : float = -INF
	for c : Vector3 in frustum_corners:
		var v : Vector3 = light_view_transform * c
		min_x = min(min_x, v.x); max_x = max(max_x, v.x)
		min_y = min(min_y, v.y); max_y = max(max_y, v.y)
		min_z = min(min_z, v.z); max_z = max(max_z, v.z)

	var dx : float = (max_x - min_x) * DIRECTONAL_DRAWPASS_MARGIN_PERCENT
	var dy : float = (max_y - min_y) * DIRECTONAL_DRAWPASS_MARGIN_PERCENT
	var dz : float = (max_z - min_z) * DIRECTONAL_DRAWPASS_MARGIN_PERCENT
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
