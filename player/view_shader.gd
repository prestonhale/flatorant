extends TextureRect

# https://github.com/87PizzaStudios/godot_light_fow/blob/main/fow/fow_light.gd

var mask_image: Image
var mask_texture: Texture2D
var view_polygon: Polygon2D

@export var default_fog_color := Color.GRAY
## Scales down the fow texture for more efficient computation
@export_range(0.05,1.0) var fow_scale_factor := 1.

var tracked_player: Player

@onready var subviewport: SubViewport = $SubViewportContainer/MaskSubViewport

var size_vec: Vector2i

var vision_cone_dups: Dictionary

# Called when the node enters the scene tree for the first time.
func _ready():
	# Process after the polygon is update
	
	self.size.x = get_viewport_rect().size.x
	self.size.y = get_viewport_rect().size.y
	
	# Set a custom color as the default modulation
	var image1 = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image1.fill(default_fog_color)
	var fillTexture = ImageTexture.create_from_image(image1)
	texture = fillTexture
	
	var display_width = self.size.x
	var display_height = self.size.y
	size_vec = fow_scale_factor * Vector2(display_width, display_height)
	
	subviewport.set_size(size_vec)
	
	# mask
	mask_image = Image.create(display_width, display_height, false, Image.FORMAT_RGBA8)
	mask_image.fill(Color.BLACK)
	mask_texture = ImageTexture.create_from_image(mask_image)

func _process(_delta: float):
	var player
	if not tracked_player:
		return
	else:
		player = tracked_player
	
	# Update the fog of war's position
	position = player.position - (get_viewport_rect().size/2)
	
	# Update the subviewport polygon to match the player's polygon
	if not view_polygon:
		view_polygon = player.vision_cone.write_polygon2d.duplicate()
		view_polygon.color = Color.WHITE
		view_polygon.scale = Vector2(2, 2)
		subviewport.add_child(view_polygon)
	view_polygon.position = player.get_global_transform_with_canvas().origin
#	view_polygon.offset = get_global_transform().origin
	view_polygon.rotation = player.rotation - .5 * PI
	view_polygon.polygon = player.vision_cone.write_polygon2d.polygon
	
	mask_image = subviewport.get_texture().get_image()
	mask_texture = ImageTexture.create_from_image(mask_image)
	material.set_shader_parameter('mask_texture', mask_texture)

