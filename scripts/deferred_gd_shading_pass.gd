extends ORC_DeferredGDRendererPass
class_name ORC_DeferredGDShadingPass

var vf_2d : int
var vf_3d : int
var screen_quad_primitive : ORC_ProceduralPrimitive
var invert_sphere_primitive : ORC_ProceduralPrimitive
var invert_cone_primitive : ORC_ProceduralPrimitive

# TODO : propagate to all files the direct initialization of SafeRID members
var albedo_map_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var normal_map_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var position_map_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var orm_map_sampler : ORC_SamplerRID = ORC_SamplerRID.new()

var vert_uniform_set : ORC_SetRID = ORC_SetRID.new()
var frag_uniform_set : ORC_SetRID = ORC_SetRID.new()
var global_uniform_buffer : ORC_BufferRID = ORC_BufferRID.new()

var light_matrice_uniform_set : ORC_SetRID = ORC_SetRID.new()

var shadow_framebuffers : Dictionary[StringName, RID] 

var matrices_uniform_set : ORC_SetRID = ORC_SetRID.new()
var bone_pose_uniform_set : ORC_SetRID = ORC_SetRID.new()
var bind_pose_uniform_set : ORC_SetRID = ORC_SetRID.new()

var vf_static : int
var vf_skeletal : int
var static_flag_mask : int
var skeletal_flag_mask : int
# TODO : Check the design chose of single framebuffer format per pass
var shadow_framebuffer_format : int 

var vert_uniforms : Array[RDUniform]
var frag_uniforms : Array[RDUniform]

var shadow_cubemap_sampler : ORC_SamplerRID = ORC_SamplerRID.new()
var shadow_cubemap_texture : ORC_TextureRID = ORC_TextureRID.new()	# TODO : Check why it s not an attachment
var face_views : Array[RID] = []	# TODO : Check what type it is
var face_framebuffers : Array[RID] = []

var linear_uniform_set : ORC_SetRID = ORC_SetRID.new()

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

	albedo_map_sampler.rid = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	normal_map_sampler.rid = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	position_map_sampler.rid = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	orm_map_sampler.rid = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())

	matrices_uniform_set = ORC_SetRID.new()
	bone_pose_uniform_set = ORC_SetRID.new()
	bind_pose_uniform_set = ORC_SetRID.new()

	vf_info = ORC_VertexFormatInfo.new()
	vf_static = ORC_RDHelper.create_vertex_format(vf_info)
	vf_info.has_bones = true
	vf_info.has_weights = true
	vf_skeletal = ORC_RDHelper.create_vertex_format(vf_info)

	static_flag_mask = deferred_gd_renderer.scene_proxy.get_mask_from_flags([])
	skeletal_flag_mask = deferred_gd_renderer.scene_proxy.get_mask_from_flags(["SKELETAL"])

	setup_shadow_cubemap_resources()

# TODO : why not seting things up in a data driven way ? 
func setup_shadow_cubemap_resources() -> void:
	shadow_cubemap_sampler.rid = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())

	var format := RDTextureFormat.new()
	format.width = 4096
	format.height = 4096
	format.texture_type = RenderingDevice.TEXTURE_TYPE_CUBE
	format.array_layers = 6
	format.format = RenderingDevice.DATA_FORMAT_D32_SFLOAT
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)
	shadow_cubemap_texture.rid = ORC_RDHelper.get_rd().texture_create(format, RDTextureView.new())

	var shadow_attachment_format : RDAttachmentFormat = ORC_RendererFactory.create_attachment_format(deferred_gd_renderer.shadow_attach_def)
	shadow_framebuffer_format = ORC_RDHelper.get_rd().framebuffer_format_create([shadow_attachment_format])

	for face_idx in range(6):
		var face_view := RDTextureView.new()
		var slice_rid : RID = ORC_RDHelper.get_rd().texture_create_shared_from_slice(face_view, shadow_cubemap_texture.rid, face_idx, 0)
		face_views.append(slice_rid)

		var fb : RID = ORC_RDHelper.get_rd().framebuffer_create([slice_rid], shadow_framebuffer_format)		# TODO : check if this method is better than the used one with fb_format
		face_framebuffers.append(fb)

func create_shadow_framebuffer(attach_name : StringName) -> void:
	var shadow_attachments : Array[RID] = [deferred_gd_renderer.get_attachment(attach_name)]
	shadow_framebuffers[attach_name] = ORC_RDHelper.get_rd().framebuffer_create(shadow_attachments, shadow_framebuffer_format)

# TODO : Optimize and try to provide helpers / boiler plate for common patterns (pso batching, resource reuseage etc...)
# Other passes are also candidates for this refactor
func render_override() -> void:
	var cam_matrices_uniform : RDUniform= RDUniform.new()
	cam_matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	cam_matrices_uniform.binding = 0
	cam_matrices_uniform.add_id(deferred_gd_renderer.current_cam_data.matrices_uniform_buffer.rid)

	var cam_world_pos : Vector3 = deferred_gd_renderer.current_cam_data.view_transform.affine_inverse().origin
	var cam_pos_floats_array : PackedFloat32Array = [cam_world_pos.x, cam_world_pos.y, cam_world_pos.z, 1.0]
	var bytes : PackedByteArray = cam_pos_floats_array.to_byte_array()

	var window_size : Vector2i = DisplayServer.window_get_size()
	var float_array : PackedFloat32Array = PackedFloat32Array([window_size.x as float, window_size.y as float, 0.0, 0.0])
	bytes.append_array(float_array.to_byte_array())

	global_uniform_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)
	var global_uniform : RDUniform= RDUniform.new()
	global_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	global_uniform.binding = 0
	global_uniform.add_id(global_uniform_buffer.rid)

	var albedo_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Albedo"), albedo_map_sampler.rid, 1)
	var normal_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Normal"), normal_map_sampler.rid, 2)
	var position_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("Position"), position_map_sampler.rid, 3)
	var orm_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(deferred_gd_renderer.get_attachment("ORM"), orm_map_sampler.rid, 4)

	vert_uniforms = [cam_matrices_uniform]
	frag_uniforms = [global_uniform, albedo_uniform, normal_uniform, position_uniform, orm_uniform]

	is_first_light = true

	draw_all_no_shadow_lights()

	for light_data : ORC_DeferredGD_LightData in deferred_gd_renderer.shadow_light_data:
		single_shadow_map_draw_pass(light_data)
		single_shadow_light_render_call(light_data)

var is_first_light : bool
func draw_all_no_shadow_lights() -> void:
	var previous_pso : ORC_PSO = null
	var draw_list : int = -1

	for light_data : ORC_DeferredGD_LightData in deferred_gd_renderer.no_shadow_light_data:
		var vf : int = vf_2d if light_data.has_flag("DIRECTIONAL") else vf_3d
		var pso : ORC_PSO = (pso_factories["Light"] as ORC_PSOFactory).get_or_create_pso(light_data.get_flags_mask(), vf)
		if pso != previous_pso:
			previous_pso = pso
			if draw_list != -1:
				ORC_RDHelper.get_rd().draw_list_end()


			vert_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create(vert_uniforms, pso.shader_program, 1)
			frag_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create(frag_uniforms, pso.shader_program, 0)
			var clear_colors : Array[Color] = [Color(0.0, 0.0, 0.0, 1.0)]
			var draw_flags : int = RenderingDevice.DRAW_CLEAR_ALL if is_first_light else RenderingDevice.DRAW_IGNORE_ALL
			is_first_light = false
			draw_list = ORC_RDHelper.get_rd().draw_list_begin(get_framebuffer("Main"), draw_flags, clear_colors)
			
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, vert_uniform_set.rid, 1)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, frag_uniform_set.rid, 0)
			ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, pso.pipeline)

		var primitive : ORC_ProceduralPrimitive = screen_quad_primitive
		if light_data is ORC_DeferredGD_OmniLightData:
			primitive = invert_sphere_primitive
		elif light_data is ORC_DeferredGD_SpotLightData:
			primitive = invert_cone_primitive

		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, primitive.get_vertex_array())
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, primitive.get_index_array())

		var bytes : PackedByteArray = PackedByteArray()
		if !light_data is ORC_DeferredGD_DirectionalLightData:
			bytes.append_array(light_data.model_matrix_bytes)
		bytes.append_array(light_data.light_buffer_bytes)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, bytes, bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

	# free last pso batch resources (if any)
	if is_first_light == false:
		ORC_RDHelper.get_rd().draw_list_end()

func single_shadow_light_render_call(light_data : ORC_DeferredGD_LightData) -> void:
	var light_matrices_buffer : ORC_BufferRID 
	var light_primitive : ORC_ProceduralPrimitive
	var is_directional : bool = false
	if light_data.has_flag("DIRECTIONAL"):
		light_primitive = screen_quad_primitive
		light_matrices_buffer = (light_data as ORC_DeferredGD_DirectionalLightData).shadow_matrices_uniform_buffer
		is_directional = true
	elif light_data.has_flag("OMNI"):
		light_primitive = invert_sphere_primitive
		light_matrices_buffer = (light_data as ORC_DeferredGD_OmniLightData).packed_shadow_matrices_uniform_buffer
	elif light_data.has_flag("SPOT"):
		light_primitive = invert_cone_primitive
		light_matrices_buffer = (light_data as ORC_DeferredGD_SpotLightData).shadow_matrices_uniform_buffer

	var shadow_cubemap_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(shadow_cubemap_texture.rid, shadow_cubemap_sampler.rid, 5)
	var frag_uniforms_with_shadow_maps : Array[RDUniform]
	frag_uniforms_with_shadow_maps.append_array(frag_uniforms)
	frag_uniforms_with_shadow_maps.append(shadow_cubemap_uniform)

	var light_matrices_uniform : RDUniform = RDUniform.new()
	light_matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	light_matrices_uniform.binding = 0
	light_matrices_uniform.add_id(light_matrices_buffer.rid)

	shadow_light_draw_call(light_data, frag_uniforms_with_shadow_maps, light_matrices_uniform, get_framebuffer("Main"), light_primitive, is_directional)

func shadow_light_draw_call(light_data : ORC_DeferredGD_LightData, frag_uniforms_with_shadow_maps : Array[RDUniform], light_matrices_uniform : RDUniform, framebuffer : RID, primitive : ORC_ProceduralPrimitive, is_directional : bool) -> void:
	# TODO : Cache psos ?
	var vf : int = vf_2d if is_directional else vf_3d
	var pso : ORC_PSO = (pso_factories["Light"] as ORC_PSOFactory).get_or_create_pso(light_data.get_flags_mask(), vf)
	# TODO : vert_uniforms & frag_uniforms were set during render_override, need to refactor this
	vert_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create(vert_uniforms, pso.shader_program, 1)
	frag_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create(frag_uniforms_with_shadow_maps, pso.shader_program, 0)
	light_matrice_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create([light_matrices_uniform], pso.shader_program, 2)
	
	var clear_colors : Array[Color] = [Color(0.0, 0.0, 0.0, 1.0)]
	var draw_flags : int = RenderingDevice.DRAW_CLEAR_ALL if is_first_light else RenderingDevice.DRAW_IGNORE_ALL
	var draw_list : int = ORC_RDHelper.get_rd().draw_list_begin(framebuffer, draw_flags, clear_colors)
	is_first_light = false
	ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, vert_uniform_set.rid, 1)
	ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, frag_uniform_set.rid, 0)
	ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, light_matrice_uniform_set.rid, 2)
	ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, pso.pipeline)
	
	ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, primitive.get_vertex_array())
	ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, primitive.get_index_array())

	var bytes : PackedByteArray
	if !is_directional:
		bytes.append_array(light_data.model_matrix_bytes)
	bytes.append_array(light_data.light_buffer_bytes)
	if is_directional:
		var floats_buffer : PackedFloat32Array = PackedFloat32Array()
		floats_buffer.append(light_data.faked_light_position.x)
		floats_buffer.append(light_data.faked_light_position.y)
		floats_buffer.append(light_data.faked_light_position.z)
		floats_buffer.append(light_data.faked_light_range)
		bytes.append_array(floats_buffer.to_byte_array())
	ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, bytes, bytes.size())
	ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)
	ORC_RDHelper.get_rd().draw_list_end()

func single_shadow_map_draw_pass(light_data : ORC_DeferredGD_LightData) -> void:
	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data

	if light_data.has_flag("OMNI"):
		var shadow_matrices_buffer : ORC_BufferRID = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH]
		shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 0)
		shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH]
		shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 1)
		shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH]
		shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 2)
		shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH]
		shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 3)
		shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH]
		shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 4)
		shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH]
		shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 5)
	else:
		shadow_map_draw_pass(light_data, surfaces_data, light_data.shadow_matrices_uniform_buffer)

func directional_draw_pass(light_data : ORC_DeferredGD_DirectionalLightData) -> void:
	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data
	shadow_map_draw_pass(light_data, surfaces_data, light_data.shadow_matrices_uniform_buffer)

func omni_shadow_map_draw_pass(light_data : ORC_DeferredGD_OmniLightData) -> void:
	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data

	var shadow_matrices_buffer : ORC_BufferRID = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.MAIN_OR_XPlus_SHADOW_ATTACH]
	shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 0)

	shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.XMinus_SHADOW_ATTACH]
	shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 1)

	shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YPlus_SHADOW_ATTACH]
	shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 2)

	shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.YMinus_SHADOW_ATTACH]
	shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 3)

	shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZPlus_SHADOW_ATTACH]
	shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 4)

	shadow_matrices_buffer = light_data.shadow_matrices_uniform_buffers[ORC_DeferredGDRenderer.ZMinus_SHADOW_ATTACH]
	shadow_map_draw_pass(light_data, surfaces_data, shadow_matrices_buffer, 5)

func spot_shadow_map_draw_pass(light_data : ORC_DeferredGD_SpotLightData) -> void:
	var surfaces_data : Array[ORC_DeferredGD_SurfaceData] = deferred_gd_renderer.opaque_surfaces_data
	shadow_map_draw_pass(light_data, surfaces_data, light_data.shadow_matrices_uniform_buffer)

var linear_params_buffer : ORC_BufferRID = ORC_BufferRID.new()
var omni_params_uniform_set : ORC_SetRID = ORC_SetRID.new()
func shadow_map_draw_pass(light_data : ORC_DeferredGD_LightData, surfaces_data : Array[ORC_DeferredGD_SurfaceData], shadow_matrices_buffer : ORC_BufferRID, face_idx : int = 0) -> void:	
	var shadow_framebuffer : RID = face_framebuffers[face_idx]

	var matrices_uniform : RDUniform = RDUniform.new()
	matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	matrices_uniform.binding = 0
	matrices_uniform.add_id(shadow_matrices_buffer.rid)
	
	var linear_params_uniform : RDUniform = RDUniform.new()
	var floats_buffer : PackedFloat32Array = PackedFloat32Array()
	if light_data.has_flag("DIRECTIONAL"):
		var directional_light_data : ORC_DeferredGD_DirectionalLightData = light_data as ORC_DeferredGD_DirectionalLightData
		floats_buffer.append(directional_light_data.faked_light_position.x)
		floats_buffer.append(directional_light_data.faked_light_position.y)
		floats_buffer.append(directional_light_data.faked_light_position.z)
		floats_buffer.append(directional_light_data.faked_light_range)
	else:
		floats_buffer.append(light_data.location.x)
		floats_buffer.append(light_data.location.y)
		floats_buffer.append(light_data.location.z)
		floats_buffer.append(light_data.range)
	var bytes : PackedByteArray = floats_buffer.to_byte_array()
	linear_params_buffer.rid = ORC_RDHelper.get_rd().uniform_buffer_create(bytes.size(), bytes)

	linear_params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	linear_params_uniform.binding = 0
	linear_params_uniform.add_id(linear_params_buffer.rid)

	var is_first_surface : bool = true
	var previous_pso : ORC_PSO = null
	var draw_list : int = -1
	
	for surface_data : ORC_DeferredGD_SurfaceData in surfaces_data:
		var is_skeletal : bool = surface_data.has_flag("SKELETAL")
		var vf : int = vf_skeletal if is_skeletal else vf_static
		var surface_flags_mask : int = skeletal_flag_mask if is_skeletal else static_flag_mask
		var pso : ORC_PSO = (pso_factories["Shadow"] as ORC_PSOFactory).get_or_create_pso(surface_flags_mask, vf)
		if pso != previous_pso:
			previous_pso = pso
			if draw_list != -1:
				ORC_RDHelper.get_rd().draw_list_end()
			
			var draw_flags : int = RenderingDevice.DRAW_CLEAR_ALL if is_first_surface else RenderingDevice.DRAW_IGNORE_ALL
			draw_list = ORC_RDHelper.get_rd().draw_list_begin(shadow_framebuffer, draw_flags)
			
			matrices_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create([matrices_uniform], pso.shader_program, 0)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, matrices_uniform_set.rid, 0)
			
			linear_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create([linear_params_uniform], pso.shader_program, 1)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, linear_uniform_set.rid, 1)

			ORC_RDHelper.get_rd().draw_list_bind_render_pipeline(draw_list, pso.pipeline)

			is_first_surface = false	

		# TODO cache skeletal GPU resources and / or clean them
		if is_skeletal:
			var skeleton_data : ORC_DeferredGD_SkeletonData = surface_data.mesh_data.skeleton_data
			var skin_data : ORC_DeferredGD_SkinData = surface_data.mesh_data.skin_data

			var bone_pose_uniform : RDUniform = RDUniform.new()
			bone_pose_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
			bone_pose_uniform.binding = 0
			bone_pose_uniform.add_id(skeleton_data.global_bone_pose_array_buffer.rid)
			bone_pose_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create([bone_pose_uniform], pso.shader_program, 2)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, bone_pose_uniform_set.rid, 2)

			var bind_pose_uniform : RDUniform = RDUniform.new()
			bind_pose_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
			bind_pose_uniform.binding = 0
			bind_pose_uniform.add_id(skin_data.invert_bind_pose_array_buffer.rid)
			bind_pose_uniform_set.rid = ORC_RDHelper.get_rd().uniform_set_create([bind_pose_uniform], pso.shader_program, 4)
			ORC_RDHelper.get_rd().draw_list_bind_uniform_set(draw_list, bind_pose_uniform_set.rid, 4)
		
		ORC_RDHelper.get_rd().draw_list_bind_vertex_array(draw_list, surface_data.shadow_vertex_array.rid)
		ORC_RDHelper.get_rd().draw_list_bind_index_array(draw_list, surface_data.topology_data.index_array.rid)
		ORC_RDHelper.get_rd().draw_list_set_push_constant(draw_list, surface_data.mesh_data.model_matrix_bytes, surface_data.mesh_data.model_matrix_bytes.size())
		ORC_RDHelper.get_rd().draw_list_draw(draw_list, true, 1)

	# free last pso batch resources (if any)
	if is_first_surface == false:
		ORC_RDHelper.get_rd().draw_list_end()

func cleanup_override() -> void:
	super()
	ORC_ProceduralPrimitiveFactory.free_rids(screen_quad_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_sphere_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_cone_primitive)
