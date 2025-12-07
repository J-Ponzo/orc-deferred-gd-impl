extends ORC_ProxyObject
class_name ORC_DeferredGD_MeshProxy

var global_transform_last_frame : Transform3D

func update_override() -> void:
	if global_transform_last_frame != node.global_transform:
		primary_data.model_matrix_bytes = ORC_RDHelper.proj_to_bytes(Projection(node.global_transform))
		global_transform_last_frame = node.global_transform
