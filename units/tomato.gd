extends KinematicBody2D

const SPEED = 120
const MOVE_TIMEOUT = 0.4
const MIN_TARGET_DISTANCE = 8
const NODE_RESET_THRESHOLD = 16

onready var nav = get_viewport().get_node("world/nav")
onready var rays = $rays
onready var ray_front = $rays/ray0
onready var move_timer = $move_timer
onready var select_ring = $select_ring

var path = []
var target = null
var velocity = Vector2.ZERO
var stuck_position = null

var selected = false
var select_group = null

func _ready():
    move_timer.connect("timeout", self, "_on_move_timeout")
    add_to_group("units")

func _physics_process(_delta):
    if target != null:
        move()
        if (path.empty() and position.distance_to(target) < MIN_TARGET_DISTANCE) or (not path.empty() and position.distance_to(target) < NODE_RESET_THRESHOLD):
            target = null
        if target != null and move_timer.is_stopped():
            handle_colliders()
    while target == null and not path.empty():
        try_set_target()
    if target == null:
        set_collision_layer_bit(0, true)

func move():
    velocity = position.direction_to(target) * SPEED
    rays.rotation = velocity.angle()
    if ray_front.is_colliding():
        var viable_ray = get_viable_ray()
        if viable_ray:
            velocity = Vector2.RIGHT.rotated(rays.rotation + viable_ray.rotation) * SPEED
    velocity = move_and_slide(velocity)


func get_viable_ray():
    for ray in rays.get_children():
        if !ray.is_colliding():
            return ray
    return null

func handle_colliders():
    for i in get_slide_count():
        var collider = get_slide_collision(i).collider
        var collider_in_select_group = false
        for unit in select_group:
            if unit.get_ref() and unit.get_ref() == collider:
                collider_in_select_group = true
                break
        if collider_in_select_group and collider.target == null:
            stuck_position = null
            move_timer.start(MOVE_TIMEOUT)
            return
    stuck_position = position
    move_timer.start(MOVE_TIMEOUT)

func navigate_to(destination):
    target = null
    path = nav.get_simple_path(position, destination, false)

func try_set_target():
    var next_node = path[0]
    path.remove(0)
    if position.distance_to(next_node) > 9:
        target = next_node
        move_timer.stop()
        set_collision_layer_bit(0, false)

func _on_move_timeout():
    if (stuck_position != null and position.distance_to(stuck_position) < 1) or stuck_position == null:
        stuck_position = null
        target = null
        path = []

func select(group):
    selected = true
    select_group = group
    select_ring.visible = true

func deselect():
    selected = false
    select_ring.visible = false
