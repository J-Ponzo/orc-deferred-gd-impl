extends ORC_PrimaryData
class_name ORC_DeferredGD_LightData

var shadow_enabled : bool
# TODO handle light_buffer_bytes values directly to improve performance
var light_params_buffer_floats : PackedFloat32Array
var light_buffer_bytes : PackedByteArray