//shader_type canvas_item;
//
//uniform sampler2D state_in;
//uniform ivec2 grid_size;
	////vec2 grid_size_f = vec2(grid_size);
	////ivec2 cell = ivec2(floor(UV * grid_size_f));
//
//const vec3 COLOR_GRID = vec3(0.1);      // background grid
//const vec3 COLOR_CELL = vec3(0.3);      // highlight active cell
//const vec3 COLOR_REGISTER = vec3(0.8, 0.2, 0.2); // special pixels like (0,0), etc.
//
//void fragment() {
	//vec2 grid_size_f = vec2(grid_size);
	//ivec2 cell = ivec2(floor(UV * grid_size_f));
	//
	////COLOR = texture(state_in, UV);
	////COLOR = vec4(UV.x, UV.y, 0.5, 1);
	////// Distance to center of cell
	////vec2 fpos = fract(UV * grid_size_f);
	////float border = step(0.95, fpos.x) + step(0.95, fpos.y); // thin edge lines
////
	////// Highlight registers
	////bool is_register = (cell.x < 2 && cell.y < 2);
////
	////vec3 base_color = COLOR_GRID;
////
	////// Overlay grid cell structure
	////base_color += vec3(border * 0.2);
////
	////// Register highlight
	////if (is_register) {
		////base_color = COLOR_REGISTER;
	////}
////
	//////COLOR = vec4(base_color, 1.0);
	////// Show blue value of texture sample as brightness
	////vec4 tex = texelFetch(state_in, cell, 0);
	////COLOR = tex;
//}

//shader_type canvas_item;
//
//uniform sampler2D state_in;
//uniform ivec2 dir;
//uniform ivec2 grid_size;
//
//const float INV255 = 1.0/255.0;
//
//void fragment() {
	//vec2 grid_size_f = vec2(grid_size);
	//ivec2 cell = ivec2(floor(UV * grid_size_f));
	//COLOR = texelFetch(state_in, cell, 1);
	////COLOR = vec4(UV.x, UV.y, 0.5, 1.0);
	////vec2 GS = vec2(grid_size);
	////vec2 invGS = 1.0/GS;
	////vec2 uv = floor(UV * GS) + 0.5; // snap to texel center
	//////ivec2 uv    = ivec2(UV*GS);
	//////COLOR = texture(state_in, uv * invGS, 0);
	////COLOR = texture(state_in, UV);
	//
//}

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
	
	bool eat = all(equal(nhead, apple));
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
