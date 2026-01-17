extends ORC_DeferredGDRendererPass
class_name ORC_DeferredGDShadowPass

var shadow_framebuffers : Dictionary[StringName, RID]

var vf_static : int
var vf_skeletal : int
var static_flag_mask : int
var skeletal_flag_mask : int

func setup_override() -> void:
	super()

	var vf_info : ORC_VertexFormatInfo = ORC_VertexFormatInfo.new()
	vf_static = ORC_RDHelper.create_vertex_format(vf_info)
	vf_info.has_bones = true
	vf_info.has_weights = true
	vf_skeletal = ORC_RDHelper.create_vertex_format(vf_info)

	static_flag_mask = deferred_gd_renderer.scene_proxy.get_mask_from_flags([])
	skeletal_flag_mask = deferred_gd_renderer.scene_proxy.get_mask_from_flags(["SKELETAL"])

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
	var matrices_uniform : RDUniform = RDUniform.new()
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffer)

	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data
	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH])

func omni_draw_pass(light_data : ORC_DeferredGD_OmniLightData) -> void:
	var matrices_uniform : RDUniform = RDUniform.new()
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH])

	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data
	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH])

	matrices_uniform = RDUniform.new()		# TODO we need to clean those RDUniforms
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH])

	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH])

	matrices_uniform = RDUniform.new()		# TODO we need to clean those RDUniforms
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH])

	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH])

	matrices_uniform = RDUniform.new()		# TODO we need to clean those RDUniforms
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH])

	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH])

	matrices_uniform = RDUniform.new()		# TODO we need to clean those RDUniforms
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH])

	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH])

	matrices_uniform = RDUniform.new()		# TODO we need to clean those RDUniforms
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH])

	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH])

func spot_draw_pass(light_data : ORC_DeferredGD_SpotLightData) -> void:
	var matrices_uniform : RDUniform = RDUniform.new()
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(light_data.shadow_matrices_uniform_buffer)

	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data
	shadow_map_draw_pass(surfaces_data, [matrices_uniform], shadow_framebuffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH])

func shadow_map_draw_pass(surfaces_data : Array[ORC_DeferredGD_SurfaceData], uniforms : Array[RDUniform], framebuffer : RID) -> void:
	var is_first_surface : bool = true
	var previous_pso : ORC_PSO = null
	var draw_list : int = -1
	
	for surface_data : ORC_DeferredGD_SurfaceData in surfaces_data:
		var is_skeletal : bool = surface_data.has_flag("SKELETAL")
		var vf : int = vf_skeletal if is_skeletal else vf_static
		var flags_mask : int = skeletal_flag_mask if is_skeletal else static_flag_mask
		var pso : ORC_PSO = (pso_factories["Shadow"] as ORC_PSOFactory).get_or_create_pso(flags_mask, vf)
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

	# TODO cache skeletal GPU resources and / or clean them
		if is_skeletal:
			var skeleton_data : ORC_DeferredGD_SkeletonData = surface_data.mesh_data.skeleton_data
			var skin_data : ORC_DeferredGD_SkinData = surface_data.mesh_data.skin_data

			var bone_pose_uniform : RDUniform = RDUniform.new()
			bone_pose_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
			bone_pose_uniform.binding = 0
			bone_pose_uniform.add_id(skeleton_data.global_bone_pose_array_buffer)
			var bone_pose_uniform_set : RID = ORC_RDHelper.get_rd().uniform_set_create([bone_pose_uniform], pso.shader_program, 2)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, bone_pose_uniform_set, 2)

			var bind_pose_uniform : RDUniform = RDUniform.new()
			bind_pose_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
			bind_pose_uniform.binding = 0
			bind_pose_uniform.add_id(skin_data.invert_bind_pose_array_buffer)
			var bind_pose_uniform_set : RID = ORC_RDHelper.get_rd().uniform_set_create([bind_pose_uniform], pso.shader_program, 4)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, bind_pose_uniform_set, 4)

		
		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, surface_data.shadow_vertex_array)
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, surface_data.topology_data.index_array)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, surface_data.mesh_data.model_matrix_bytes, surface_data.mesh_data.model_matrix_bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

	# free last pso batch resources (if any)
	if is_first_surface == false:
		ORC_RDHelper.get_rd().draw_list_end()

func cleanup_override() -> void:
	super()
