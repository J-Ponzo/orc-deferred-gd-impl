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
	pass

func cleanup_override() -> void:
	super_cleanup()

	ORC_RDHelper.get_rd().free_rid(albedo_map_sampler)
	ORC_RDHelper.get_rd().free_rid(normal_map_sampler)
	ORC_RDHelper.get_rd().free_rid(position_map_sampler)
	ORC_RDHelper.get_rd().free_rid(orm_map_sampler)

	ORC_ProceduralPrimitiveFactory.free_rids(screen_quad_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_sphere_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_cone_primitive)