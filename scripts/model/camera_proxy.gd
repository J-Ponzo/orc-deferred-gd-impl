extends ORC_ProxyObject
class_name ORC_DeferredGD_CameraProxy

var cam_transform_last_frame : Transform3D
var cam_proj_last_frame : Projection

var has_cam_changed = false 

func update_override() -> void:
	has_cam_changed = false
	if cam_transform_last_frame != node.get_camera_transform():
		cam_transform_last_frame = node.get_camera_transform()
		primary_data.update_view_matrix(node)
		has_cam_changed = true

	if cam_proj_last_frame != node.get_camera_projection():
		cam_proj_last_frame = node.get_camera_projection()
		primary_data.update_projection_matrix(node)
		has_cam_changed = true

	if has_cam_changed:
		primary_data.update_matrices_uniform_buffer()
