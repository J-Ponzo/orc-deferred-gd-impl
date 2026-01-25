extends ORC_PrimaryData
class_name ORC_DeferredGD_LightData

enum EShadowResolution {
	RESOLUTION_1K,
	RESOLUTION_2K,
	RESOLUTION_4K,
	RESOLUTION_8K,
}

static func _get_shadow_resolution_affix(resolution : EShadowResolution) -> StringName:
	if resolution == EShadowResolution.RESOLUTION_1K:
		return "1K"
	elif resolution == EShadowResolution.RESOLUTION_2K:
		return "2K"
	elif resolution == EShadowResolution.RESOLUTION_4K:
		return "4K"
	elif resolution == EShadowResolution.RESOLUTION_8K:
		return "8K"
	return "UNKNOWN_RESOLUTION"

static func _get_face_idx_affix(face_idx : int) -> StringName:
	return "Face_" + str(face_idx)

static func _get_shadow_texture_name(resolution : EShadowResolution) -> StringName:
	var resolution_affix : StringName = _get_shadow_resolution_affix(resolution)
	return StringName("ShadowCubeMap_" + resolution_affix)

static func _get_shadow_framebuffer_name(face_idx : int, resolution : EShadowResolution) -> StringName:
	var resolution_affix : StringName = _get_shadow_resolution_affix(resolution)
	var face_idx_affix : StringName = _get_face_idx_affix(face_idx)
	return StringName("ShadowCubeMap_" + resolution_affix + "_" + face_idx_affix)

# TODO handle light_buffer_bytes values directly to improve performance
var light_params_buffer_floats : PackedFloat32Array
var light_buffer_bytes : PackedByteArray
var shadow_enabled : bool
var shadow_resolution : EShadowResolution = EShadowResolution.RESOLUTION_8K

func get_shadow_texture_name() -> StringName:
	return ORC_DeferredGD_LightData._get_shadow_texture_name(shadow_resolution)