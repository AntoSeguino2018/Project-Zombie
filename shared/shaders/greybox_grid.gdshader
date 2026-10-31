shader_type spatial;
// Materiale greybox: griglia da 1 m in coordinate mondo, per leggere
// distanze, altezze e velocità mentre si prototipa.

uniform vec4 base_color : source_color = vec4(0.55, 0.57, 0.6, 1.0);
uniform vec4 line_color : source_color = vec4(0.38, 0.4, 0.44, 1.0);
uniform float cell_size = 1.0;
// Spessore delle linee in pixel (resta costante con la distanza, senza sfarfallio).
uniform float line_thickness = 1.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p) {
	vec2 coord = p / cell_size;
	vec2 dist = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	return 1.0 - clamp(min(dist.x, dist.y) / line_thickness, 0.0, 1.0);
}

void fragment() {
	// Proiezione triplanare: ogni faccia usa il piano più allineato alla sua normale.
	// Le tre griglie si calcolano sempre, perché fwidth non va usato dentro un if.
	vec3 n = abs(world_normal);
	float on_x = grid_line(world_pos.zy);
	float on_y = grid_line(world_pos.xz);
	float on_z = grid_line(world_pos.xy);
	float line = n.x > n.y && n.x > n.z ? on_x : (n.y > n.z ? on_y : on_z);
	ALBEDO = mix(base_color.rgb, line_color.rgb, line);
	ROUGHNESS = 0.9;
}
