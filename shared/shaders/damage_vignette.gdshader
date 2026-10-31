shader_type canvas_item;
// Bordo colorato sui lati dello schermo, trasparente al centro.
// intensity = 0 lo spegne, 1 lo accende del tutto.

uniform vec4 tint : source_color = vec4(0.85, 0.05, 0.05, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float edge = smoothstep(0.35, 1.3, length(UV * 2.0 - 1.0));
	COLOR = vec4(tint.rgb, tint.a * edge * intensity);
}
