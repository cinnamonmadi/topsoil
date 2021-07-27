extends CanvasLayer

onready var host_button = $host_button
onready var join_button = $join_button
onready var start_button = $start_button
onready var info_label = $info_label

var self_id
var opponent_id
var opponent_ready = false

func _ready():
    host_button.connect("pressed", self, "_on_host_pressed")
    join_button.connect("pressed", self, "_on_join_pressed")
    start_button.connect("pressed", self, "_on_start_pressed")
    get_tree().connect("network_peer_connected", self, "_on_peer_connected")

func _on_host_pressed():
    button_disable(host_button)
    button_disable(join_button)
    button_enable(start_button)
    info_label.visible = true
    set_info_label("waiting on other player...")

    var peer = NetworkedMultiplayerENet.new()
    peer.create_server(8001, 2)
    get_tree().network_peer = peer

    self_id = get_tree().get_network_unique_id()

func _on_join_pressed():
    button_disable(host_button)
    button_disable(join_button)
    button_enable(start_button)
    info_label.visible = true
    set_info_label("connecting...")

    var peer = NetworkedMultiplayerENet.new()
    peer.create_client('127.0.0.1', 8001)
    get_tree().network_peer = peer

    self_id = get_tree().get_network_unique_id()

func _on_peer_connected(peer_id):
    opponent_id = peer_id
    set_info_label("you are player " + str(self_id) + ". connected to player id " + str(opponent_id))

func _on_start_pressed():
    if get_tree().is_network_server():
        if opponent_ready:
            rpc("start_game")
            start_game()
    else:
        rpc("set_opponent_ready")

remote func set_opponent_ready():
    opponent_ready = true
    print(opponent_ready)
    set_info_label("opponent is ready")

remote func start_game():
    var root = get_tree().get_root()

    var old_scene = root.get_node("root")
    old_scene.call_deferred("free")

    var new_scene = load("res://main.tscn").instance()
    root.add_child(new_scene)
    var player = new_scene.get_node("player")
    player.self_id = self_id
    player.opponent_id = opponent_id

func button_disable(button):
    button.visible = false
    button.disabled = true

func button_enable(button):
    button.visible = true
    button.disabled = false

func set_info_label(value):
    info_label.text = value
