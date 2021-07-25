extends Camera2D

onready var image_cursor = load("res://player/cursor.png")
onready var map = get_viewport().get_node("world/nav/map")
onready var parent = get_parent()

const TILE_SIZE = 32
const SCREEN_WIDTH = 1280
const SCREEN_HEIGHT = 720
const PAN_MARGIN = 15
const PAN_SPEED = 1000.0

# mouse input
var mouse_captured = false
var mouse_pos = Vector2.ZERO
var mouse_global_pos = Vector2.ZERO

# camera panning
var min_position
var max_position

# selecting
var selecting = false
var select_start = Vector2.ZERO
var selected = []

func _ready():
    current = true
    set_scroll_bounds()
    position = min_position
    mouse_capture()

func set_scroll_bounds():
    var map_tile_width = 1
    var map_tile_height = 1
    while map.get_cell(map_tile_width, 0) != -1:
        map_tile_width += 1
    while map.get_cell(0, map_tile_height) != -1:
        map_tile_height += 1

    min_position = Vector2(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
    max_position = Vector2((map_tile_width * TILE_SIZE) - (SCREEN_WIDTH / 2), (map_tile_height * TILE_SIZE) - (SCREEN_HEIGHT / 2))

func _process(delta):
    handle_input()
    if mouse_captured and not selecting:
        update_camera(delta)
    if selecting:
        update()

func _draw():
    if selecting:
        draw_rect(Rect2(select_start, mouse_pos - select_start - position), Color(1, 1, 0), false)

func handle_input():
    if not mouse_captured:
        if Input.is_action_just_pressed("escape"):
            get_tree().quit()
        if Input.is_action_just_pressed("left_click"):
            mouse_capture()
        return

    if Input.is_action_just_pressed("escape"):
        mouse_free()

    mouse_pos = get_viewport().get_mouse_position()
    mouse_global_pos = get_global_mouse_position()
    if Input.is_action_just_pressed("left_click"):
        select_begin()
    if Input.is_action_just_released("left_click"):
        select_end()

    if Input.is_action_just_pressed("right_click"):
        var global_mouse_pos = get_global_mouse_position()
        for unit in selected:
            if unit.get_ref():
                unit.get_ref().command_move(global_mouse_pos)
    elif Input.is_action_just_pressed("attack_move"):
        var global_mouse_pos = get_global_mouse_position()
        for unit in selected:
            if unit.get_ref():
                unit.get_ref().command_attack_move(global_mouse_pos)

func select_begin():
    selecting = true
    select_start = mouse_pos - position

func select_end():
    selecting = false
    update()

    for unit in selected:
        if unit.get_ref():
            unit.get_ref().deselect()
    selected = []

    for unit in get_tree().get_nodes_in_group("units"):
        unit.select_ring.visible = false

    var select_rect = RectangleShape2D.new()
    select_rect.extents = (mouse_pos - select_start - position) / 2
    if select_rect.extents.x == 0:
        select_rect.extents.x = 1
    if select_rect.extents.y == 0:
        select_rect.extents.y = 1
    var select_query = Physics2DShapeQueryParameters.new()
    select_query.set_shape(select_rect)
    select_query.transform = Transform2D(0, select_start + position + select_rect.extents)
    var query_results = get_world_2d().direct_space_state.intersect_shape(select_query, 100)
    for result in query_results:
        if result.collider.is_in_group("units") and result.collider.team == 0:
            selected.append(weakref(result.collider))

    for unit in selected:
        unit.get_ref().select(selected)

func update_camera(delta):
    if mouse_pos.x <= PAN_MARGIN:
        position.x -= PAN_SPEED * delta
    elif mouse_pos.x >= SCREEN_WIDTH - PAN_MARGIN:
        position.x += PAN_SPEED * delta
    if mouse_pos.y <= PAN_MARGIN:
        position.y -= PAN_SPEED * delta
    elif mouse_pos.y >= SCREEN_HEIGHT - PAN_MARGIN:
        position.y += PAN_SPEED * delta

    position.x = clamp(position.x, min_position.x, max_position.x)
    position.y = clamp(position.y, min_position.y, max_position.y)

func mouse_capture():
    Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
    Input.set_custom_mouse_cursor(image_cursor)
    mouse_captured = true

func mouse_free():
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    Input.set_custom_mouse_cursor(null)
    mouse_captured = false
