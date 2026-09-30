shader_type spatial;
render_mode unshaded, cull_disabled;
// 敌人死亡溶解：噪声低于 progress 的像素被丢弃，边缘发光。每个实例用 instance uniform，共用一个材质。

instance uniform float progress : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 base_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform float edge_width = 0.08;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

void fragment() {
	float n = texture(noise_tex, UV * 1.5).r;
	if (n < progress) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, edge_width, n - progress);
	ALBEDO = mix(base_color.rgb * (1.0 - progress * 0.5), edge_color.rgb * 2.0, edge * step(0.01, progress));
}
