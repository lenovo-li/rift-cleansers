shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// 实体特效网格（飞刀、巨剑、陨石、冰枪、冰刺、烟团）：顶点色 × tint + 边缘自发光。
// 顶点色里偏红偏暖的面（陨石熔岩）额外发光；fade 控制整体透明度（淡入淡出）。

instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float fade = 1.0;
instance uniform float glow = 0.6;
uniform float rim_power = 2.5;

void fragment() {
	vec3 base = COLOR.rgb * tint.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float hot = clamp((COLOR.r - COLOR.b) * 1.6 - 0.4, 0.0, 1.0);
	ALBEDO = base;
	ROUGHNESS = 0.35;
	METALLIC = 0.2;
	EMISSION = base * (rim * glow * 2.0 + hot * 3.0) + tint.rgb * glow * 0.25;
	ALPHA = clamp(fade * tint.a, 0.0, 1.0);
}
