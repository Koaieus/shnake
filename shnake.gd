extends Node2D
class_name ShnakeGame

@export var start_head_pos: Vector2i = Vector2i(30, 30)
@export var start_direction: Vector2i = Vector2i.UP
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

# Snake updates every x seconds
var step_rate: float:
	set = _set_step_rate
func _set_step_rate(v): pass
func get_step_rate(): return 1.0/fps

const GRID_SIZE := Vector2i(64, 64)

func _ready():
	viewport_a.size = GRID_SIZE
	viewport_b.size = GRID_SIZE
	_reset_state()
	_step()

func _process(delta):
	frame_timer += delta
	if frame_timer >= get_step_rate():
		frame_timer = 0
		_step()

func _reset_state():
	fps = start_fps
	var img = Image.create_empty(GRID_SIZE.x, GRID_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,1))
	img.set_pixel(start_head_pos.x, start_head_pos.y, Color(0,0,1,1)) # head in green
	# initialize registers: both REG00 and REG10 store head_x, head_y in g channel
	img.set_pixel(0,0, Color(0, start_head_pos.x/255.0, 0,1))
	img.set_pixel(1,0, Color(0, start_head_pos.y/255.0, 0,1))
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	for cr in [cr_a, cr_b]:
		var mat = cr.material as ShaderMaterial
		mat.set_shader_parameter("state_in", tex)
		mat.set_shader_parameter("dir", dir)
		mat.set_shader_parameter("grid_size", GRID_SIZE)
		cr.material = mat
	display.texture = tex

func _step():
	var src = viewport_a if using_a else viewport_b
	var dst = viewport_a if not using_a else viewport_b
	var cr_dst = cr_b if using_a else cr_a
	var mat = cr_dst.material as ShaderMaterial
	mat.set_shader_parameter("state_in", src.get_texture())
	mat.set_shader_parameter("dir", dir)
	dst.render_target_update_mode = SubViewport.UPDATE_ONCE
	display.texture = dst.get_texture()
	_decode_and_print(dst)
	using_a = !using_a
	previous_dir = dir

func _decode_and_print(vp: SubViewport):
	var img = vp.get_texture().get_image()
	var r00 = img.get_pixel(0,0)
	var r10 = img.get_pixel(1,0)
	var head_x = int(r00.g * 255.0)
	var head_y = int(r00.g * 255.0)
	var is_dead: bool = r00.g == 1.0 and r10.g == 1.0
	print("Head at (%d, %d)" % [head_x, head_y])
	if is_dead:
		print('Died!')
		assert(false)
		_reset_state()

func _unhandled_input(e):
	if e.is_action_pressed("ui_right") and dir != Vector2i.LEFT:
		dir = Vector2i.RIGHT
	elif e.is_action_pressed("ui_left") and dir != Vector2i.RIGHT:
		dir = Vector2i.LEFT
	elif e.is_action_pressed("ui_up") and dir != Vector2i.DOWN:
		dir = Vector2i.UP
	elif e.is_action_pressed("ui_down") and dir != Vector2i.UP:
		dir = Vector2i.DOWN
