shader_type canvas_item;
// 屏幕边缘暗角：低血量时常驻，受伤时脉冲一下。

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.7, 0.0, 0.05, 1.0);

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c * vec2(1.0, 0.8)) * 1.6;
	float v = smoothstep(0.45, 1.05, d) * intensity;
	COLOR = vec4(tint.rgb, v);
}
