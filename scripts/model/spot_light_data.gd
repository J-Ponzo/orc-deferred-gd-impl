extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_SpotLightData

var model_matrix_bytes : PackedByteArray
var color : Color
var intensity : float
var location : Vector3
var range : float
var attenuation : float
var direction : Vector3
var angle : float
var angle_attenuation : float

var shadow_matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()

func get_shadow_framebuffer_name() -> StringName:
	return ORC_DeferredGD_LightData._get_shadow_framebuffer_name(0, shadow_resolution)