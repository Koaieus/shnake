extends Node2D
class_name ShnakeGame

@export var start_head_pos: Vector2i = Vector2i(30, 30)
@export_range(1, 100, 1) var start_score: int = 3
@export var start_direction: Vector2i = Vector2i.UP
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

var score: int: 
	set(v):
		if v != score:
			print('Score now: %s' % score)
			score = v
			if score > 0 and increase_fps:
				fps = start_fps + (score - start_score)
				#print("fps=%s score=%s start_score=%s" % [fps, score, start_score])


var offset: int: 
	set(v):
		if v != offset:
			print('Offset now: %s' % offset)
			offset = v

## Snake updates every x seconds
var step_rate: float:
	get():
		return 1./fps


const GRID_SIZE := Vector2i(64, 64)

func _ready():
	# Enforce viewport sizes
	viewport_a.size = GRID_SIZE
	viewport_b.size = GRID_SIZE
	reset()
	await RenderingServer.frame_post_draw
	simulate_step()

func _process(delta):
	frame_timer += delta
	if frame_timer >= step_rate:
		frame_timer = 0.0
		simulate_step()
		
func reset():
	fps = start_fps
	score = start_score
	# Create fresh initial state image
	var img = Image.create_empty(GRID_SIZE.x, GRID_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,1))
	# Place head marker
	img.set_pixel(start_head_pos.x, start_head_pos.y, Color(0, 0, 1, 1))
	# Set initial score=1 in (0,0).g and no offset
	img.set_pixel(0, 0, Color(0, score/255.0, 0, 1))
	# Encode head pos in (0,1).g and (1,1).g
	var enc = Vector2(start_head_pos.x / 255.0, start_head_pos.y / 255.0)
	img.set_pixel(0, 1, Color(0, enc.x, 0, 1))
	img.set_pixel(1, 1, Color(0, enc.y, 0, 1))

	# Create initial textures
	var tex = ImageTexture.create_from_image(img)
	# Assign to both viewports' materials so ping-pong starts consistently
	for color_rect in [color_rect_a, color_rect_b]:
		var mat = color_rect.material as ShaderMaterial
		mat.set_shader_parameter("state_in", tex)
		mat.set_shader_parameter("dir", dir)
		mat.set_shader_parameter("grid_size", GRID_SIZE)

	# Show initial texture
	display.texture = tex


func simulate_step():
	var src: SubViewport = viewport_a if using_a else viewport_b
	var dst: SubViewport = viewport_b if using_a else viewport_a
	var dst_cr: ColorRect = color_rect_b if using_a else color_rect_a
	var mat: ShaderMaterial = dst_cr.material
	
	mat.set_shader_parameter("dir", dir)
	mat.set_shader_parameter("state_in", src.get_texture())

	dst.render_target_update_mode = SubViewport.UPDATE_ONCE
	display.texture = src.get_texture()

	check_for_apple_and_reroll(dst, dst_cr)
	using_a = !using_a
	previous_dir = dir
	
	
func check_for_apple_and_reroll(dst_vp: SubViewport, dst_cr: ColorRect):
	var img = dst_vp.get_texture().get_image()
	
	# Decode score from (0,0)
	var score_px = img.get_pixel(0, 0)
	print('Reading `score` color: %s' % [score_px])

	# Decode death from (0,0)
	var death_px = img.get_pixel(1, 0)
	print('Reading `death_px` color: %s' % [death_px])

	# Decode pos from (1,0)
	var pos := Vector2i(int(img.get_pixel(0, 1).g * GRID_SIZE.x), int(img.get_pixel(1, 1).g * GRID_SIZE.y))
	print('Decoded `position`: %s' % [pos])
	

	score = int(score_px.r * 255.0)
	## Decode offset from (0,0)
	#offset = int(score_px.g * 255.0)
	
	## Calculate apple position
	#var seed := score + offset
	#seed ^= (seed << 5);
	#seed ^= (seed >> 3);
#
	#var apple_pos = Vector2i((seed * 31) % 64, (seed * 57) % 64)
	#var apple_px := img.get_pixelv(apple_pos)
	#print("Apple @ %s  Col(%s)" % [apple_pos, apple_px])
	
	# Decode death from (0,0)
	var is_dead: bool = death_px.g * 255.0 >= 1.0
	#assert(not is_dead, 'Dedde')
	#if is_dead:
		#print("Died at %s" % [pos])
		#return reset()
	return
	
	#var is_inside_snake := _is_inside_snake(apple_px.b)
	#if is_inside_snake:
		#print('reroll detected!')
		#var reroll_count := 1
		#while (is_inside_snake):
			#offset = (offset + 1) % 256
			## Reroll random position
			#seed = score + offset
			#seed ^= (seed << 5);
			#seed ^= (seed >> 3);
			#apple_pos = Vector2i((seed * 31) % 64, (seed * 57) % 64)
			#
			#apple_px = img.get_pixelv(apple_pos)
			#is_inside_snake = _is_inside_snake(apple_px.b)
			#print('Reroll attempt %s... apple pos now: %s. Still inside snake? %s' % [reroll_count, apple_pos, 'yes! Rerolling more...' if is_inside_snake else 'nope, all good now :)'])
			#assert(reroll_count < 200, 'Bork!')
			#reroll_count += 1
		#score_px.g = float(offset) / 255.0
		#print('Writing color %s to (0,0)' % [score_px])
		#img.set_pixel(0, 0, score_px)
		#print('Color is now: %s' % [img.get_pixel(0,0)])
		#assert(is_equal_approx(img.get_pixel(0,0).g, (float(offset) / 255.0)), "bad pixel value")
		#var new_tex = ImageTexture.new()
		#new_tex.create_from_image(img)
		##var mat = (color_rect_a.material if using_a else color_rect_b.material) as ShaderMaterial # or flip?
		#dst_cr.material.set_shader_parameter("state_in", new_tex)


func _is_inside_snake(apple_blue_value: float) -> bool:
	return apple_blue_value > 0

func _unhandled_input(event):
	if event.is_action_pressed("ui_right") and previous_dir != Vector2i.LEFT:
		dir = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left") and previous_dir != Vector2i.RIGHT:
		dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_up") and previous_dir != Vector2i.DOWN:
		dir = Vector2i.UP
	elif event.is_action_pressed("ui_down") and previous_dir != Vector2i.UP:
		dir = Vector2i.DOWN
