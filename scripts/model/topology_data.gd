extends ORC_SecondaryData
class_name ORC_DeferredGD_TopologyData

var unique_id : int

var instance_id : int
var surface_id : int

var index_count : int
var index_buffer : ORC_BufferRID = ORC_BufferRID.new()
var index_array : ORC_IndexArrayRID = ORC_IndexArrayRID.new()

var vertex_count : int
var position_buffer : ORC_BufferRID = ORC_BufferRID.new()
var normal_buffer : ORC_BufferRID = ORC_BufferRID.new()
var tangent_buffer : ORC_BufferRID = ORC_BufferRID.new()
var color_buffer : ORC_BufferRID = ORC_BufferRID.new()
var uv_buffer : ORC_BufferRID = ORC_BufferRID.new()
var uv2_buffer : ORC_BufferRID = ORC_BufferRID.new()
var bones_buffer : ORC_BufferRID = ORC_BufferRID.new()
var weights_buffer : ORC_BufferRID = ORC_BufferRID.new()
