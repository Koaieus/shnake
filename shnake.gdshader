shader_type canvas_item;

// Shader Snake — Branchless Edition™
// Goal: Remove all conditional branching where possible for warp-friendly execution

// Pass UV from vertex to fragment
varying vec2 v_uv;

void vertex() {
    v_uv = UV;
}


uniform sampler2D state_in;
uniform ivec2 dir;

const int GRID_SIZE = 64;
const float GRID_SIZE_M1 = float(GRID_SIZE - 1);


ivec2 get_frag_coord(vec2 uv) {
    return ivec2(floor(uv * float(GRID_SIZE)));
}


// Decode reserved state
int decode_score() { return int(round(texelFetch(state_in, ivec2(0,0), 0).r * 255.0)); }
int decode_offset() { return int(round(texelFetch(state_in, ivec2(0,0), 0).g * 255.0)); }
bool is_dead() { return texelFetch(state_in, ivec2(0,0), 0).b == 10./255.; }

ivec2 decode_head_pos() {
    vec2 enc = texelFetch(state_in, ivec2(1,0), 0).rg;
    return ivec2(round(enc * float(GRID_SIZE-1)));
}

vec2 encode_head_pos(ivec2 pos) {
    return vec2(float(pos.x)/GRID_SIZE_M1, float(pos.y)/GRID_SIZE_M1);
}

ivec2 get_apple_pos(int score) {
    return ivec2((score * 31) % GRID_SIZE, (score * 57) % GRID_SIZE);
}

void fragment() {
	ivec2 uv = get_frag_coord(UV);
	if (uv.x < 0 || uv.y < 0 || uv.x >= GRID_SIZE || uv.y >= GRID_SIZE) { discard; }

	vec4 cur = texelFetch(state_in, uv, 0);
	int score = decode_score();
	int offset = decode_offset();
	ivec2 apple = get_apple_pos(score + offset);
	ivec2 head = decode_head_pos();
	ivec2 nhead = ivec2((head + dir + GRID_SIZE) % GRID_SIZE);

	// Flags
	bool at00 = (uv.x==0 && uv.y==0);
	bool at10 = (uv.x==1 && uv.y==0);
	bool self_hit = texelFetch(state_in, nhead, 0).b > 0.2;
	bool eat = (nhead == apple) && !self_hit;
	bool new_h = (uv == nhead) && !self_hit;
	bool is_apple = (uv == apple) && !(uv == nhead);

	// Reserved pixel (0,0): store score, offset, death
	int new_score = score + int(eat);
	float death = (self_hit ? 1.0 : 0.0)/255.0;
	vec4 p00 = vec4(float(new_score)/255.0, float(offset)/255.0, death, 1.0);

	// Pixel (1,0): head pos
	vec4 p10 = vec4(encode_head_pos(nhead), 0.0, 1.0);

	// Apple pixel marker
	vec4 pA = vec4(1.0, 0.0, 0.0, 1.0);

	// New head: full blue
	vec4 pH = vec4(0.0, 0.0, 1.0, 1.0);

	// Body: fade blue, disappear if beyond length
	float bv = cur.b * 255.0 - 1.0;
	float min_bl = float(255 - score);
	vec4 pB = mix(vec4(0.0, 0.0, 0.0, 1.0), vec4(0.0,0.0,bv/255.0,1.0), step(min_bl, bv));

	// Compose
	vec4 _out = pB;
	_out = mix(_out, pH, float(new_h));
	_out = mix(_out, pA, float(is_apple));
	_out = mix(_out, p10, float(at10));
	_out = mix(_out, p00, float(at00));

	COLOR = _out;
}
