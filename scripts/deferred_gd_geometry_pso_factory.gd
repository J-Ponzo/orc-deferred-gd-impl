extends ORC_PSOFactory

func create_pso_from_data_override(proxy_data : ORC_ProxyData, vertex_src : String, fragment_src : String) -> ORC_PSO:
	var surface_data : ORC_DeferredGD_SurfaceData = proxy_data as ORC_DeferredGD_SurfaceData
	
	var pso_def : ORC_PSODef = ORC_PSODef.new()
	pso_def.fragment_shader_raw_src = fragment_src
	pso_def.vertex_shader_raw_src = vertex_src
	
	pso_def.vertex_format_def = surface_data.vf_def

	pso_def.depth_stencil_state = ORC_PSODepthStencilDef.new()
	pso_def.depth_stencil_state.enable_depth_test = true
	pso_def.depth_stencil_state.enable_depth_write = true
	pso_def.depth_stencil_state.depth_compare_operator = RenderingDevice.CompareOperator.COMPARE_OP_LESS

	for i in range(4):
		var blend_attachment_def : ORC_PSOColorBlendAttachmentDef = ORC_PSOColorBlendAttachmentDef.new()
		pso_def.blend_attachments.append(blend_attachment_def)
	
	var pso : ORC_PSO = ORC_RendererFactory.create_pso(pso_def, self.render_pass.framebuffer_format)
	return pso
