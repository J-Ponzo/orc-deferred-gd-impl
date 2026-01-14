extends ORC_DeferredGDRendererPass
class_name ORC_DeferredGDShadingPass

var vf_2d : int
var vf_3d : int
var screen_quad_primitive : ORC_ProceduralPrimitive
var invert_sphere_primitive : ORC_ProceduralPrimitive
var invert_cone_primitive : ORC_ProceduralPrimitive

var albedo_map_sampler : RID
var normal_map_sampler : RID
var position_map_sampler : RID
var orm_map_sampler : RID

func setup_override() -> void:
	super()

	var vf_info : ORC_VertexFormatInfo = ORC_VertexFormatInfo.new()
	vf_info.is_2d = true
	vf_2d = ORC_RDHelper.create_vertex_format(vf_info)
	vf_info.is_2d = false
	vf_3d = ORC_RDHelper.create_vertex_format(vf_info)

	screen_quad_primitive = ORC_ProceduralPrimitiveFactory.create_screen_quad()
	invert_sphere_primitive = ORC_ProceduralPrimitiveFactory.create_inverted_sphere()
	invert_cone_primitive = ORC_ProceduralPrimitiveFactory.create_inverted_cone()

	albedo_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	normal_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	position_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	orm_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())

# TODO : Optimize and try to provide helpers / boiler plate for common patterns (pso batching, resource reuseage etc...)
# Other passes are also candidates for this refactor
func render_override() -> void:
	var cam_matrices_uniform : RDUniform= RDUniform.new()
	cam_matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	cam_matrices_uniform.binding = 0
	cam_matrices_uniform.add_id(deferred_gd_renderer.current_cam_data.matrices_uniform_buffer)

	var cam_world_pos : Vector3 = deferred_gd_renderer.current_cam_data.view_transform.affine_inverse().origin
	var cam_pos_floats_array : PackedFloat32Array = [cam_world_pos.x, cam_world_pos.y, cam_world_pos.z, 1.0]
	var bytes : PackedByteArray =  cam_pos_floats_array.to_byte_array()

	var width : float = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height :float = ProjectSettings.get_setting("display/window/size/viewport_height")
	var float_array : PackedFloat32Array = PackedFloat32Array([width, height, 0.0, 0.0])
	bytes.append_array(float_array.to_byte_array())

	var global_uniform_buffer : RID = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)
	var global_uniform : RDUniform= RDUniform.new()
	global_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	global_uniform.binding = 0
	global_uniform.add_id(global_uniform_buffer)

	var albedo_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Albedo"), albedo_map_sampler, 1)
	var normal_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Normal"), normal_map_sampler, 2)
	var position_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Position"), position_map_sampler, 3)
	var orm_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("ORM"), orm_map_sampler, 4)

	var vert_uniforms : Array[RDUniform] = [cam_matrices_uniform]
	var frag_uniforms : Array[RDUniform] = [global_uniform, albedo_uniform, normal_uniform, position_uniform, orm_uniform]
	
	var is_first_light : bool = true
	var previous_pso : ORC_PSO = null
	var draw_list : int = -1
	var vert_uniform_set : RID = RID()
	var frag_uniform_set : RID = RID()

	for light_data : ORC_DeferredGD_LightData in deferred_gd_renderer.no_shadow_light_data:
		var vf : int = vf_2d if light_data.has_flag("DIRECTIONAL") else vf_3d
		var pso : ORC_PSO = (pso_factories["Light"] as ORC_PSOFactory).get_or_create_pso(light_data.get_flags_mask(), vf)
		if pso != previous_pso:
			previous_pso = pso
			if draw_list != -1:
				ORC_RDHelper.get_rd().draw_list_end()
				ORC_RDHelper.get_rd().free_rid(vert_uniform_set)
				ORC_RDHelper.get_rd().free_rid(frag_uniform_set)

			vert_uniform_set = ORC_RDHelper.get_rd().uniform_set_create(vert_uniforms, pso.shader_program, 1)
			frag_uniform_set = ORC_RDHelper.get_rd().uniform_set_create(frag_uniforms, pso.shader_program, 0)
			var clear_colors : Array[Color] = [Color(0.0, 0.0, 0.0, 1.0)]
			var draw_flags : int = RenderingDevice.DRAW_CLEAR_ALL if is_first_light else RenderingDevice.DRAW_IGNORE_ALL
			draw_list = ORC_RDHelper.get_rd().draw_list_begin(framebuffer, draw_flags, clear_colors)
			
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, vert_uniform_set, 1)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, frag_uniform_set, 0)
			ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, pso.pipeline)

			is_first_light = false

		var primitive : ORC_ProceduralPrimitive = screen_quad_primitive
		if light_data is ORC_DeferredGD_OmniLightData:
			primitive = invert_sphere_primitive
		elif light_data is ORC_DeferredGD_SpotLightData:
			primitive = invert_cone_primitive

		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, primitive.get_vertex_array())
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, primitive.get_index_array())

		bytes.clear()
		if !light_data is ORC_DeferredGD_DirectionalLightData:
			bytes.append_array(light_data.model_matrix_bytes)
		bytes.append_array(light_data.light_buffer_bytes)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, bytes, bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

	# free last pso batch resources (if any)
	if is_first_light == false:
		ORC_RDHelper.get_rd().draw_list_end()

func cleanup_override() -> void:
	super()

	ORC_RDHelper.get_rd().free_rid(albedo_map_sampler)
	ORC_RDHelper.get_rd().free_rid(normal_map_sampler)
	ORC_RDHelper.get_rd().free_rid(position_map_sampler)
	ORC_RDHelper.get_rd().free_rid(orm_map_sampler)

	ORC_ProceduralPrimitiveFactory.free_rids(screen_quad_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_sphere_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_cone_primitive)
