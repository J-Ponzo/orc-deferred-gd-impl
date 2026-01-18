extends ORC_ProxyObject
class_name ORC_DeferredGD_SkeletonProxy

# TODO centralize this
const SIZEOF_FLOAT = 4
const SIZEOF_MAT4 = SIZEOF_FLOAT * 16

func update_override() -> void:
	var global_bone_poses : Array[Projection] = []
	global_bone_poses.resize(node.get_bone_count())
	for bone_idx in range(global_bone_poses.size()):
		var global_bone_pose : Projection = Projection(node.get_bone_global_pose(bone_idx))
		global_bone_poses[bone_idx] = global_bone_pose

	var global_bone_pose_array : PackedByteArray = ORC_RDHelper.projs_to_bytes(global_bone_poses)
	ORC_RDHelper.get_rd().buffer_update(primary_data.global_bone_pose_array_buffer.rid, 0, SIZEOF_MAT4 * global_bone_poses.size(), global_bone_pose_array)
