extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_OmniLightData

var model_matrix_bytes : PackedByteArray
var color : Color
var intensity : float
var location : Vector3
var range : float
var attenuation : float

var shadow_matrices_uniform_buffers : Dictionary[StringName, RID]
var shading_matrices_uniform_buffer : RID   # TODO might be not needed
