shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// =========================================================================
// Shader de Água Modular HD Pixel Art 3D (pixel_water.gdshader)
// - Ondulação natural original restaurada do commit 3a5ab6ea
// - Lâmina translúcida de 2.0m e efervescência estocástica a 6 Hz para cascatas
// - Película lateral de Y_água até Y_solo preservada (sem descarte de paredes laterais)
// =========================================================================

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.72, 0.82, 0.40);
uniform vec4 deep_color : source_color = vec4(0.08, 0.32, 0.52, 0.70);
uniform float depth_fade_distance : hint_range(0.1, 5.0) = 1.20;

group_uniforms ThreeWayWaterBlend;
uniform bool enable_3way_blend = false;
// 1. Água Turquesa Cristalina (Clearwater / Calcário)
uniform vec4 turquesa_shallow : source_color = vec4(0.18, 0.82, 0.78, 0.50);
uniform vec4 turquesa_deep : source_color = vec4(0.05, 0.38, 0.48, 0.90);
uniform float turquesa_fade = 1.20;
// 2. Água Barrenta de Várzea (Whitewater / Sedimentos / Solimões)
uniform vec4 barrenta_shallow : source_color = vec4(0.62, 0.47, 0.31, 0.85);
uniform vec4 barrenta_deep : source_color = vec4(0.38, 0.26, 0.16, 0.98);
uniform float barrenta_fade = 0.22;
// 3. Água Preta de Igarapé (Blackwater / Chá Mate / Rio Negro)
uniform vec4 igarape_shallow : source_color = vec4(0.38, 0.24, 0.11, 0.60);
uniform vec4 igarape_deep : source_color = vec4(0.11, 0.06, 0.04, 0.96);
uniform float igarape_fade = 0.55;

group_uniforms RipplesAndWaves;
uniform bool use_voronoi = false;
uniform float pixel_grid_density : hint_range(8.0, 128.0) = 52.0; // Texels por metro
uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;
uniform float wave_height : hint_range(0.0, 0.1) = 0.02;
uniform float voronoi_frequency : hint_range(0.2, 5.0) = 1.35;
uniform float shoreline_foam_dist : hint_range(0.05, 1.0) = 0.30;
uniform int shoreline_ripple_rings : hint_range(1, 5) = 3;
uniform float contact_foam_threshold : hint_range(0.01, 0.20) = 0.06;

group_uniforms WindAndRefraction;
uniform vec2 wind_direction = vec2(0.7071, 0.7071);
uniform float wind_speed : hint_range(0.2, 8.0) = 2.0;
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform float refraction_strength : hint_range(0.0, 12.0) = 4.0;
uniform float dash_density : hint_range(0.05, 0.95) = 0.40;
uniform float dash_max_width_px : hint_range(4.0, 32.0) = 14.0;
uniform float dash_cycle_speed : hint_range(0.05, 2.0) = 0.55;

group_uniforms ScreenSpaceReflection;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.35;
uniform float reflection_distortion_px : hint_range(0.0, 6.0) = 1.8;
uniform float specular_glint_threshold : hint_range(0.5, 0.99) = 0.88;

group_uniforms Foam;
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float wave_crest_foam_threshold : hint_range(0.70, 0.99) = 0.94;
uniform float wave_crest_voronoi_threshold : hint_range(0.50, 0.99) = 0.80;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_flow_data;
varying vec2 v_uv2;
varying float v_fall_top;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float voronoi_wave(vec2 uv, float time) {
	vec2 i_uv = floor(uv);
	vec2 f_uv = fract(uv);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash2(i_uv + neighbor);
			point = 0.5 + 0.5 * sin(time * wave_speed + 6.2831 * point);
			vec2 diff = neighbor + point - f_uv;
			min_dist = min(min_dist, length(diff));
		}
	}
	return min_dist;
}

vec2 hash_grad(vec2 p) {
	vec2 k = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(k) * 43758.5453123);
}

float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(dot(hash_grad(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
			dot(hash_grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash_grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(hash_grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float compute_screen_horizontal_dashes(
	vec3 world_pos,
	vec2 screen_uv,
	vec2 viewport_size,
	mat4 view_matrix,
	mat4 proj_matrix,
	float time,
	vec2 w_dir,
	float w_speed,
	float w_strength,
	float density,
	float max_width_px,
	float cycle_speed
) {
	vec2 curr_px = screen_uv * viewport_size;
	float cell_size = 0.85;
	vec2 cell_base = floor(world_pos.xz / cell_size);
	float dash_out = 0.0;

	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cell = cell_base + vec2(float(dx), float(dy));
			vec2 rnd = hash2(cell);

			if (rnd.x < (1.0 - density)) continue;

			vec3 dash_pos_world = vec3(
				(cell.x + rnd.x * 0.7 + 0.15) * cell_size,
				world_pos.y,
				(cell.y + rnd.y * 0.7 + 0.15) * cell_size
			);

			vec4 clip = proj_matrix * view_matrix * vec4(dash_pos_world, 1.0);
			if (clip.w <= 0.001) continue;
			vec2 suv = (clip.xy / clip.w) * 0.5 + 0.5;
			vec2 spx = suv * viewport_size;

			vec2 diff = abs(curr_px - spx);
			if (diff.y > 0.80) continue;

			float wave_phase = dot(dash_pos_world.xz, w_dir) * 2.6 - time * w_speed * cycle_speed + rnd.y * 6.2831;
			float wave_val = sin(wave_phase);
			float swell = smoothstep(-0.35, 0.85, wave_val) * w_strength;
			if (swell <= 0.005) continue;

			float current_half_width = (max_width_px * 0.5 * swell) * (0.65 + 0.35 * rnd.y);
			if (diff.x <= current_half_width) {
				float edge = clamp((current_half_width - diff.x) * 1.4, 0.0, 1.0);
				dash_out = max(dash_out, edge * swell);
			}
		}
	}
	return clamp(dash_out, 0.0, 1.0);
}

void vertex() {
	v_flow_data = COLOR;
	v_uv2 = UV2;
	v_fall_top = UV.y;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	if (v_fall_top <= 0.001) {
		v_fall_top = w_pos.y;
	}

	if (NORMAL.y > 0.5 && COLOR.b < 0.5) {
		vec2 snapped_xz = floor(w_pos.xz * pixel_grid_density) / pixel_grid_density;
		float wave = 0.0;
		if (use_voronoi) {
			wave = sin(snapped_xz.x * 6.0 + TIME * wave_speed) * cos(snapped_xz.y * 6.0 + TIME * wave_speed * 0.8);
		} else {
			vec2 w_dir = normalize(wind_direction);
			float coord_w = dot(snapped_xz, w_dir);
			float h1 = sin(coord_w * 2.2 - TIME * wind_speed * 1.5);
			float h2 = sin(dot(snapped_xz, normalize(w_dir * 0.92 + vec2(-w_dir.y, w_dir.x) * 0.39)) * 3.6 - TIME * wind_speed * 2.0 + 1.2);
			float gust = smoothstep(-0.35, 0.65, sin(coord_w * 0.45 - TIME * wind_speed * 0.60));
			wave = (h1 * 0.60 + h2 * 0.40) * (0.35 + 0.65 * gust) * wind_strength;
		}
		VERTEX.y += wave * wave_height;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool is_waterfall = (abs(v_world_normal.y) <= 0.5 && v_flow_data.b >= 0.8);

	// Descarta apenas faces voltadas para baixo (-Y)
	if (v_world_normal.y < -0.5) {
		discard;
	}

	if (is_waterfall) {
		// =========================================================================
		// TRANSIÇÃO VERTICAL DA CASCATA:
		// - Lâmina translúcida nos primeiros 2.0m de queda (Ytop a Ytop - 2m)
		// - Efervescência branca de cascata a 6 Hz para Y < Ytop - 2m
		// =========================================================================
		float fall_top = v_fall_top;
		float fall_dist = max(0.0, fall_top - v_world_pos.y);

		vec2 fall_snapped = floor(vec2(v_world_pos.x, v_world_pos.y) * pixel_grid_density) / pixel_grid_density;
		float cascade_speed = wave_speed * 4.2;

		vec4 fall_water_col = shallow_color;
		if (enable_3way_blend) {
			float w_turq = v_uv2.x;
			float w_barr = v_uv2.y;
			float sum_uv = w_turq + w_barr;
			if (sum_uv > 0.001) {
				float w_iga = max(0.0, 1.0 - sum_uv);
				fall_water_col = turquesa_shallow * w_turq + barrenta_shallow * w_barr + igarape_shallow * w_iga;
			} else {
				float t = clamp(v_flow_data.a, 0.0, 1.0);
				fall_water_col = mix(turquesa_shallow, igarape_shallow, t);
			}
		}

		vec2 texel_size = 1.0 / VIEWPORT_SIZE;
		float refr_anim = sin(fall_snapped.y * 14.0 + TIME * 12.0) * cos(fall_snapped.x * 10.0);
		vec2 refr_uv = SCREEN_UV + vec2(refr_anim * 1.5, refr_anim * 0.8) * texel_size;
		vec3 bg_refracted = texture(screen_texture, refr_uv).rgb;

		float stream1 = sin(fall_snapped.x * 12.0 + (fall_snapped.y + TIME * cascade_speed) * 8.0);
		float stream2 = cos(fall_snapped.x * 20.0 - (fall_snapped.y + TIME * cascade_speed * 1.3) * 11.0);
		float stream_noise = gradient_noise(vec2(fall_snapped.x * 3.5, (fall_snapped.y + TIME * cascade_speed) * 2.0));

		float col_hash = fract(sin(fall_snapped.x * 127.1) * 43758.5453);
		float threshold_y = 2.0 + (col_hash - 0.5) * 0.25;

		if (fall_dist <= threshold_y) {
			float cord_lines = sin(fall_snapped.x * 24.0 + stream_noise * 2.0) * 0.5 + 0.5;
			float cord_step = step(0.70, cord_lines);

			vec3 sheet_tint = fall_water_col.rgb * 1.08;
			vec3 laminar_sheet = mix(bg_refracted, sheet_tint, clamp(fall_water_col.a * 0.65, 0.35, 0.70));
			laminar_sheet = mix(laminar_sheet, vec3(1.0, 1.0, 1.0), cord_step * 0.25);

			ALBEDO = laminar_sheet;
			ALPHA = 1.0;
		} else {
			float foam_time_step = floor(TIME * 6.0);
			vec2 foam_grid = floor(vec2(v_world_pos.x, v_world_pos.y) * pixel_grid_density);
			float effervescence_noise = fract(sin(dot(foam_grid + vec2(foam_time_step * 19.3, foam_time_step * 37.1), vec2(12.9898, 78.233))) * 43758.5453);

			float foam_signal = stream_noise * 0.40 + (stream1 * stream2) * 0.30 + effervescence_noise * 0.45;
			float white_foam = step(0.28, foam_signal);

			vec3 boiling_cascade = mix(fall_water_col.rgb * 0.85, foam_color, clamp(white_foam + 0.55, 0.0, 1.0));

			ALBEDO = boiling_cascade;
			ALPHA = 1.0;
		}
	} else {
		// Superfície d'água e película lateral
		vec2 texel_size = 1.0 / VIEWPORT_SIZE;
		vec2 flow_dir = (v_flow_data.rg * 2.0 - 1.0);
		vec2 world_xz_snapped = floor(v_world_pos.xz * pixel_grid_density) / pixel_grid_density;
		vec2 animated_xz = world_xz_snapped - flow_dir * (TIME * 0.25);

		float bg_depth_raw = texture(depth_texture, SCREEN_UV).r;
		vec3 bg_ndc = vec3(SCREEN_UV * 2.0 - 1.0, bg_depth_raw);
		vec4 bg_view = INV_PROJECTION_MATRIX * vec4(bg_ndc, 1.0);
		bg_view.xyz /= bg_view.w;
		float water_depth = max(0.0, VERTEX.z - bg_view.z);

		vec4 cur_shallow = shallow_color;
		vec4 cur_deep = deep_color;
		float cur_fade = depth_fade_distance;

		if (enable_3way_blend) {
			float w_turquesa = v_uv2.x;
			float w_barrenta = v_uv2.y;
			float sum_uv2 = w_turquesa + w_barrenta;
			if (sum_uv2 > 0.001) {
				float w_igarape = max(0.0, 1.0 - sum_uv2);
				float streak = sin(animated_xz.x * 2.8 + animated_xz.y * 1.6) * 0.04
				             + cos(animated_xz.x * 1.4 - animated_xz.y * 3.2) * 0.03;
				float mix_active_uv2 = smoothstep(0.02, 0.15, 1.0 - max(max(w_turquesa, w_barrenta), w_igarape));
				w_barrenta = clamp(w_barrenta + streak * mix_active_uv2, 0.0, 1.0);
				float total_w = w_turquesa + w_barrenta + w_igarape;
				w_turquesa /= total_w;
				w_barrenta /= total_w;
				w_igarape /= total_w;
				cur_shallow = turquesa_shallow * w_turquesa + barrenta_shallow * w_barrenta + igarape_shallow * w_igarape;
				cur_deep = turquesa_deep * w_turquesa + barrenta_deep * w_barrenta + igarape_deep * w_igarape;
				cur_fade = turquesa_fade * w_turquesa + barrenta_fade * w_barrenta + igarape_fade * w_igarape;
			} else {
				float t = clamp(v_flow_data.a, 0.0, 1.0);
				float streak = sin(animated_xz.x * 2.8 + animated_xz.y * 1.6) * 0.04
				             + cos(animated_xz.x * 1.4 - animated_xz.y * 3.2) * 0.03;
				float mix_active = smoothstep(0.04, 0.20, t) * smoothstep(0.96, 0.80, t);
				t = clamp(t + streak * mix_active, 0.0, 1.0);
				if (t <= 0.5) {
					float f = smoothstep(0.12, 0.42, t);
					cur_shallow = mix(turquesa_shallow, barrenta_shallow, f);
					cur_deep = mix(turquesa_deep, barrenta_deep, f);
					cur_fade = mix(turquesa_fade, barrenta_fade, f);
				} else {
					float f = smoothstep(0.58, 0.88, t);
					cur_shallow = mix(barrenta_shallow, igarape_shallow, f);
					cur_deep = mix(barrenta_deep, igarape_deep, f);
					cur_fade = mix(barrenta_fade, igarape_fade, f);
				}
			}
		}

		float depth_factor = clamp(water_depth / cur_fade, 0.0, 1.0);
		float stepped_depth = floor(depth_factor * 5.0) / 5.0;

		vec2 w_dir = normalize(wind_direction);
		vec2 w_perp = vec2(-w_dir.y, w_dir.x);
		float coord_wind = dot(world_xz_snapped, w_dir);
		float coord_perp = dot(world_xz_snapped, w_perp);

		float h1 = sin(coord_wind * 2.2 - TIME * wind_speed * 1.5);
		vec2 dir_h2 = normalize(w_dir * 0.92 + w_perp * 0.39);
		float h2 = sin(dot(world_xz_snapped, dir_h2) * 3.6 - TIME * wind_speed * 2.0 + 1.2);
		vec2 dir_h3 = normalize(w_dir * 0.93 - w_perp * 0.36);
		float h3 = cos(dot(world_xz_snapped, dir_h3) * 5.0 - TIME * wind_speed * 2.4 + 2.1);

		float gust_coord = coord_wind * 0.45 - TIME * wind_speed * 0.60;
		float gust = smoothstep(-0.35, 0.65, sin(gust_coord) + sin(gust_coord * 0.5 + 1.1) * 0.4);
		float wind_wave_long = (h1 * 0.52 + h2 * 0.32 + h3 * 0.16) * (0.45 + 0.55 * gust) * wind_strength;

		vec2 refraction_dir = vec2(0.0);
		if (use_voronoi) {
			refraction_dir = vec2(
				sin(v_world_pos.z * 16.0 + TIME * wave_speed * 2.0),
				cos(v_world_pos.x * 16.0 + TIME * wave_speed * 1.5)
			);
		} else {
			refraction_dir = w_dir * (wind_wave_long * 1.35) + w_perp * (h2 * 0.45);
		}

		float depth_refr_scale = clamp(water_depth / max(0.1, cur_fade * 0.65), 0.05, 1.35);
		vec2 pixel_wave_offset = round(refraction_dir * (refraction_strength * 0.5) * depth_refr_scale) * texel_size;
		vec2 bg_uv = SCREEN_UV + pixel_wave_offset;

		float test_depth_raw = texture(depth_texture, bg_uv).r;
		vec3 test_ndc = vec3(bg_uv * 2.0 - 1.0, test_depth_raw);
		vec4 test_view = INV_PROJECTION_MATRIX * vec4(test_ndc, 1.0);
		test_view.xyz /= test_view.w;
		if (test_view.z > VERTEX.z - 0.02) {
			bg_uv = SCREEN_UV;
		}

		vec3 refracted_bg = texture(screen_texture, bg_uv).rgb;

		vec2 blur_r1 = texel_size * 2.2;
		vec2 blur_r2 = texel_size * 4.2;
		vec3 b_u = texture(screen_texture, bg_uv + vec2(0.0, blur_r1.y)).rgb;
		vec3 b_d = texture(screen_texture, bg_uv - vec2(0.0, blur_r1.y)).rgb;
		vec3 b_l = texture(screen_texture, bg_uv - vec2(blur_r1.x, 0.0)).rgb;
		vec3 b_r = texture(screen_texture, bg_uv + vec2(blur_r1.x, 0.0)).rgb;
		vec3 b_ul = texture(screen_texture, bg_uv + vec2(-blur_r2.x, blur_r2.y)).rgb;
		vec3 b_ur = texture(screen_texture, bg_uv + vec2(blur_r2.x, blur_r2.y)).rgb;
		vec3 b_dl = texture(screen_texture, bg_uv - vec2(blur_r2.x, blur_r2.y)).rgb;
		vec3 b_dr = texture(screen_texture, bg_uv + vec2(blur_r2.x, -blur_r2.y)).rgb;
		vec3 blurred_bg = (refracted_bg * 0.18 + (b_u + b_d + b_l + b_r) * 0.13 + (b_ul + b_ur + b_dl + b_dr) * 0.075);

		float shoreline_turbid = 0.0;
		float contact_foam = 0.0;
		if (water_depth < shoreline_foam_dist && water_depth >= 0.0) {
			float norm_shore = water_depth / shoreline_foam_dist;
			float wave_perturb = sin(world_xz_snapped.x * 12.0 + world_xz_snapped.y * 12.0) * 0.08;
			float rings = sin((norm_shore + wave_perturb) * float(shoreline_ripple_rings) * 6.2831 - TIME * (wave_speed * 2.5));
			float ring_step = step(0.40 + norm_shore * 0.4, rings);
			float edge_solid = smoothstep(0.18, 0.02, norm_shore) * 0.50;
			shoreline_turbid = clamp(ring_step + edge_solid, 0.0, 1.0);
			float contact_line = step(water_depth, contact_foam_threshold);
			contact_foam = max(contact_line, ring_step * step(norm_shore, 0.35));
		}

		float wave_curr = 0.0;
		float v_wave = 0.0;
		float caustic_band = 0.0;
		float crest_rise = 0.0;
		float crest_voronoi_rise = 0.0;

		if (use_voronoi) {
			wave_curr = sin(world_xz_snapped.x * 6.0 + TIME * wave_speed) * cos(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8);
			v_wave = voronoi_wave(animated_xz * voronoi_frequency, TIME);
			caustic_band = step(0.72, v_wave);
			crest_rise = smoothstep(0.40, 0.93, wave_curr);
			crest_voronoi_rise = smoothstep(0.55, 0.85, v_wave);
		} else {
			wave_curr = wind_wave_long;
			v_wave = clamp(wind_wave_long * 0.5 + 0.5, 0.0, 1.0);
			caustic_band = step(0.78, wind_wave_long) * 0.35;
			crest_rise = smoothstep(0.45, 0.95, wave_curr);
			crest_voronoi_rise = smoothstep(0.50, 0.90, v_wave);
		}

		float high_crest_turbid = crest_rise * (0.35 + 0.45 * crest_voronoi_rise);
		float crest_turbid = clamp(high_crest_turbid * 0.70 + caustic_band * 0.25, 0.0, 1.0);

		float crest_foam = 0.0;
		if (use_voronoi) {
			crest_foam = step(wave_crest_foam_threshold, wave_curr) * step(wave_crest_voronoi_threshold, v_wave);
		} else {
			crest_foam = step(wave_crest_foam_threshold, wind_wave_long);
		}

		float turb = v_flow_data.b;
		if (turb > 0.35) {
			float turb_foam = step(1.02 - turb * 0.52, v_wave) * smoothstep(0.35, 0.85, turb);
			crest_foam = max(crest_foam, turb_foam);
		}

		float turbid_factor = clamp(shoreline_turbid * 0.50 + crest_turbid * 0.40 + turb * 0.50, 0.0, 1.0);
		vec3 seabed_refracted = mix(refracted_bg, blurred_bg, turbid_factor);

		vec3 reflected_scene = vec3(0.0);
		float reflection_weight = 0.0;

		if (v_world_normal.y > 0.5) {
			vec4 clip_curr = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world_pos, 1.0);
			vec4 clip_up = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world_pos + vec3(0.0, 1.0, 0.0), 1.0);
			vec2 uv_curr = (clip_curr.xy / clip_curr.w) * 0.5 + 0.5;
			vec2 uv_up = (clip_up.xy / clip_up.w) * 0.5 + 0.5;
			vec2 screen_up_per_meter = uv_up - uv_curr;
			vec2 screen_perp = vec2(-screen_up_per_meter.y, screen_up_per_meter.x);

			vec2 wave_slope = vec2(0.0);
			float voronoi_ripple = 0.0;
			if (use_voronoi) {
				wave_slope = vec2(
					cos(world_xz_snapped.x * 6.0 + TIME * wave_speed) * cos(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8),
					-sin(world_xz_snapped.x * 6.0 + TIME * wave_speed) * sin(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8)
				);
				voronoi_ripple = (v_wave - 0.5) * 2.0;
			} else {
				wave_slope = w_dir * (wind_wave_long * 1.4) + w_perp * (h2 * 0.45);
				voronoi_ripple = (v_wave - 0.5) * 1.2;
			}

			vec2 surface_wave_offset = (screen_perp * (wave_slope.x * 1.5 + voronoi_ripple * 0.8) + screen_up_per_meter * (wave_slope.y * 1.8 + wave_curr * 0.7)) * (reflection_distortion_px * texel_size.y * 14.0);
			vec2 pixel_wave_distortion = round(surface_wave_offset / texel_size) * texel_size;

			for (int step_idx = 1; step_idx <= 24; step_idx++) {
				float t_refl = float(step_idx) / 24.0;
				float h_refl = t_refl * t_refl * 3.2 + t_refl * 1.6;
				vec2 sample_uv = SCREEN_UV + screen_up_per_meter * h_refl + pixel_wave_distortion;

				if (sample_uv.x < 0.005 || sample_uv.x > 0.995 || sample_uv.y < 0.005 || sample_uv.y > 0.995) break;

				float sample_depth = texture(depth_texture, sample_uv).r;
				vec3 sample_ndc = vec3(sample_uv * 2.0 - 1.0, sample_depth);
				vec4 sample_view = INV_PROJECTION_MATRIX * vec4(sample_ndc, 1.0);
				sample_view.xyz /= sample_view.w;
				vec3 sample_world_pos = (INV_VIEW_MATRIX * vec4(sample_view.xyz, 1.0)).xyz;

				float obj_h = sample_world_pos.y - v_world_pos.y;
				if (obj_h <= 0.02) continue;
				if (h_refl > obj_h * 2.2 + 0.15) continue;

				float max_tol = max(0.045, obj_h * 0.35);
				float wave_h_mod = wave_curr * wave_height * 2.5;
				float expected_h = h_refl * 0.5 + wave_h_mod;

				if (abs(obj_h - expected_h) < max_tol && sample_view.z < VERTEX.z + 0.25) {
					reflected_scene = texture(screen_texture, sample_uv).rgb;
					float height_scale = clamp(obj_h / 0.35, 0.30, 1.0);
					float falloff = 1.0 - t_refl * 0.30;
					reflection_weight = clamp(reflection_strength * 1.65 * falloff * height_scale, 0.0, 0.82);
					break;
				}
			}
		}

		vec4 base_water = mix(cur_shallow, cur_deep, stepped_depth);
		float shallow_fade = clamp(water_depth / (cur_fade * 0.65), 0.15, 1.0);
		float effective_alpha = mix(cur_shallow.a * shallow_fade, cur_deep.a, stepped_depth);

		vec3 water_tint = mix(base_water.rgb, cur_shallow.rgb * 1.05, high_crest_turbid * 0.06);
		vec3 underwater_floor = mix(seabed_refracted, water_tint, effective_alpha);

		underwater_floor = mix(underwater_floor, cur_shallow.rgb * 1.25, caustic_band * 0.18);

		vec3 surface_composite = underwater_floor;
		if (reflection_weight > 0.0) {
			surface_composite = mix(underwater_floor, reflected_scene, reflection_weight);
		}

		if (v_world_normal.y > 0.5 && !use_voronoi) {
			float white_dash = compute_screen_horizontal_dashes(
				v_world_pos,
				SCREEN_UV,
				VIEWPORT_SIZE,
				VIEW_MATRIX,
				PROJECTION_MATRIX,
				TIME,
				w_dir,
				wind_speed,
				wind_strength,
				dash_density,
				dash_max_width_px,
				dash_cycle_speed
			);
			if (white_dash > 0.0) {
				surface_composite = mix(surface_composite, vec3(1.0, 1.0, 1.0), white_dash * 0.95);
			}
		}

		float total_surface_foam = max(crest_foam, contact_foam);
		if (total_surface_foam > 0.0) {
			surface_composite = mix(surface_composite, foam_color, clamp(total_surface_foam * 0.90, 0.0, 1.0));
		}

		ALBEDO = surface_composite;
		ALPHA = 1.0;
	}
}
