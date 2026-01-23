extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_DirectionalLightData

var color : Color
var intensity : float
var direction : Vector3
var shadow_max_distance : float

var shadow_matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()
var faked_light_range : float       # to compute shadows
var faked_light_position : Vector3  # to compute shadows