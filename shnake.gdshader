/*
	=====================
	Shader Snake — Branchless Edition™
	=====================

	Grid-based Snake implemented in a single pass shader using:
	- Minimal texture fetches (max 4 per pixel)
	- Packed metadata registers (pixels 0,0 and 1,0)
	- Self-contained logic for movement, eating, dying, and fading

	Pixel encodings:
	REG00 (0,0):
	- r = score / 255
	- g = RNG offset / 255
	- b = death flag (1/255 when self-hit occurs, otherwise blue trail if head passes)
	- a = 1.0

	REG10 (1,0):
	- r = head_x / (grid_width - 1)
	- g = head_y / (grid_height - 1)
	- b = blue trail if head passes over this pixel (preserves fade logic)
	- a = 1.0

	Body Pixels:
	- b = snake trail. 1.0 (255) for head, decrements by 1 each frame, disappears when below (255 - score)

	Notes:
	- Red apple is placed using XOR-folded seed from score + offset with 2 primes
	- All logic is conditional-free (branchless) using ternary expressions for warp-safe evaluation
*/

shader_type canvas_item;

uniform ivec2 grid_size;
uniform sampler2D state_in;
uniform ivec2 dir;

// Static colors and flags
const vec4 COLOR_APPLE = vec4(1.0, 0.0, 0.0, 1.0); // bright red apple
const vec4 COLOR_HEAD  = vec4(0.0, 0.0, 1.0, 1.0); // full blue head
const float GREEN_DEATH_FLAG = 1.0;                // encoded death marker

// Constant register pixel coords
const ivec2 REG00 = ivec2(0,0); // stores score, rng offset, death flag
const ivec2 REG10 = ivec2(1,0); // stores head position as encoded RG

// Magic primes for pseudo-random apple placement
const int PRIME_A = 31;
const int PRIME_B = 57;
const float INV_255 = 1.0 / 255.0;

void fragment() {
	// Derive grid dimensions and inverse texel size (based on viewport)
	vec2 grid_size_f = vec2(grid_size);
	int GW = grid_size.x;          // grid width
	int GH = grid_size.y;          // grid height
	vec2 fWh1 = grid_size_f - vec2(1.0);  // (GW-1, GH-1) as float

	// Map UV to integer texel coords
	ivec2 uv = ivec2(UV * grid_size_f);

	// Fetch special register pixels
	vec4 r00 = texelFetch(state_in, REG00, 0);  // score, offset, death flag (written only)
	float score = r00.r * 255.0;
	int score_i  = int(score);
	int offset = int(r00.g * 255.0);

	vec4 r10 = texelFetch(state_in, REG10, 0);  // encoded head pos (r = x / (GW-1), g = y / (GH-1))
	ivec2 head = ivec2(
		int(round(r10.r * fWh1.x)), 
		int(round(r10.g * fWh1.y))
	);

	// Next head position and apple location
	ivec2 nhead = (head + dir + grid_size) % grid_size; // move with wraparound

	// Fetch current texel color (for fading logic)
	vec4 cur = texelFetch(state_in, uv, 0);

	// Calculate XOR-folded seed for apple location
	int seed = score_i + offset;
	seed ^= (seed << 5);
	seed ^= (seed >> 3);

	ivec2 apple = ivec2((seed * PRIME_A) % GW, (seed * PRIME_B) % GH);

	// Pixel location checks
	bool at00 = all(equal(uv, REG00)); // register (0,0)
	bool at10 = all(equal(uv, REG10)); // register (1,0)

	// Detect collisions and actions (done only at pixel 0,0)
	bool self_hit = at00 && (texelFetch(state_in, nhead, 0).b > 0.);
	bool eat      = at00 && ((nhead == apple) || texelFetch(state_in, apple, 0).b > 0.) ;

	// Runtime flags for this pixel
	bool new_h      = (uv == nhead);          // this pixel will become head
	bool show_apple = !new_h && (uv == apple); // apple display (not if overwritten by head)

	// Blue channel: trail fade and head marker
	float decayed = cur.b - INV_255;
	// Blue value [normalized] to be used in every pixel we write
	float b = new_h ? 1.0 : step(1.0 - score * INV_255, decayed) * decayed;

	// Register pixel (0,0): score + offset + DEATH_FLAG
	int new_score = score_i + int(eat);
	vec4 p00 = vec4(
		float(new_score) * INV_255,
		(self_hit ? GREEN_DEATH_FLAG : float(offset) * INV_255),
		b,
		1.0
	);

	// Register pixel (1,0): head position (preserve RG, reuse blue if head lands here)
	vec4 p10 = vec4(
		float(nhead.x) / fWh1.x,
		float(nhead.y) / fWh1.y,
		b,
		1.0
	);

	// Regular body pixels: fading trail
	vec4 pB = vec4(0.0, 0.0, b, 1.0); // fading trail

	// Final composition using ternaries
	vec4 col = show_apple ? COLOR_APPLE : pB;  // apple or regular body
	col = at10       ? p10         : col;   // register (1,0) overrides all
	col = at00       ? p00         : col;   // register (0,0) overrides all

	COLOR = col;
}