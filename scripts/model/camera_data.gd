extends ORC_PrimaryData
class_name ORC_DeferredGD_CameraData

var view_transform : Transform3D
var view_matrix_bytes : PackedByteArray
var projection_matrix_bytes : PackedByteArray

var matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()

func update_view_matrix(cam_node : Camera3D) -> void:
    view_transform = cam_node.get_camera_transform().affine_inverse()
    view_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(view_transform))

func update_projection_matrix(cam_node : Camera3D) -> void:
    projection_matrix_bytes = ORC_RDHelper.proj_to_bytes(cam_node.get_camera_projection().flipped_y())

func update_matrices_uniform_buffer() -> void:
    var bytes = PackedByteArray()
    bytes.append_array(view_matrix_bytes)
    bytes.append_array(projection_matrix_bytes)
    matrices_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

func initialize_all(cam_node : Camera3D) -> void:
    update_view_matrix(cam_node)
    update_projection_matrix(cam_node)
    update_matrices_uniform_buffer()
