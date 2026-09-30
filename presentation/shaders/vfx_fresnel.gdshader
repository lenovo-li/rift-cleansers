shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// 能量罩（vfx_kit 的 Dome，平面着色的测地半球）：边缘发光 + 自下而上的扫光 + 面片闪烁。
// 神圣护盾、反伤光环、火球/光球核心都用这个。

instance uniform vec4 tint : source_color = vec4(0.6, 0.85, 1.0, 1.0);
instance uniform float fade = 1.0;
uniform float rim_power = 2.2;
uniform float base_alpha = 0.08;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), rim_power);
	// 扫光：一条亮带从底部升到顶部，循环
	float sweep_pos = fract(TIME * 0.45);
	float sweep = 1.0 - smoothstep(0.0, 0.12, abs(local_pos.y / max(length(local_pos), 0.001) - sweep_pos));
	float flicker = texture(noise_tex, vec2(local_pos.x * 0.7 + TIME * 0.2, local_pos.z * 0.7)).r;
	float a = base_alpha + rim * 0.9 + sweep * 0.25 + flicker * 0.12;
	ALBEDO = mix(tint.rgb, vec3(1.0), rim * 0.4) * 1.6;
	ALPHA = clamp(a * fade * tint.a, 0.0, 1.0);
}
