shader_type spatial;
// LED che si accendono uno per uno, al posto del materiale luminoso di un
// modello importato. Quale LED è un frammento lo si capisce dalla sua
// posizione nello spazio della mesh, così il modello non va diviso in pezzi.
// layout 0 = tamburo della Magnum: sei camere (quadratini sulla faccia) e sei
//   strisce esterne, una per camera; la camera 0 è in alto, le altre seguono
//   l'ordine di sparo (ogni 60° in senso orario guardando dalla canna).
// layout 1 = striscia di sei LED in cima al fusto della Magnum: 0 davanti
//   (verso la canna), 5 dietro.
// Tutto il resto della superficie resta sempre acceso.

uniform vec4 on_color : source_color = vec4(0.0, 0.68, 1.0, 1.0);
uniform vec4 off_color : source_color = vec4(0.04, 0.07, 0.1, 1.0);
uniform float energy = 2.2;
// Bit i acceso = LED i acceso.
uniform int lit_mask = 63;
uniform int layout = 0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

int drum_slot(vec3 p) {
	float r = length(p.xy);
	if (r < 0.008) {
		return -1;
	}
	float angle = degrees(atan(p.y, p.x));
	// Quadratini davanti a ogni camera: la camera 0 è a 90°, poi -60° alla volta.
	// Strisce esterne: stanno a metà tra due camere, assegnate a quella prima.
	float first = r < 0.034 ? 90.0 : 60.0;
	int slot = int(round((first - angle) / 60.0));
	return ((slot % 6) + 6) % 6;
}

int frame_slot(vec3 p) {
	if (p.y < 0.088 || abs(p.x) > 0.008 || p.z < -0.055 || p.z > 0.042) {
		return -1;
	}
	return clamp(int(round((p.z + 0.045) / 0.0155)), 0, 5);
}

void fragment() {
	int slot = layout == 0 ? drum_slot(local_pos) : frame_slot(local_pos);
	bool on = slot < 0 || ((lit_mask >> slot) & 1) == 1;
	ALBEDO = on ? on_color.rgb : off_color.rgb;
	EMISSION = on ? on_color.rgb * energy : vec3(0.0);
	ROUGHNESS = 0.5;
}
