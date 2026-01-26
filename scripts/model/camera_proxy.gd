extends ORC_ProxyObject
class_name ORC_DeferredGD_CameraProxy

var cam_transform_last_frame : Transform3D
var cam_proj_last_frame : Projection

var has_cam_changed = false 

func update_override() -> void:
	var cam_transform : Transform3D = node.get_camera_transform()
	var cam_proj : Projection = node.get_camera_projection()
	
	has_cam_changed = false
	if cam_transform_last_frame != cam_transform:
		primary_data.view_transform = cam_transform.affine_inverse()
		primary_data.view_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(primary_data.view_transform))
		cam_transform_last_frame = cam_transform
		has_cam_changed = true

	if cam_proj_last_frame != cam_proj:
		primary_data.projection_matrix_bytes = ORC_RDHelper.proj_to_bytes(cam_proj.flipped_y())
		cam_proj_last_frame = cam_proj
		has_cam_changed = true

	if has_cam_changed:
		var bytes = primary_data.view_matrix_bytes
		bytes.append_array(primary_data.projection_matrix_bytes)
		primary_data.matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)
