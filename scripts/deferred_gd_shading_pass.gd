extends ORC_RenderPassBase
class_name ORC_DeferredGDShadingPass

var screen_quad_primitive : ORC_ProceduralPrimitive
var invert_sphere_primitive : ORC_ProceduralPrimitive
var invert_cone_primitive : ORC_ProceduralPrimitive

var albedo_map_sampler : RID
var normal_map_sampler : RID
var position_map_sampler : RID
var orm_map_sampler : RID

func setup_override() -> void:
	super_setup()

	screen_quad_primitive = ORC_ProceduralPrimitiveFactory.create_screen_quad()
	invert_sphere_primitive = ORC_ProceduralPrimitiveFactory.create_inverted_sphere()
	invert_cone_primitive = ORC_ProceduralPrimitiveFactory.create_inverted_cone()

	albedo_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	normal_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	position_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())
	orm_map_sampler = ORC_RDHelper.get_rd().sampler_create(ORC_RDHelper.create_sampler_state())

func render_override() -> void:
	var cam_matrices_uniform : RDUniform= RDUniform.new()
	cam_matrices_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	cam_matrices_uniform.binding = 0
	cam_matrices_uniform.add_id(renderer.gathered_cam_data.matrices_uniform_buffer)

	var cam_world_pos : Vector3 = renderer.gathered_cam_data.view_transform.affine_inverse().origin
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

	var albedo_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(renderer.get_attachment("Albedo"), albedo_map_sampler, 1)
	var normal_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(renderer.get_attachment("Normal"), normal_map_sampler, 2)
	var position_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(renderer.get_attachment("Position"), position_map_sampler, 3)
	var orm_uniform : RDUniform = ORC_RDHelper.create_texture_sampler_uniform(renderer.get_attachment("ORM"), orm_map_sampler, 4)

	var lights_data : Array[ORC_DeferredGD_LightData] = renderer.no_shadow_light_data
	var vert_uniforms : Array[RDUniform] = [cam_matrices_uniform]
	var frag_uniforms : Array[RDUniform] = [global_uniform, albedo_uniform, normal_uniform, position_uniform, orm_uniform]
	
	# TODO : Implement draw pass

func cleanup_override() -> void:
	super_cleanup()

	ORC_RDHelper.get_rd().free_rid(albedo_map_sampler)
	ORC_RDHelper.get_rd().free_rid(normal_map_sampler)
	ORC_RDHelper.get_rd().free_rid(position_map_sampler)
	ORC_RDHelper.get_rd().free_rid(orm_map_sampler)

	ORC_ProceduralPrimitiveFactory.free_rids(screen_quad_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_sphere_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_cone_primitive)
