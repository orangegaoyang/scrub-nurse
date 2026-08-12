shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform vec4 color : source_color = vec4(0, 0, 0, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec2 size = vec2(0.19, 0.13);
uniform float corner_radius = 0.025;

// 2D rounded-rectangle SDF (Inigo Quilez), evaluated in world-ish units so
// corners stay round regardless of the plane's aspect.
void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 h = size * 0.5;
	float r = corner_radius;
	vec2 q = abs(p) - h + r;
	float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
	float a = smoothstep(0.0015, 0.0, d) * alpha;
	ALBEDO = color.rgb;
	ALPHA = a;
}
