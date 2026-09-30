shader_type spatial;
// 灰烬王城地面：世界坐标石板格（每块 2 米，逐行错缝），灰烬噪声斑驳，广场中心更亮、外圈更焦黑。
// 没有贴图，全部程序化；俯视 28 米距离下只需要大块明暗。

uniform vec4 stone_color : source_color = vec4(0.36, 0.34, 0.31, 1.0);
uniform vec4 ash_color : source_color = vec4(0.18, 0.16, 0.15, 1.0);
uniform vec4 ember_color : source_color = vec4(0.55, 0.22, 0.08, 1.0);
uniform float tile_size = 2.0;
uniform float plaza_radius = 20.0;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = world_pos.xz / tile_size;
	// 逐行错缝
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float grout = smoothstep(0.02, 0.06, edge);
	float tile_shade = 0.85 + hash(cell) * 0.3;
	float n = texture(noise_tex, world_pos.xz * 0.02).r;
	float n2 = texture(noise_tex, world_pos.xz * 0.11 + vec2(0.3)).r;
	float dist = length(world_pos.xz);
	// 广场内石板干净，外圈灰烬越来越多
	float ash = smoothstep(0.35, 0.75, n + clamp((dist - plaza_radius) / 70.0, 0.0, 0.35));
	vec3 col = stone_color.rgb * tile_shade;
	col = mix(col, ash_color.rgb, ash * 0.85);
	col *= mix(0.55, 1.0, grout);
	// 零星余烬裂纹（石缝里微微发红）
	float ember = (1.0 - grout) * smoothstep(0.72, 0.9, n2) * ash;
	ALBEDO = col;
	EMISSION = ember_color.rgb * ember * 1.5;
	ROUGHNESS = 0.95;
}
