shader_type canvas_item;

uniform sampler2D state_in;
uniform ivec2 dir;

void fragment() {
    ivec2 uv = ivec2(FRAGCOORD.xy);
    vec4 prev = texelFetch(state_in, uv, 0);
    COLOR = prev + vec4(0.01, 0.01, 0.01, 0.0);

}