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
		var pso : ORC_PSO = (pso_factories["Material"] as ORC_PSOFactory).get_or_create_pso_from_data(surface_data)
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

		var albedo_uniform : RDUniform = RDUniform.new()
		albedo_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
		albedo_uniform.binding = 0
		albedo_uniform.add_id(surface_data.material_data.albedo_buffer)

		var albedo_uniform_set : RID = ORC_RDHelper.get_rd().uniform_set_create([albedo_uniform], pso.shader_program, 1)

		ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, albedo_uniform_set, 1)
		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, surface_data.vertex_array)
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, surface_data.topology_data.index_array)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, surface_data.mesh_data.model_matrix_bytes, surface_data.mesh_data.model_matrix_bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

		ORC_RDHelper.get_rd().free_rid(albedo_uniform_set)

	# free last pso batch resources (if any)
	if is_first_surface == false:
		ORC_RDHelper.get_rd().draw_list_end()
		ORC_RDHelper.get_rd().free_rid(matrices_uniform_set)
