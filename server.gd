extends Node

const DEFAULT_PORT : int = 8382
const DEFAULT_MAX_PEERS : int = 10

const MAINCHAIN_RPC_PORT = 18443
const TESTCHAIN_RPC_PORT = 18743
const RPC_USER : String = "user"
const RPC_PASS : String = "pass"

var peers = []
var pending_requests = []

var mainchain_balance : float = 0.0

# TODO store with pending requests
var testchain_address : String = ""
var testchain_payment_transaction : Dictionary
var mainchain_payout_txid : String = ""

signal mainchain_balance_updated
signal generated_testchain_address
signal received_testchain_transaction_result
signal mainchain_sendtoaddress_txid_result

@onready var http_rpc_mainchain_getbalance: HTTPRequest = $HTTPRequestGetBalanceMainchain 
@onready var http_rpc_mainchain_sendtoaddress: HTTPRequest = $HTTPRequestSendToAddressMainchain
@onready var http_rpc_testchain_getnewaddress: HTTPRequest = $HTTPRequestGetTestchainAddress
@onready var http_rpc_testchain_gettransaction: HTTPRequest = $HTTPRequestGetTestchainTransaction


func _ready() -> void:
	print("Starting server")
	
	$"/root/Net".fast_withdraw_requested.connect(_on_fast_withdraw_requested)
	$"/root/Net".fast_withdraw_invoice_paid.connect(_on_fast_withdraw_invoice_paid)
	
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


# TODO make this work asynchronously - remove await
func _on_fast_withdraw_requested(peer_id : int, amount : float, destination: String) -> void:
	print("Server began handling fast withdraw request")
	print("Peer: ", peer_id)
	print("Amount: ", amount)
	print("Mainchain destination: ", destination)
	rpc_mainchain_getbalance()
	await mainchain_balance_updated
	
	print("Mainchain balance: ", mainchain_balance)
	
	# Check our mainchain balance is enough
	if mainchain_balance < amount:
		printerr("Insufficient mainchain balance for trade!")
		return
	
	# Get a new sidechain address for specified sidechain
	rpc_testchain_getnewaddress()
	await generated_testchain_address
	
	print("New testchain address generated for trade invoice: ", testchain_address)
	
	# Create and store invoice, send instructions to client for completion
	
	pending_requests.push_back([peer_id, testchain_address, amount, destination])
	
	print("Sending invoice to requesting peer")

	$"/root/Net".receive_fast_withdraw_invoice.rpc_id(peer_id, amount, testchain_address)


# TODO make this work asynchronously - remove await
func _on_fast_withdraw_invoice_paid(peer_id : int, txid : String, amount : float, destination: String) -> void:
	print("Client claims to have paid invoice")
	print("Peer: ", peer_id)
	print("TxID: ", txid)
	print("Amount: ", amount)
	print("Mainchain destination: ", destination)
	
	# Lookup invoice
	# TODO change containers improve lookup - test only
	var invoice_paid = null
	for invoice in pending_requests:
		if invoice[0] == peer_id && invoice[2] == amount && invoice[3] == destination:
			invoice_paid = invoice
			break
	
	if invoice_paid == null:
		printerr("No matching invoice found!")
		return
	
	# Check if paid
	testchain_payment_transaction.clear()
	rpc_testchain_gettransaction(txid)
	await received_testchain_transaction_result
	
	if testchain_payment_transaction.is_empty():
		printerr("No payment transaction found!")
		return
	
	# Verify that transaction paid invoice amount to our L2 address
	var payment_found : bool = false
	for output in testchain_payment_transaction["details"]:
		print("Output:",  output)
		if output["address"] == testchain_address and output["amount"] >= invoice_paid[2]:
			payment_found = true
			break
			
	if not payment_found:
		printerr("Payment not found in transaction!")
		return
			
	# Pay client peer and erase invoice
	
	rpc_mainchain_sendtoaddress(amount, destination)
	await mainchain_sendtoaddress_txid_result
	
	pending_requests.erase(invoice_paid)
	
	$"/root/Net".withdraw_complete.rpc_id(peer_id, mainchain_payout_txid, amount, "mupCLTxooxrc35Ufp9sKbks3FJPRBRSJvD")
	

func rpc_mainchain_getbalance() -> void:
	make_mainchain_rpc_request("getbalance", [], http_rpc_mainchain_getbalance)


func rpc_testchain_getnewaddress() -> void:
	make_testchain_rpc_request("getnewaddress", ["", "legacy"], http_rpc_testchain_getnewaddress)


func rpc_testchain_gettransaction(txid : String) -> void:
	make_testchain_rpc_request("gettransaction", [txid], http_rpc_testchain_gettransaction)


func rpc_mainchain_sendtoaddress(amount : float, address : String) -> void:
	make_mainchain_rpc_request("sendtoaddress", [address, amount], http_rpc_mainchain_sendtoaddress)


func make_mainchain_rpc_request(method: String, params: Variant, http_request: HTTPRequest) -> void:
	var auth = RPC_USER + ":" + RPC_PASS
	var auth_bytes = auth.to_utf8_buffer()
	var auth_encoded = Marshalls.raw_to_base64(auth_bytes)
	var headers: PackedStringArray = []
	headers.push_back("Authorization: Basic " + auth_encoded)
	headers.push_back("content-type: application/json")
	
	var jsonrpc := JSONRPC.new()
	var req = jsonrpc.make_request(method, params, 1)
	
	http_request.request("http://127.0.0.1:" + str(MAINCHAIN_RPC_PORT), headers, HTTPClient.METHOD_POST, JSON.stringify(req))


func make_testchain_rpc_request(method: String, params: Variant, http_request: HTTPRequest) -> void:
	var auth = RPC_USER + ":" + RPC_PASS
	var auth_bytes = auth.to_utf8_buffer()
	var auth_encoded = Marshalls.raw_to_base64(auth_bytes)
	var headers: PackedStringArray = []
	headers.push_back("Authorization: Basic " + auth_encoded)
	headers.push_back("content-type: application/json")
	
	var jsonrpc := JSONRPC.new()
	var req = jsonrpc.make_request(method, params, 1)
	
	http_request.request("http://127.0.0.1:" + str(TESTCHAIN_RPC_PORT), headers, HTTPClient.METHOD_POST, JSON.stringify(req))


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


func _on_http_request_get_balance_mainchain_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var res = get_result(response_code, body)
	if res.has("result"):
		print("Result: ", res.result)
		mainchain_balance = res.result
	else:
		print("result error")
		mainchain_balance = 0
		
	mainchain_balance_updated.emit()


func _on_http_request_get_testchain_address_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var res = get_result(response_code, body)
	if res.has("result"):
		print("Result: ", res.result)
		testchain_address = res.result
	else:
		print("result error")
		testchain_address = ""
		
	generated_testchain_address.emit()


func _on_http_request_get_testchain_transaction_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var res = get_result(response_code, body)
	if res.has("result"):
		print("Result: ", res.result)
		testchain_payment_transaction = res.result
	else:
		print("result error")
		testchain_payment_transaction.clear()
		
	received_testchain_transaction_result.emit()


func _on_http_request_send_to_address_mainchain_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var res = get_result(response_code, body)
	if res.has("result"):
		print("Result: ", res.result)
		mainchain_payout_txid = res.result
	else:
		print("result error")
		mainchain_payout_txid = ""
		
	mainchain_sendtoaddress_txid_result.emit()
