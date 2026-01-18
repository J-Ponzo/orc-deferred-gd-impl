extends ORC_PrimaryData
class_name ORC_DeferredGD_CameraData

var view_transform : Transform3D
var view_matrix_bytes : PackedByteArray
var projection_matrix_bytes : PackedByteArray

var matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()
