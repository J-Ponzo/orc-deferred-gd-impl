extends ORC_RenderPassBase
class_name ORC_DeferredGDGeometryPass

func setup_override() -> void:
	super_setup()
	print("ORC_DeferredGDGeometryPass.setup()")

func render_override() -> void:
	if renderer.current_cam_data == null:
		return

	var matrices_uniform : RDUniform = RDUniform.new()
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(renderer.current_cam_data.matrices_uniform_buffer)

	var is_first_surface : bool = true
	var previous_pso : ORC_PSO = null
	var draw_list : int = -1
	var matrices_uniform_set : RID = RID()

	for surface_data : ORC_DeferredGD_SurfaceData in renderer.opaque_surfaces_data:
		var pso : ORC_PSO = (pso_factories["Material"] as ORC_PSOFactory).get_or_create_pso(surface_data.get_flags_mask(), surface_data.vertex_format)
		if pso != previous_pso:
			previous_pso = pso
			if draw_list != -1:
				ORC_RDHelper.get_rd().draw_list_end()
				ORC_RDHelper.get_rd().free_rid(matrices_uniform_set)

			matrices_uniform_set = ORC_RDHelper.get_rd().uniform_set_create([matrices_uniform], pso.shader_program, 0)
			var clear_colors : Array[Color] = [Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0)]
			var draw_flags : int = RenderingDevice.DRAW_CLEAR_ALL if is_first_surface else RenderingDevice.DRAW_IGNORE_ALL
			is_first_surface = false
			draw_list = ORC_RDHelper.get_rd().draw_list_begin(framebuffer, draw_flags, clear_colors)
			
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, matrices_uniform_set, 0)
			ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, pso.pipeline)

		var material_uniforms : Array[RDUniform] = []
		var color_uniform : RDUniform = RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		color_uniform.binding = 0
		color_uniform.add_id(surface_data.material_data.albedo_buffer)
		material_uniforms.append(color_uniform)
		if surface_data.has_flag("ALBEDO_MAP"):
			var albedo_uniform : RDUniform = create_texture_sampler_uniform(surface_data.material_data.albedo_tex, surface_data.material_data.albedo_sampler, 1)
			material_uniforms.append(albedo_uniform)
		if surface_data.has_flag("NORMAL_MAP"):
			var normal_uniform : RDUniform = create_texture_sampler_uniform(surface_data.material_data.normal_tex, surface_data.material_data.normal_sampler, 2)
			material_uniforms.append(normal_uniform)
		if surface_data.has_flag("ORM_MAP"):
			var orm_uniform : RDUniform = create_texture_sampler_uniform(surface_data.material_data.orm_tex, surface_data.material_data.orm_sampler, 3)
			material_uniforms.append(orm_uniform)
		var material_uniform_set : RID = ORC_RDHelper.get_rd().uniform_set_create(material_uniforms, pso.shader_program, 1)
		ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, material_uniform_set, 1)	

		ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, material_uniform_set, 1)
		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, surface_data.vertex_array)
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, surface_data.topology_data.index_array)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, surface_data.mesh_data.model_matrix_bytes, surface_data.mesh_data.model_matrix_bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

		ORC_RDHelper.get_rd().free_rid(material_uniform_set)

	# free last pso batch resources (if any)
	if is_first_surface == false:
		ORC_RDHelper.get_rd().draw_list_end()
		ORC_RDHelper.get_rd().free_rid(matrices_uniform_set)

# TODO move to RDHelper
func create_texture_sampler_uniform(texture_rid : RID, sampler_rid : RID, binding : int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler_rid)
	uniform.add_id(texture_rid)

	return uniform

func cleanup_override() -> void:
	super_cleanup()
	print("ORC_DeferredGDGeometryPass.cleanup()")
