extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_OmniLightData

var model_matrix_bytes : PackedByteArray
var color : Color
var intensity : float
var location : Vector3
var range : float
var attenuation : float

# TODO : shadow_matrices_uniform_buffers & packed_shadow_matrices_uniform_buffer are exclty the same data but in different layouts. The former is used in shadow_pass and the later in shading_pass. This is not optimal. Refacto needed.
var shadow_matrices_uniform_buffers : Dictionary[StringName, RID]
var packed_shadow_matrices_uniform_buffer : RID  
