shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// 斩击弧 / 旋风带（vfx_kit 的 SlashArc、Swirl）：UV.x 沿弧（0 起刀 → 1 收刀），UV.y 从内缘到外缘。
// progress 0→1：刀光从起刀端扫到收刀端，拖尾逐渐消散；外缘是最亮的刀锋。
// progress < 0 表示循环模式（旋风带）：不扫描，只滚动噪声条纹。

instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(0.6, 0.85, 1.0, 1.0);
instance uniform float fade = 1.0;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float body;
	if (progress < 0.0) {
		body = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.75, 1.0, u));
	} else {
		float head = mix(-0.1, 1.25, progress);
		// 刀头之后亮、之前没有；拖尾长度随时间缩短
		float tail = mix(0.9, 0.15, progress);
		body = smoothstep(head - tail, head, u) * (1.0 - smoothstep(head, head + 0.06, u));
	}
	float scroll = TIME * (progress < 0.0 ? 1.6 : 0.4);
	float streak = texture(noise_tex, vec2(u * 2.5 - scroll, v * 0.6)).r;
	float edge = pow(v, 3.0);
	float core = edge * 1.6 + streak * 0.55 * v;
	vec3 col = mix(tint.rgb, vec3(1.0), edge * 0.7);
	ALBEDO = col * 1.8;
	ALPHA = clamp(body * core * fade * tint.a, 0.0, 1.0);
}
