shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// 地面图案（Blender 渲染的白色透明底贴图：符文法阵、地裂）：按 tint 上色，pulse 控制呼吸闪烁。
// 旋转由节点完成，这里只负责颜色和透明度。

instance uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.4, 1.0);
instance uniform float fade = 1.0;
instance uniform float pulse = 0.0;
uniform sampler2D mask_tex : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	float m = texture(mask_tex, UV).a;
	float breathe = 1.0 - pulse * (0.5 + 0.5 * sin(TIME * 9.0));
	// 中心略亮，边缘稍暗，看起来像从地面透出来的光
	float glow = 1.0 - 0.35 * length(UV - vec2(0.5)) * 2.0;
	ALBEDO = tint.rgb * 2.0;
	ALPHA = clamp(m * glow * breathe * fade * tint.a, 0.0, 1.0);
}
