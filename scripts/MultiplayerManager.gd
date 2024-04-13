extends Node

# Autoload named Lobby

# These signals can be connected to by a UI lobby scene or the game scene.
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

const PORT = 2244
const DEFAULT_SERVER_IP = "localhost" # IPv4 localhost
const MAX_CONNECTIONS = 1000

# This will contain player info for every player,
# with the keys being each player's unique IDs.
var players = {}
var public_lobbies = {}
var private_lobbies = {}

# This is the local player info. This should be modified locally
# before the connection is made. It will be passed to every other peer.
# For example, the value of "name" can be set to something the player
# entered in a UI scene.
var player_info = {"name": "Name"}
var characters = 'qwertyuiopasdfgjklzxcvbnm123456789QWERTYUIOPASDFGJKLZXCVBNMM'
var join_code_chars = 'qwertyuiopasdfghjklzxcvbnm'
var players_loaded = 0

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	create_game()

func _input(ev):
	if Input.is_key_pressed(KEY_N):
		print("CURRENT PLAYERS LOADED: %s" % players_loaded)
	if Input.is_key_pressed(KEY_P):
		print("PLAYERS CONNECTED:")
		for entry in players:
			print("\t%s" % str(entry))

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	multiplayer.multiplayer_peer = peer
	print("CREATED SERVER")

@rpc("any_peer")
func request_lobby_list():
	recieve_lobby_list.rpc(public_lobbies)

func remove_multiplayer_peer():
	multiplayer.multiplayer_peer = null

# Every peer will call this when they have loaded the game scene.
func player_loaded():
	if multiplayer.is_server():
		players_loaded += 1

# When a peer connects, send them my player info.
# This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)
	print("Player %s connected" % new_player_id)
	player_loaded()

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()
	
@rpc("any_peer", "reliable")
func create_lobby(max_players, turn_type, lobby_type):
	var lobby_id = generate_ID(characters, 20)
	var lobby_join_code = generate_ID(join_code_chars, 5)
	var lobby_info = {"host" : multiplayer.get_remote_sender_id(), "players" : [multiplayer.get_remote_sender_id()], "max players" : max_players, "turn type": turn_type, "lobby_type" : lobby_type, "join_code" : lobby_join_code}
	if lobby_type == "public":
		public_lobbies[lobby_id] = lobby_info
	else:
		private_lobbies[lobby_id] = lobby_info
	print("CREATED NEW %s LOBBY %s:\n\t%s" % [lobby_info["lobby_type"],lobby_id, lobby_info])
	recieve_lobby_id.rpc(lobby_id)
	
func generate_ID(chars, length):
	var word: String
	var n_char = len(chars)
	for i in range(length):
		word += chars[randi()% n_char]
	return word
	
@rpc("any_peer")
func close_lobby(id):
	public_lobbies.erase(id)
	private_lobbies.erase(id)
	print("ERASED LOBBY %s" % id)
	
@rpc("any_peer")
func recieve_lobby_list(): pass

@rpc("any_peer")
func recieve_lobby_id(): pass
