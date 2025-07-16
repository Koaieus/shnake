/* Shader: Shnake Snake — Single-channel head/world state */
shader_type canvas_item;
uniform sampler2D state_in;
uniform ivec2 dir;
uniform ivec2 grid_size;

const ivec2 REG00 = ivec2(0,0);
const ivec2 REG10 = ivec2(1,0);
const float INV255 = 1.0/255.0;

void fragment(){
    ivec2 GS = grid_size;
    vec2 inv = vec2(GS);
    ivec2 uv = ivec2(UV * inv);
    // fetch registers: head pos in .g at REG00 and REG10
    float hx = texelFetch(state_in, REG00,0).g * 255.0;
    float hy = texelFetch(state_in, REG10,0).g * 255.0;
    ivec2 head = ivec2(int(hx), int(hy));
    ivec2 nhead = (head + dir + GS) % GS;
	
	bool died = texelFetch(state_in, nhead, 0).b > 0.;
	
    // fetch current
    float curb = texelFetch(state_in, uv,0).b;
    // detect eat any blue
    ivec2 apple = ivec2( 
		int(texelFetch(state_in, ivec2(2,0),0).r*float(GS.x)), 
		int(texelFetch(state_in, ivec2(2,0),0).g*float(GS.y)) 
	);
    bool eat = texelFetch(state_in, apple,0).b>0.0;
    bool newh = all(equal(uv,nhead));
    bool showA = !newh && all(equal(uv,apple));
    // compute blue fade
    float b = newh?1.0:max(curb - INV255,0.0);
    // store head pos
    vec4 p00 = vec4(0, died ? 1.0 : float(nhead.x)/255.0, b,1);
    vec4 p10 = vec4(0, died ? 1.0 : float(nhead.y)/255.0, b,1);
    vec4 pA  = vec4(1,0,0,1);
    vec4 pB  = vec4(0,0,b,1);
    vec4 col = showA? pA : pB;
    col = all(equal(uv,REG10))? p10:col;
    col = all(equal(uv,REG00))? p00:col;
    COLOR = col;
}
