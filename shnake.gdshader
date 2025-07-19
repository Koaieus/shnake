shader_type canvas_item;

uniform sampler2D state_in;
uniform ivec2 dir;
uniform ivec2 grid_size;

const float INV255 = 1.0/255.0;

void fragment() {
	vec2 grid_size_f = vec2(grid_size);
    vec2 invGS = 1.0/grid_size_f;
	ivec2 cell = ivec2(floor(UV * grid_size_f)); // 0-63 for x, y

    COLOR.a=1.0;
	
    // gather green regs: (0,1),(1,1),(1,0),(0,0)
    vec4 regs = textureGather(state_in, invGS, 1);
    //vec4 regs = vec4(
		//texelFetch(state_in, ivec2(0,1), 0).g,
		//texelFetch(state_in, ivec2(1,1), 0).g,
		//texelFetch(state_in, ivec2(1,0), 0).g,
		//texelFetch(state_in, ivec2(0,0), 0).g
	//);
	float g01 = regs.x; // (0,1)
	float g11 = regs.y; // (1,1)
	//float g10 = regs.z; // (1,0)
	float g00 = regs.w; // (0,0)
    int score  = int(g00*255.0);
    ivec2 head = ivec2(int(g01*255.0),int(g11*255.0));
    float curb = texture(state_in, UV).b;

    ivec2 nhead = (head+dir+grid_size)%grid_size;
    bool is_newh = all(equal(cell,nhead));
	
    ivec2 apple = ivec2((score*31) % grid_size.x, (score*57) % grid_size.y);
    bool is_apple = all(equal(cell,apple));
    float apple_b = texelFetch(state_in, apple, 0).b;
	
	bool eat = all(equal(nhead, apple)) || apple_b > 0.;
    score += int(eat);
	COLOR.r = float(is_apple && !eat);

    float nhead_b = texelFetch(state_in, nhead, 0).b;
	
    bool self_hit = nhead_b > 0.0;
	float decayed = curb - INV255;
	float threshold_b = max(1.0 - float(score) * INV255, 0.0);
	
    COLOR.b = is_newh ? 1.0 : step(threshold_b, decayed) * decayed;

    // compute green via nested ternary for registers
    COLOR.g = (cell.x<2&&cell.y<2) ?
        (cell.y==0 
			? (cell.x==0 ? float(score)/255.0 : float(self_hit))
			: (cell.x==0 ? float(nhead.x)/255.0 : float(nhead.y)/255.0)
        ) : 0.0;

}
