extends Node2D
class_name ShnakeGame

@export var start_head_pos: Vector2i = Vector2i(30, 30)
@export_range(1, 100, 1) var start_score: int = 3
@export var start_direction: Vector2i = Vector2i.RIGHT
@export_range(1, 150, 1) var start_fps: float = 10
@export var increase_fps: bool = true

@onready var display: TextureRect = %Display
@onready var viewport_a: SubViewport = $SubViewportA
@onready var viewport_b: SubViewport = $SubViewportB
@onready var color_rect_a: ColorRect = $SubViewportA/ColorRectA
@onready var color_rect_b: ColorRect = $SubViewportB/ColorRectB

@onready var snake_material: ShaderMaterial = preload("res://shnake_shader_material.tres")

var using_a := true
var dir := start_direction
var previous_dir := start_direction
var frame_timer := 0.0
var fps: float = start_fps

## Snake updates every x seconds
var step_rate: float:
	get():
		return 1./fps
var tick: int = 0

const GRID_SIZE = 64

func _ready():
	# Enforce viewport sizes
	viewport_a.size = Vector2i(GRID_SIZE, GRID_SIZE)
	viewport_b.size = Vector2i(GRID_SIZE, GRID_SIZE)
	reset()
	simulate_step()

func _process(delta):
	frame_timer += delta
	if frame_timer >= step_rate:
		frame_timer = 0.0
		simulate_step()
		
func reset():
	fps = start_fps
	# Create fresh initial state image
	var img = Image.create_empty(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,1))
	# Place head marker
	img.set_pixel(start_head_pos.x, start_head_pos.y, Color(0, 0, 1, 1))
	# Set initial score=1 in (0,0).r and no offset
	img.set_pixel(0, 0, Color(start_score/255.0, 0.0, 0.0, 1))
	# Encode head pos in (1,0)
	var enc = Vector2(start_head_pos.x / 63.0, start_head_pos.y / 63.0)
	img.set_pixel(1, 0, Color(enc.x, enc.y, 0, 1))

	# Create initial textures
	var tex = ImageTexture.create_from_image(img)
	# Assign to both viewports' materials so ping-pong starts consistently
	for color_rect in [color_rect_a, color_rect_b]:
		var mat = color_rect.material as ShaderMaterial
		mat.set_shader_parameter("state_in", tex)
		mat.set_shader_parameter("dir", dir)

	# Show initial texture
	display.texture = tex
	#simulate_step()


func simulate_step():
	var src: SubViewport = viewport_a if using_a else viewport_b
	var dst: SubViewport = viewport_b if using_a else viewport_a
	var dst_cr: ColorRect = color_rect_b if using_a else color_rect_a
	var mat: ShaderMaterial = dst_cr.material
	
	mat.set_shader_parameter("dir", dir)
	mat.set_shader_parameter("state_in", src.get_texture())

	dst.render_target_update_mode = SubViewport.UPDATE_ONCE
	display.texture = src.get_texture()

	check_for_apple_and_reroll()
	using_a = !using_a
	previous_dir = dir
	
	
func check_for_apple_and_reroll():
	var src: SubViewport = viewport_a if using_a else viewport_b
	var img = src.get_texture().get_image()
	var score_px = img.get_pixel(0, 0)
	var score = int(score_px.r * 255.0)
	if score > 0 and increase_fps:
		fps = start_fps + (score - start_score)
		#print("fps=%s score=%s start_score=%s" % [fps, score, start_score])
	var offset = int(score_px.g * 255.0)
	var is_dead: bool = int(score_px.b * 255.0) == 1.0
	#assert(not is_dead, 'Dedde')
	if is_dead:
		return reset()
	var seed_ = score + offset
	var apple_pos = Vector2i((seed_ * 31) % 64, (seed_ * 57) % 64)
	var apple_px = img.get_pixel(apple_pos.x, apple_pos.y)
	#print("apple pos, px: %s %s" % [apple_pos,apple_px])
	#print("score (offset): %s (%s)" % [score, offset])
	var is_inside_snake = _is_inside_snake(apple_px.b)
	if is_inside_snake:
		print('reroll detected!')
		var reroll_count := 1
		while (is_inside_snake):
			offset = (offset + 1) % 256
			score_px.g = float(offset) / 255.0
			seed_ = score + offset
			apple_pos = Vector2i((seed_ * 31) % 64, (seed_ * 57) % 64)
			apple_px = img.get_pixel(apple_pos.x, apple_pos.y)
			is_inside_snake = _is_inside_snake(apple_px.g)
			print('Reroll attempt %s... still inside snake?' % [reroll_count, 'yes! :o' if is_inside_snake else 'nope :)'])
			reroll_count += 1
		img.set_pixel(0, 0, score_px)
		var new_tex = ImageTexture.create_from_image(img)
		var mat = (color_rect_a.material if using_a else color_rect_b.material) as ShaderMaterial
		mat.set_shader_parameter("state_in", new_tex)

func _is_inside_snake(apple_blue_value: float) -> bool:
	return apple_blue_value > 0.2 and apple_blue_value < 1.0

func _unhandled_input(event):
	if event.is_action_pressed("ui_right") and previous_dir != Vector2i.LEFT:
		dir = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left") and previous_dir != Vector2i.RIGHT:
		dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_up") and previous_dir != Vector2i.DOWN:
		dir = Vector2i.UP
	elif event.is_action_pressed("ui_down") and previous_dir != Vector2i.UP:
		dir = Vector2i.DOWN
