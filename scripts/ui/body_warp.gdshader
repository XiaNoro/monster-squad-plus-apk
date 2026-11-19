shader_type canvas_item;

uniform vec4 pad;
uniform float sy = 1.0;
uniform float sx = 1.0;
uniform float bulge = 0.0;
uniform float lean = 0.0;
uniform float bend = 2.0;
uniform float flutter = 0.0;
uniform float phase = 0.0;
uniform float flash = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 inner = vec2(1.0 - pad.x - pad.z, 1.0 - pad.y - pad.w);
	vec2 b = (UV - pad.xy) / inner;
	float h = (1.0 - b.y) / sy;
	float hc = clamp(h, 0.0, 1.2);
	float x = b.x - 0.5;
	x -= lean * pow(hc, bend) + flutter * hc * hc * hc * sin(phase + hc * 5.0);
	x /= sx * (1.0 + bulge * sin(3.14159 * clamp(h, 0.0, 1.0)));
	vec2 src = vec2(x + 0.5, 1.0 - h);
	vec4 c = texture(TEXTURE, src);
	c.a *= step(0.0, src.x) * step(src.x, 1.0) * step(0.0, src.y) * step(src.y, 1.0);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c * tint;
}
