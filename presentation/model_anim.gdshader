shader_type spatial;
// 模型顶点动画（敌人、Boss、地图零件共用）。Blender 端 lowpoly.part() 把每个零件的分区和枢轴写进两层 UV：
//   UV.x  = 分区编号 + 0.5（发光零件）  UV.y = 枢轴 x    UV2 = 枢轴 (y, z)   —— 模型空间，y 上、-z 前
// 分区编号与 tools/blender/lowpoly.py 的 PARTS 一致：
//   0 body  1 leg_l  2 leg_r  3 arm_l  4 arm_r  5 head  6 tail  7 wing_l  8 wing_r  9 cloth  10 flame  11 sway  12 spin
// 敌人每帧通过实例参数传状态（MeshInstance3D.set_instance_shader_parameter）；MultiMesh 零件不传，只用时间和世界坐标做环境动画。
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(1.0);
uniform float emission_energy = 0.0;   // 精英整体微光
uniform float glow_energy = 0.9;       // 发光零件（眼睛、余烬、晶体）
uniform float roughness_value = 0.85;
uniform float wind_strength = 1.0;     // 地图零件摇摆幅度

// x 跑动相位（弧度，CPU 按移动距离累加）  y 移动强度 0-1  z 攻击进度 0-1（0 = 不在攻击）  w 受击 0-1
instance uniform vec4 anim_a = vec4(0.0);
// x 闪白 0-1  y 攻击类型（0 挥击 1 施法 2 蓄力冲刺 3 砸地）  z 随机种子  w 预留
instance uniform vec4 anim_b = vec4(0.0);

varying float v_glow;

mat3 rot_x(float a) { float c = cos(a); float s = sin(a); return mat3(vec3(1, 0, 0), vec3(0, c, s), vec3(0, -s, c)); }
mat3 rot_y(float a) { float c = cos(a); float s = sin(a); return mat3(vec3(c, 0, -s), vec3(0, 1, 0), vec3(s, 0, c)); }
mat3 rot_z(float a) { float c = cos(a); float s = sin(a); return mat3(vec3(c, s, 0), vec3(-s, c, 0), vec3(0, 0, 1)); }

// 攻击时手臂抬起角度（绕 x 轴，正值向前上方抬）
float arm_attack(float t, float kind) {
	if (t <= 0.0) return 0.0;
	if (kind > 2.5) {  // 砸地：双手高举 → 猛砸
		return t < 0.5 ? mix(0.0, 2.8, smoothstep(0.0, 0.5, t)) : mix(2.8, 0.5, smoothstep(0.5, 0.65, t)) * (1.0 - smoothstep(0.75, 1.0, t));
	}
	if (kind > 1.5) return 0.4 * sin(t * 3.14159);  // 蓄力冲刺：手臂后收
	if (kind > 0.5) return 1.5 * sin(min(t / 0.6, 1.0) * 1.5708) * (1.0 - smoothstep(0.7, 1.0, t));  // 施法：前指
	// 挥击：后拉 → 向前劈 → 收回
	return t < 0.35 ? mix(0.0, 2.2, smoothstep(0.0, 0.35, t)) : mix(2.2, 0.3, smoothstep(0.35, 0.55, t)) * (1.0 - smoothstep(0.7, 1.0, t));
}

void vertex() {
	float id = floor(UV.x + 0.01);
	v_glow = step(0.25, fract(UV.x + 0.01));
	vec3 pivot = vec3(UV.y, UV2.x, UV2.y);
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	float seed = anim_b.z;
	float ph = anim_a.x;
	float move = anim_a.y;
	float atk = anim_a.z;
	float hurt = anim_a.w;
	float kind = anim_b.y;
	float idle = 1.0 - move;
	vec3 wpos = MODEL_MATRIX[3].xyz;
	mat3 r = mat3(1.0);
	vec3 off = vec3(0.0);

	if (id > 0.5 && id < 2.5) {           // 腿：前后交替
		float side = id < 1.5 ? 1.0 : -1.0;
		r = rot_x(sin(ph) * 0.6 * move * side);
	} else if (id > 2.5 && id < 4.5) {    // 手臂：与腿反向摆 + 攻击动作 + 待机轻晃
		float side = id < 3.5 ? 1.0 : -1.0;
		float a = -sin(ph) * 0.45 * move * side + sin(TIME * 1.7 + seed + side) * 0.06 * idle;
		a += arm_attack(atk, kind) * (kind > 0.5 && kind < 1.5 && side > 0.0 ? 0.5 : 1.0);
		r = rot_x(a) * rot_z(side * hurt * 0.5);
	} else if (id > 4.5 && id < 5.5) {    // 头：走路点头、待机左右看、受击后仰
		r = rot_y(sin(TIME * 0.6 + seed) * 0.25 * idle) * rot_x(cos(ph * 2.0) * 0.06 * move + hurt * 0.35 - atk * 0.15);
	} else if (id > 5.5 && id < 6.5) {    // 尾巴：摆动
		r = rot_y(sin(TIME * 4.0 + seed) * 0.45) * rot_x(sin(TIME * 2.3 + seed) * 0.15);
	} else if (id > 6.5 && id < 8.5) {    // 翅膀：拍动（绕前后轴）
		float side = id < 7.5 ? 1.0 : -1.0;
		r = rot_z(side * (sin(TIME * 14.0 + seed) * 0.55 + 0.1));
	} else if (id > 8.5 && id < 9.5) {    // 衣摆 / 飘带：越往下摆得越大，移动时向后飘
		float k = clamp((pivot.y - p.y) / max(pivot.y, 0.2), 0.0, 1.2);
		off.x += sin(TIME * 2.2 + seed + p.y * 4.0) * 0.035 * k;
		off.z += (sin(TIME * 1.7 + seed + p.x * 5.0) * 0.025 + move * 0.07) * k;
	} else if (id > 9.5 && id < 10.5) {   // 火焰：闪烁拉伸 + 摇曳
		float h = max(p.y - pivot.y, 0.0);
		float f = sin(TIME * 13.0 + seed * 3.0 + wpos.x) * 0.5 + sin(TIME * 7.3 + seed) * 0.5;
		off.y += h * f * 0.18;
		off.x += sin(TIME * 9.0 + h * 14.0 + seed) * h * 0.25;
		off.z += cos(TIME * 8.0 + h * 11.0 + seed) * h * 0.2;
	} else if (id > 10.5 && id < 11.5) {  // 风吹摇摆（树、草、旗）：按世界坐标错开相位
		float h = max(p.y - pivot.y, 0.0);
		float w = sin(TIME * 1.3 + wpos.x * 0.21 + wpos.z * 0.17) * 0.6 + sin(TIME * 2.9 + wpos.z * 0.3) * 0.25;
		float lean = (0.035 + 0.06 / (1.0 + h)) * wind_strength;
		off.x += w * lean * h;
		off.z += cos(TIME * 1.1 + wpos.x * 0.13) * lean * 0.5 * h;
		off += vec3(sin(TIME * 6.0 + p.x * 9.0 + p.z * 7.0), 0.0, cos(TIME * 5.0 + p.y * 8.0)) * 0.008 * h * wind_strength;
	} else if (id > 11.5) {               // 环绕物：绕枢轴竖轴旋转 + 上下漂浮
		r = rot_y(TIME * 1.4 + seed);
		off.y += sin(TIME * 2.2 + seed) * 0.04;
	}
	p = pivot + r * (p - pivot) + off;
	n = r * n;

	// 整体：走路起伏、待机呼吸、攻击前倾、受击后仰、冲刺蓄力下蹲抖动
	float lean = hurt * 0.25 - (kind < 2.5 ? sin(atk * 3.14159) * 0.2 : 0.0);
	float squash = 1.0 - hurt * 0.08 - (kind > 1.5 && kind < 2.5 ? sin(atk * 3.14159) * 0.18 : 0.0);
	p.y *= squash + sin(TIME * 2.0 + seed) * 0.015 * idle;
	if (kind > 1.5 && kind < 2.5 && atk > 0.0) p.x += sin(TIME * 70.0) * 0.025 * atk;
	mat3 body = rot_x(lean) * rot_z(sin(ph) * 0.05 * move);
	p = body * p;
	n = body * n;
	p.y += abs(sin(ph)) * 0.05 * move;
	VERTEX = p;
	NORMAL = normalize(n);
}

void fragment() {
	vec3 albedo = COLOR.rgb * tint.rgb;
	float flash = anim_b.x;
	ALBEDO = mix(albedo, vec3(1.0), flash);
	ROUGHNESS = roughness_value;
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0 + anim_b.z * 5.0);
	EMISSION = albedo * (emission_energy + v_glow * glow_energy * pulse) + vec3(flash * 1.4);
}
