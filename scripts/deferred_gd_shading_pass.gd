extends ORC_RenderPassBase
class_name ORC_DeferredGDShadingPass

var screen_quad_primitive : ORC_ProceduralPrimitive
var invert_sphere_primitive : ORC_ProceduralPrimitive
var invert_cone_primitive : ORC_ProceduralPrimitive

func setup_override() -> void:
	super_setup()

	screen_quad_primitive = ORC_ProceduralPrimitiveFactory.create_screen_quad()
	invert_sphere_primitive = ORC_ProceduralPrimitiveFactory.create_inverted_sphere()
	invert_cone_primitive = ORC_ProceduralPrimitiveFactory.create_inverted_cone()

func render_override() -> void:
	ORC_ProceduralPrimitiveFactory.create_screen_quad()
	ORC_ProceduralPrimitiveFactory.create_inverted_sphere()
	ORC_ProceduralPrimitiveFactory.create_inverted_cone()

func cleanup_override() -> void:
	super_cleanup()

	ORC_ProceduralPrimitiveFactory.free_rids(screen_quad_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_sphere_primitive)
	ORC_ProceduralPrimitiveFactory.free_rids(invert_cone_primitive)