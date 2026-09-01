shader_type spatial;
render_mode cull_disabled, specular_disabled;

// 卡通三档着色:半 Lambert 漫反射压成三档色阶,外加一层冷色边缘光。
// 保留原贴图(albedo_tex,默认白)和底色(tint),所有模型共用同一份材质逻辑。

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec3 tint : source_color = vec3(1.0);
// 自定义 light() 时引擎不会自动叠加环境光,这里手工补一份暖色环境底光。
uniform vec3 ambient : source_color = vec3(0.24, 0.22, 0.18);
// 暗部抬升:过暗的材质抬到暖灰色底,低模卡通不出现死黑。
uniform float lift : hint_range(0.0, 0.4) = 0.06;
// 反照率上限:白墙白床单不再爆白,亮面封在柔和的奶白色。
uniform float albedo_cap : hint_range(0.5, 1.0) = 0.72;
// 固定底光:与反照率无关的恒常微光,深色材质(金属器械)也能被看清。
uniform float emission_floor : hint_range(0.0, 0.2) = 0.03;

varying float v_rim;

void fragment() {
	ALBEDO = min(max(texture(albedo_tex, UV).rgb * tint, vec3(lift)), vec3(albedo_cap));
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	float fres = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	v_rim = pow(1.0 - fres, 4.0);
	// 恒常底光:保证暗部不死黑,低模卡通不发闷。
	EMISSION = ALBEDO * ambient + vec3(emission_floor);
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float band = ndl < 0.4 ? 0.45 : (ndl < 0.75 ? 0.7 : 0.82);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ALBEDO * band;
	DIFFUSE_LIGHT += v_rim * LIGHT_COLOR * ATTENUATION * vec3(0.55, 0.7, 1.0) * 0.12;
}
