shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// 冲击波：平面上一圈向外扩散的亮环，边缘带噪声扰动，随 progress 变细并淡出。

instance uniform float progress : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 wave_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float thickness = 0.12;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float angle = atan(c.y, c.x);
	float wobble = texture(noise_tex, vec2(angle * 0.3, progress * 0.5)).r * 0.08;
	// progress 是线性时间：半径用 ease-out 快速扩开，透明度按时间线性淡出
	float eased = 1.0 - pow(1.0 - progress, 3.0);
	float front = eased * 0.92 + wobble;
	float w = thickness * (1.0 - progress * 0.7);
	float ring = smoothstep(front - w, front, r) * (1.0 - smoothstep(front, front + w * 0.4, r));
	// 环内侧留一层淡淡的余光
	float inner = (1.0 - smoothstep(0.0, front, r)) * 0.15 * (1.0 - progress);
	float fade = 1.0 - progress * progress;
	ALBEDO = wave_color.rgb * 1.6;
	ALPHA = clamp((ring + inner) * fade * wave_color.a, 0.0, 1.0);
}
