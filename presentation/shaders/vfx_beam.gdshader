shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// 光柱（vfx_kit 的 Beam，开口圆筒，UV.y 从底到顶）：向上滚动的噪声能量流，中心比边缘亮，两端淡出。
// 惩击、圣域、陨石拖尾、火球拖尾都用这个。

instance uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.55, 1.0);
instance uniform float fade = 1.0;
uniform float scroll_speed = 2.5;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

void fragment() {
	float n = texture(noise_tex, vec2(UV.x * 2.0, UV.y * 1.5 - TIME * scroll_speed)).r;
	float core = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float ends = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.5) * 1.8;
	ALPHA = clamp((core * 0.8 + n * 0.5) * ends * fade * tint.a, 0.0, 1.0);
}
