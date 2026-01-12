extends ORC_RenderPassBase
class_name ORC_DeferredGDShadingPass

func render_override() -> void:
    ORC_ProceduralPrimitiveFactory.create_screen_quad()