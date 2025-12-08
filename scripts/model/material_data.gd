extends ORC_SecondaryData
class_name ORC_DeferredGD_MaterialData

var albedo_buffer : RID
var albedo_tex : RID 
var albedo_sampler : RID 
var normal_tex : RID
var normal_sampler : RID
var orm_tex : RID
var orm_sampler : RID 
var cull_mode : RenderingDevice.PolygonCullMode
var render_mode : ORC_PSODef.ERenderMode

func is_transparent() -> bool:
	return render_mode == ORC_PSODef.ERenderMode.Transparent_Mix or render_mode == ORC_PSODef.ERenderMode.Transparent_Add or render_mode == ORC_PSODef.ERenderMode.Transparent_Subtract or render_mode == ORC_PSODef.ERenderMode.Transparent_Multiply or render_mode == ORC_PSODef.ERenderMode.Transparent_PremultAlpha
