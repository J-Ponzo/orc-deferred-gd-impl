extends ORC_PSOFactory

func create_pso_override(flags_mask : int, vertex_format : int, vertex_src : String, fragment_src : String) -> ORC_PSO:
	var defines : Array[StringName] = render_pass.renderer.scene_proxy.get_flags_from_mask(flags_mask)

	var pso_info : ORC_PSOInfo = ORC_PSOInfo.new()
	pso_info.vertex_shader_src = ORC_ShaderPreprocessor.preprocess("", vertex_src, defines)
	pso_info.fragment_shader_src = ORC_ShaderPreprocessor.preprocess("", fragment_src, defines)
	pso_info.vertex_format = vertex_format

	pso_info.rasterization_state = RDPipelineRasterizationState.new()
	pso_info.multisample_state = RDPipelineMultisampleState.new()

	pso_info.depth_stencil_state = RDPipelineDepthStencilState.new()
	pso_info.depth_stencil_state.enable_depth_test = true
	pso_info.depth_stencil_state.enable_depth_write = true
	pso_info.depth_stencil_state.depth_compare_operator = RenderingDevice.CompareOperator.COMPARE_OP_LESS

	pso_info.color_blend_state = RDPipelineColorBlendState.new()
	for i in range(4):
		var blend_attachment : RDPipelineColorBlendStateAttachment = RDPipelineColorBlendStateAttachment.new()
		pso_info.color_blend_state.attachments.append(blend_attachment)

	return ORC_RDHelper.create_pso(pso_info, self.render_pass.framebuffer_format)
