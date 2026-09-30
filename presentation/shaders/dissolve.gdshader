shader_type spatial;
render_mode unshaded, cull_disabled;
// 敌人死亡溶解：噪声低于 progress 的像素被丢弃，边缘发光。每个实例用 instance uniform，共用一个材质。
// 低模没有 UV，噪声按模型空间坐标采样；有顶点色时用顶点色，否则用 base_color。

instance uniform float progress : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 base_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform float edge_width = 0.08;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float n = texture(noise_tex, local_pos.xz * 1.3 + local_pos.y * 0.7).r;
	if (n < progress) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, edge_width, n - progress);
	vec3 body = COLOR.rgb * base_color.rgb;
	ALBEDO = mix(body * (1.0 - progress * 0.5), edge_color.rgb * 2.0, edge * step(0.01, progress));
}
