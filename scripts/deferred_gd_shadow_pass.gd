extends ORC_DeferredGDRendererPass
class_name ORC_DeferredGDShadowPass

var shadow_framebuffers : Dictionary[StringName, RID]

func setup_override() -> void:
	super()

	# TODO : why not seting things up in a data driven way ? 
	var shadow_attachment_format : RDAttachmentFormat = ORC_RendererFactory.create_attachment_format(deferred_gd_renderer.shadow_attach_def)
	framebuffer_format = ORC_RDHelper.get_rd().framebuffer_format_create([shadow_attachment_format])
	create_shadow_framebuffer(ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH)
	create_shadow_framebuffer(ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH)
	create_shadow_framebuffer(ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH)
	create_shadow_framebuffer(ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH)
	create_shadow_framebuffer(ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH)
	create_shadow_framebuffer(ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH)

func create_shadow_framebuffer(attach_name : StringName) -> void:
	var shadow_attachments : Array[RID] = [deferred_gd_renderer.get_attachment(attach_name)]
	shadow_framebuffers[attach_name] = ORC_RDHelper.get_rd().framebuffer_create(shadow_attachments, framebuffer_format)

# TODO : refacto this for better framework integration and reuseage
func single_render_call(light_data : ORC_DeferredGD_LightData) -> void:
	if light_data.has_flag("DIRECTIONAL"):
		directional_draw_pass(light_data as ORC_DeferredGD_DirectionalLightData)
	elif light_data.has_flag("OMNI"):
		omni_draw_pass(light_data as ORC_DeferredGD_OmniLightData)
	elif light_data.has_flag("SPOT"):
		spot_draw_pass(light_data as ORC_DeferredGD_SpotLightData)

func directional_draw_pass(light_data : ORC_DeferredGD_DirectionalLightData) -> void:
	print("SHADOW " + light_data.proxy_object.node.name)

func omni_draw_pass(light_data : ORC_DeferredGD_OmniLightData) -> void:
	print("SHADOW " + light_data.proxy_object.node.name)

func spot_draw_pass(light_data : ORC_DeferredGD_SpotLightData) -> void:
	print("SHADOW " + light_data.proxy_object.node.name)

func shadow_map_draw_pass(surfaces_data : Array[ORC_DeferredGD_SurfaceData], uniforms : Array[RDUniform], framebuffer : RID, forced_defines : Array[StringName]) -> void:
	var is_first_surface : bool = true
	var previous_pso : ORC_PSO = null
	var draw_list : int = -1
	
	for surface_data : ORC_DeferredGD_SurfaceData in surfaces_data:
		var is_skeletal : bool = surface_data.has_flag("SKELETAL")
		var vf_info : ORC_VertexFormatInfo = ORC_VertexFormatInfo.new()
		vf_info.has_bones = is_skeletal
		vf_info.has_weights = is_skeletal
		var vf : int = ORC_RDHelper.create_vertex_format(vf_info)
		var pso : ORC_PSO = (pso_factories["Shadow"] as ORC_PSOFactory).get_or_create_pso(surface_data.get_flags_mask(), vf)
		if pso != previous_pso:
			previous_pso = pso
			if draw_list != -1:
				ORC_RDHelper.get_rd().draw_list_end()

			var uniform_set : RID = ORC_RDHelper.get_rd().uniform_set_create(uniforms, pso.shader_program, 0)
			# TODO : not sure we need 4 of this
			var clear_colors = [Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0)]
			var draw_flags : int = RenderingDevice.DRAW_CLEAR_ALL if is_first_surface else RenderingDevice.DRAW_IGNORE_ALL
			draw_list = ORC_RDHelper.get_rd().draw_list_begin(framebuffer, draw_flags, clear_colors)
			
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, uniform_set, 0)
			ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, pso.pipeline)

			is_first_surface = false	

		if is_skeletal:
			pass
			# TODO : Handle skeletals
		
		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, surface_data.vertex_array)
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, surface_data.topology_data.index_array)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, surface_data.mesh_data.model_matrix_bytes, surface_data.mesh_data.model_matrix_bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

	# free last pso batch resources (if any)
	if is_first_surface == false:
		ORC_RDHelper.get_rd().draw_list_end()

func cleanup_override() -> void:
	super()
