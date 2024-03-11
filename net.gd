extends Node

# Server signals
signal fast_withdraw_requested(amount: float)

# Client signals

# TODO add params: SC #, MC fee, MC destination
@rpc("any_peer", "call_remote", "reliable")
func request_fast_withdraw(amount : float) -> void:
	print("Received fast withdrawal request")
	print("Amount: ", amount)
	
	fast_withdraw_requested.emit(amount)
