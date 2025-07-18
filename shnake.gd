extends Node2D
class_name ShnakeGame

# Snake game using ping-pong viewports and shader state
@export var start_head_pos: Vector2i = Vector2i(30, 30)
@export var start_direction: Vector2i = Vector2i.UP
@export var start_score: int = 1
@export_range(1, 150, 1) var start_fps: float = 10
@export var increase_fps: bool = true

@onready var display: TextureRect = %Display
@onready var viewport_a: SubViewport = $SubViewportA
@onready var viewport_b: SubViewport = $SubViewportB
@onready var cr_a: ColorRect = $SubViewportA/ColorRectA
@onready var cr_b: ColorRect = $SubViewportB/ColorRectB

var using_a := true
var dir := start_direction
var previous_dir := start_direction
var frame_timer := 0.0
var fps: float = start_fps
var score: int = 0

# Snake updates every x seconds
var step_rate: float:
	get:
		return 1.0 / fps

const GRID_SIZE := Vector2i(64, 64)

func _ready():
	viewport_a.size = GRID_SIZE
	viewport_b.size = GRID_SIZE
	_reset_state()
	_step()

func _process(delta):
	frame_timer += delta
	if frame_timer >= step_rate:
		frame_timer = 0.0
		_step()

func _reset_state():
	# initialize state texture
	using_a = true
	fps = start_fps
	score = start_score
	var img = Image.create_empty(GRID_SIZE.x, GRID_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,1))
	# place head in blue
	img.set_pixel(start_head_pos.x, start_head_pos.y, Color(0,0,1,1))
	img.set_pixel(0,0, Color(0, float(score)/255.0, 0, 1))
	img.set_pixel(0,1, Color(0, start_head_pos.x/255.0, 0, 1))
	img.set_pixel(1,1, Color(0, start_head_pos.y/255.0, 0, 1))
	var tex = ImageTexture.create_from_image(img)
	for cr in [cr_a, cr_b]:
		var mat = cr.material as ShaderMaterial
		mat.set_shader_parameter("state_in", tex)
		mat.set_shader_parameter("dir", dir)
		mat.set_shader_parameter("grid_size", GRID_SIZE)
		cr.material = mat
	display.texture = tex

func _step():
	# ping-pong rendering
	var src = viewport_a if using_a else viewport_b
	var dst = viewport_b if using_a else viewport_a
	var cr_dst = cr_b if using_a else cr_a
	var mat = cr_dst.material as ShaderMaterial
	mat.set_shader_parameter("state_in", src.get_texture())
	mat.set_shader_parameter("dir", dir)
	dst.render_target_update_mode = SubViewport.UPDATE_ONCE
	display.texture = dst.get_texture()
	_decode_and_print(dst)
	previous_dir = dir
	# flip:
	using_a = not using_a

func _decode_and_print(vp: SubViewport):
	var img = vp.get_texture().get_image()
	# read registers
	var r00 = img.get_pixel(0,0) # score
	var r10 = img.get_pixel(1,0) # death flag
	var r01 = img.get_pixel(0,1) # head_x
	var r11 = img.get_pixel(1,1) # head_y
	# decode head coords and score
	var head_x = int(r01.g * 255.0)
	var head_y = int(r11.g * 255.0)
	score = int(r00.g * 255.0)
	var apple := Vector2i((score*31) % GRID_SIZE.x, (score*57) % GRID_SIZE.y)
	# decode death flag from REG10.g
	var death_flag = r10.g > 0.0
	# log full state
	print("Step Log: Head=(%d,%d), Score=%d, Apple=%s, Death=%s" % [head_x, head_y, score, apple, death_flag])

func _unhandled_input(event):
	if event.is_action_pressed("ui_right") and previous_dir != Vector2i.LEFT:
		dir = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left") and previous_dir != Vector2i.RIGHT:
		dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_up") and previous_dir != Vector2i.DOWN:
		dir = Vector2i.UP
	elif event.is_action_pressed("ui_down") and previous_dir != Vector2i.UP:
		dir = Vector2i.DOWN
