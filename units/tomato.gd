extends KinematicBody2D

enum {
    STATE_IDLE,
    STATE_MOVING,
    STATE_ATTACK_MOVING,
    STATE_ENGAGING,
    STATE_ATTACKING
    }

const SPEED = 120
const MOVE_TIMEOUT = 0.4
const MIN_TARGET_DISTANCE = 8
const NODE_RESET_THRESHOLD = 16
const ATTACK_RANGE = 200

onready var nav = get_viewport().get_node("world/nav")
onready var rays = $rays
onready var ray_front = $rays/ray0
onready var stop_timer = $stop_timer
onready var sprite = $sprite
onready var select_ring = $select_ring

export var team = 0

var state = STATE_IDLE

# pathfinding
var path = []
var target = null
var target_enemy = null
var velocity = Vector2.ZERO
var stuck_position = null

# selection
var selected = false
var select_group = []

# health
var health = 10

var attack_distance = 0

func _ready():
    stop_timer.connect("timeout", self, "_on_move_timeout")
    sprite.connect("animation_finished", self, "_on_animation_finished")
    add_to_group("units")

func set_state(new_state):
    state = new_state
    if state == STATE_IDLE:
        sprite.play("idle")
        set_collision_layer_bit(0, true)
    elif state == STATE_MOVING or state == STATE_ATTACK_MOVING or state == STATE_ENGAGING:
        sprite.play("move")
        set_collision_layer_bit(0, false)
    elif state == STATE_ATTACKING:
        sprite.play("attack")
        set_collision_layer_bit(0, true)

func select(group):
    selected = true
    select_group = group
    select_ring.visible = true

func deselect():
    selected = false
    select_ring.visible = false

func command_move(destination):
    set_state(STATE_MOVING)
    navigate_to(destination)

func command_attack_move(destination):
    set_state(STATE_ATTACK_MOVING)
    navigate_to(destination)

func command_engage(enemy):
    set_state(STATE_ENGAGING)
    target_enemy = enemy
    select_group = []

func _physics_process(_delta):
    if state == STATE_IDLE:
        sprite.play("idle")
        pass
    elif state == STATE_MOVING or state == STATE_ATTACK_MOVING:
        if target == null:
            try_set_target()
        if target == null:
            set_state(STATE_IDLE)
        else:
            move_with_avoidance()
            var nearest_enemy = null
            if state == STATE_ATTACK_MOVING:
                nearest_enemy = try_find_nearest_enemy(get_destination())
            if nearest_enemy != null:
                command_engage(nearest_enemy)
            elif reached_target():
                target = null
            elif stop_timer.is_stopped():
                handle_colliders()
    elif state == STATE_ENGAGING:
        if not target_enemy.get_ref():
            var nearest_enemy = try_find_nearest_enemy(position)
            if nearest_enemy == null:
                set_state(STATE_IDLE)
            else:
                command_engage(nearest_enemy)
        if target_enemy.get_ref():
            target = target_enemy.get_ref().position
            move_with_avoidance()
            if reached_enemy_target():
                stop_timer.stop()
                attack_distance = target_enemy.get_ref().position.distance_to(position)
                set_state(STATE_ATTACKING)
            else:
                handle_colliders()

func move_with_avoidance():
    sprite.play("move")
    velocity = position.direction_to(target) * SPEED
    rays.rotation = velocity.angle()
    if ray_front.is_colliding():
        var viable_ray = get_viable_ray()
        if viable_ray:
            velocity = Vector2.RIGHT.rotated(rays.rotation + viable_ray.rotation) * SPEED
    velocity = move_and_slide(velocity)

func reached_target():
    if path.empty():
        return position.distance_to(target) < MIN_TARGET_DISTANCE
    else:
        return position.distance_to(target) < NODE_RESET_THRESHOLD

func reached_enemy_target():
    for i in get_slide_count():
        if get_slide_collision(i).collider == target_enemy.get_ref():
            return true
    return false

func try_find_nearest_enemy(destination):
    if position.distance_to(destination) > ATTACK_RANGE:
        return null
    var nearest_enemy = null
    var nearest_enemy_dist = 0
    for unit in get_tree().get_nodes_in_group("units"):
        if unit.team == team:
            continue
        var enemy_dist = unit.position.distance_to(position)
        if enemy_dist > ATTACK_RANGE:
            continue
        if nearest_enemy == null or enemy_dist < nearest_enemy_dist:
            nearest_enemy = weakref(unit)
            nearest_enemy_dist = enemy_dist
    return nearest_enemy

func get_destination():
    if path.empty():
        return target
    else:
        return path[path.size() - 1]

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
            stop_timer.start(MOVE_TIMEOUT)
            return
    stuck_position = position
    stop_timer.start(MOVE_TIMEOUT)

func navigate_to(destination):
    target = null
    path = nav.get_simple_path(position, destination, false)

func try_set_target():
    while not path.empty():
        var next_node = path[0]
        path.remove(0)
        if position.distance_to(next_node) > 9:
            target = next_node
            stop_timer.stop()
            return

func _on_move_timeout():
    if (stuck_position != null and position.distance_to(stuck_position) < 1) or stuck_position == null:
        stuck_position = null
        target = null
        path = []

func _on_animation_finished():
    if state == STATE_ATTACKING:
        if target_enemy.get_ref() and target_enemy.get_ref().position.distance_to(position) <= attack_distance + 2:
            target_enemy.get_ref().take_damage(2, self)
        set_state(STATE_ENGAGING)

func take_damage(damage, _attacker):
    health -= damage
    if health <= 0:
        queue_free()
