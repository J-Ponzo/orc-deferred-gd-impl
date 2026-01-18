extends ORC_SecondaryData
class_name ORC_DeferredGD_MaterialData

var unique_id : int

var albedo_buffer : ORC_BufferRID = ORC_BufferRID.new()
var albedo_tex : ORC_TextureRID = ORC_TextureRID.new() 
var albedo_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var normal_tex : ORC_TextureRID = ORC_TextureRID.new()
var normal_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var orm_tex : ORC_TextureRID = ORC_TextureRID.new()
var orm_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var cull_mode : RenderingDevice.PolygonCullMode
var render_mode : ORC_PSODef.ERenderMode
