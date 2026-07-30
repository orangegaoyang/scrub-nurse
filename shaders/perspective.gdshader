shader_type canvas_item;
// Fake a downward perspective tilt: squeeze the top edge inward (recedes).
uniform float amount : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	float k = amount * (1.0 - UV.y);       // 0 at bottom, "amount" at top
	float x0 = 0.5 * k;                    // visible left edge
	float x1 = 1.0 - 0.5 * k;              // visible right edge
	if (UV.x < x0 || UV.x > x1) {
		COLOR = vec4(0.0);
		return;
	}
	vec2 uv = vec2((UV.x - x0) / (x1 - x0), UV.y);
	COLOR = texture(TEXTURE, uv);
}
