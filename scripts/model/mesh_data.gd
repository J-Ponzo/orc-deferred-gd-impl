extends ORC_PrimaryData
class_name ORC_DeferredGD_MeshData

var is_instanced : bool
var nb_instances : int
var instance_storage_buffer : ORC_BufferRID = ORC_BufferRID.new()

var skeleton_data : ORC_DeferredGD_SkeletonData
var skin_data : ORC_DeferredGD_SkinData

var surfaces_data : Array[ORC_DeferredGD_SurfaceData]
var bounding_box : AABB
var model_matrix_bytes : PackedByteArray
