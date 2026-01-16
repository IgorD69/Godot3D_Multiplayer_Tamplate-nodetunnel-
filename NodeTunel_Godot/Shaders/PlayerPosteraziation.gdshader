shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;

uniform float zNear = 0.05;
uniform float zFar = 100.0;

uniform bool enable_outline = true;
uniform vec3 outline_color : source_color = vec3(0.0);
uniform float outline_thickness = 1.0;

uniform bool enable_color_limit = true;
uniform int color_levels : hint_range(2, 32) = 8;

uniform bool enable_color_palette = true;
uniform vec4 color1 : source_color = vec4(1.0, 0.925, 0.839, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 0.831, 0.639, 1.0);
uniform vec4 color3 : source_color = vec4(1.0, 0.667, 0.369, 1.0);
uniform vec4 color4 : source_color = vec4(0.816, 0.506, 0.349, 1.0);
uniform vec4 color5 : source_color = vec4(0.553, 0.412, 0.478, 1.0);
uniform vec4 color6 : source_color = vec4(0.329, 0.306, 0.408, 1.0);
uniform vec4 color7 : source_color = vec4(0.125, 0.236, 0.337, 1.0);
uniform vec4 color8 : source_color = vec4(0.05, 0.169, 0.271, 1.0);

uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3;

// Funcție rapidă pentru liniarizarea adâncimii fără matrici complexe în buclă
float get_linear_depth(vec2 uv) {
    float d = texture(DEPTH_TEXTURE, uv).r;
    return zNear * zFar / (zFar + d * (zNear - zFar));
}

float get_luma(vec3 c) {
    return dot(c, vec3(0.2125, 0.7154, 0.0721));
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 screen_raw = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 final_color = screen_raw;

	// 1. POSTERIZE (Mutat înainte pentru a reduce complexitatea culorii)
	if(enable_color_limit) {
		float lvls = float(color_levels);
		final_color = round(final_color * lvls) / lvls;
	}

	// 2. PALETTE CLAMPING (Optimizat)
	if (enable_color_palette) {
		vec3 p[8] = vec3[](color1.rgb, color2.rgb, color3.rgb, color4.rgb, color5.rgb, color6.rgb, color7.rgb, color8.rgb);
		vec3 closest = p[0];
		float min_dist = distance(final_color, p[0]);

		for(int i = 1; i < 8; i++) {
			float d = distance(final_color, p[i]);
			if(d < min_dist) {
				min_dist = d;
				closest = p[i];
			}
		}
		final_color = closest;
	}

	// 3. DITHERING (Pre-calculat index)
	if(enable_dithering) {
		float dithering[16] = float[](0.0,0.5,0.125,0.625,0.75,0.25,0.875,0.375,0.1875,0.6875,0.0625,0.5625,0.9375,0.4375,1.0,0.8125);
		ivec2 uv_i = ivec2(mod(FRAGCOORD.xy, 4.0));
		float threshold = dithering[uv_i.x + uv_i.y * 4];
		float luma = get_luma(final_color);

		float dither_val = (luma < threshold) ? -0.5 : 0.5;
		final_color += final_color * (dither_val * dither_strength);
	}

	// 4. OUTLINES (Sobel Optimizat - doar dacă e activat)
	if(enable_outline) {
		vec2 size = outline_thickness / VIEWPORT_SIZE;

		// Citiri adiacente (Cruce) - reducem de la 9 la 4 citiri pentru viteză mare
		// sau păstrăm 9 dar optimizăm funcția. Aici folosim varianta optimizată cu 4 citiri "Cross"
		float d_up    = get_linear_depth(SCREEN_UV + vec2(0, size.y));
		float d_down  = get_linear_depth(SCREEN_UV - vec2(0, size.y));
		float d_left  = get_linear_depth(SCREEN_UV - vec2(size.x, 0));
		float d_right = get_linear_depth(SCREEN_UV + vec2(size.x, 0));
		float edge_d  = abs(d_up - d_down) + abs(d_left - d_right);

		float n_up    = get_luma(texture(NORMAL_TEXTURE, SCREEN_UV + vec2(0, size.y)).rgb);
		float n_down  = get_luma(texture(NORMAL_TEXTURE, SCREEN_UV - vec2(0, size.y)).rgb);
		float edge_n  = abs(n_up - n_down);

		float outline = smoothstep(0.01, 0.05, edge_d * 5.0 + edge_n);
		final_color = mix(final_color, outline_color, outline);
	}

	ALBEDO = final_color;
}