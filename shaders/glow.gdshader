shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform vec4 color : source_color = vec4(0.62, 0.71, 0.82, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec2 size = vec2(0.175, 0.125);
uniform float corner_radius = 0.04;

// Soft rounded-rect halo: full strength inside, fading to nothing just
// outside the rect, so it reads as light spilling around the badge edges
// instead of a hard outline.
void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 h = size * 0.5;
	float r = corner_radius;
	vec2 q = abs(p) - h + r;
	float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
	float a = (1.0 - smoothstep(-0.02, 0.0, d)) * alpha;
	ALBEDO = color.rgb;
	ALPHA = a;
}
