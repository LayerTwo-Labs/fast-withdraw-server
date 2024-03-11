extends Node

const DEFAULT_PORT : int = 8382
const DEFAULT_MAX_PEERS : int = 10

var peers = []

func _ready() -> void:
	print("Starting server")
	
	$"/root/Net".fast_withdraw_requested.connect(_on_fast_withdraw_requested)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# Create server
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT, DEFAULT_MAX_PEERS)
	multiplayer.multiplayer_peer = peer

	print("Server started with peer ID: ", peer.get_unique_id())
	
	
func _on_peer_connected(id : int) -> void:
	print("Peer connected!")
	peers.push_back(id)
	
	
func _on_peer_disconnected(id : int) -> void:
	print("Peer Disconnected!")
	peers.erase(id)
	

func _on_fast_withdraw_requested(amount : float) -> void:
	print("Server began handling fast withdraw request")
	
	# Check our mainchain balance is enough
	
	# Get a new sidechain address for specified sidechain
	
	# Send L2 payment address back to requester
	
	# Track withdraw request
	
	# Then we wait for them to fund the address and send us the txid
	
