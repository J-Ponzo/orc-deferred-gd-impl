extends ORC_DeferredGD_LightData
class_name ORC_DeferredGD_OmniLightData

var model_matrix_bytes : PackedByteArray
var color : Color
var intensity : float
var location : Vector3
var range : float
var attenuation : float

# TODO : Can we do this in one line intitialization ?
var shadow_matrices_uniform_buffers : Array[ORC_BufferRID] = [
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(), 
	ORC_BufferRID.new(),
]

var packed_shadow_matrices_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()
