extends ORC_DeferredGDRendererPass
class_name ORC_DeferredGDPostProcessPass

var screen_quad_primitive : ORC_ProceduralPrimitive
var shaded_map_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var global_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()
var uniform_set : ORC_SetRID = ORC_SetRID.new()

var window_size_last_frame : Vector2i = Vector2i(-1, -1)

func setup_override() -> void:
	super()
	
	screen_quad_primitive = ORC_ProceduralPrimitiveFactory.create_screen_quad()
	shaded_map_sampler.rid = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())

func render_override() -> void:
	var window_size : Vector2i = DisplayServer.window_get_size()
	if window_size != window_size_last_frame:
		var float_array : PackedFloat32Array = PackedFloat32Array([window_size.x as float, window_size.y as float, 0.0, 0.0])
		var bytes : PackedByteArray = float_array.to_byte_array()
		global_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)
		window_size_last_frame = window_size

	var shaded_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Shaded"), shaded_map_sampler.rid, 1)

	var global_uniform : RDUniform = RDUniform.new()
	global_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	global_uniform.binding = 0
	global_uniform.add_id(global_uniform_buffer.rid)

	uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create([global_uniform, shaded_uniform], direct_psos["post_process"].shader_program, 0)
	var clear_colors = [Color(0.0, 0.0, 0.0)]
	var draw_flags = RenderingDevice.DRAW_CLEAR_ALL
	var draw_list = ORC_RDHelper.get_rd().draw_list_begin(framebuffer, draw_flags, clear_colors)

	ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, uniform_set.rid, 0)
	ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, direct_psos["post_process"].pipeline)

	ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, screen_quad_primitive.get_vertex_array())
	ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, screen_quad_primitive.get_index_array())
	ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)
		
	ORC_RDHelper.get_rd().draw_list_end()

func cleanup_override() -> void:
	super()
	window_size_last_frame = Vector2i(-1, -1)
	ORC_ProceduralPrimitiveFactory.free_rids(screen_quad_primitive)
