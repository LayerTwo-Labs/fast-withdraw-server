extends Node

const DEFAULT_PORT : int = 8382
const DEFAULT_MAX_PEERS : int = 10

const MAINCHAIN_RPC_PORT = 18443
const RPC_USER : String = "user"
const RPC_PASS : String = "password"

var peers = []

var mainchain_balance : float = 0.0

signal mainchain_balance_updated

@onready var get_mainchain_balance_request: HTTPRequest = $HTTPRequestGetBalanceMainchain 

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
	request_mainchain_balance()
	await mainchain_balance_updated
	
	print("Mainchain balance: ", mainchain_balance)
	
	# Check our mainchain balance is enough
	
	# Get a new sidechain address for specified sidechain
	
	# Send L2 payment address back to requester
	
	# Track withdraw request
	
	# Then we wait for them to fund the address and send us the txid
	
	
func request_mainchain_balance():
	make_mainchain_rpc_request("getbalance", [], get_mainchain_balance_request)
	
	
func make_mainchain_rpc_request(method: String, params: Variant, http_request: HTTPRequest):
	var auth = RPC_USER + ":" + RPC_PASS
	var auth_bytes = auth.to_utf8_buffer()
	var auth_encoded = Marshalls.raw_to_base64(auth_bytes)
	var headers: PackedStringArray = []
	headers.push_back("Authorization: Basic " + auth_encoded)
	headers.push_back("content-type: application/json")
	
	var jsonrpc := JSONRPC.new()
	var req = jsonrpc.make_request(method, params, 1)
	
	http_request.request("http://127.0.0.1:" + str(MAINCHAIN_RPC_PORT), headers, HTTPClient.METHOD_POST, JSON.stringify(req))


func get_result(response_code, body) -> Dictionary:
	var res = {}
	var json = JSON.new()
	if response_code != 200:
		if body != null:
			var err = json.parse(body.get_string_from_utf8())
			if err == OK:
				print(json.get_data())
	else:
		var err = json.parse(body.get_string_from_utf8())
		if err == OK:
			res = json.get_data() as Dictionary
	
	return res
	

func _on_http_request_get_balance_mainchain_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var res = get_result(response_code, body)
	if res.has("result"):
		print("Result: ", res.result)
		mainchain_balance = res.result
	else:
		print("result error")
		
	mainchain_balance_updated.emit()
