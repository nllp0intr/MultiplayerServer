extends Node

const MultiplayerRoundManager = preload("res://scripts/MultiplayerRoundManager.gd")
const InviteManager = preload("res://scripts/InviteManager.gd")
var multiplayerRoundManager
var inviteManager

func _ready():
	multiplayer.server_relay = false
	
	multiplayerRoundManager = MultiplayerRoundManager.new()
	multiplayerRoundManager.name = "MultiplayerRoundManager"
	add_child(multiplayerRoundManager)
	
	inviteManager = InviteManager.new()
	inviteManager.name = "InviteManager"
	add_child(inviteManager)
	
	_createServer()

func _createServer():
	var multiplayerPeer = ENetMultiplayerPeer.new()
	var error = multiplayerPeer.create_server(2095, 1000)
	if error:
		return error
	multiplayer.multiplayer_peer = multiplayerPeer
	print("CREATED SERVER")

func terminateSession(id, reason : String):
	print("%s: %s" % [id, reason])
	closeSession.rpc_id(id, reason)
	await get_tree().create_timer(5, false).timeout
	multiplayer.multiplayer_peer.disconnect_peer(id, true)

@rpc("any_peer", "reliable")
func requestNewUser(username : String):
	var key = AuthManager._CreateNewUser(username)
	if typeof(key) != TYPE_STRING:
		match key:
			-1:
				terminateSession(multiplayer.get_remote_sender_id(), "invalidUsername")
				return
			-2:
				terminateSession(multiplayer.get_remote_sender_id(), "userAlreadyExists")
				return
			-3:
				terminateSession(multiplayer.get_remote_sender_id(), "databaseError")
				return
	receivePrivateKey.rpc_id(multiplayer.get_remote_sender_id(), key)

@rpc("any_peer")
func verifyUserCreds(keyFileData : PackedByteArray):
	var keyFileDataString = keyFileData.get_string_from_utf8().split(":")
	if len(keyFileDataString) != 2:
		terminateSession(multiplayer.get_remote_sender_id(), "malformedKey")
		return
	var keyData = keyFileDataString[0]
	var username = keyFileDataString[1]
	var verified = AuthManager._verifyKeyFile(username, keyData)
	if verified != 0:
		match verified:
			-1:
				terminateSession(multiplayer.get_remote_sender_id(), "nonExistentUser")
				return
			-2:
				terminateSession(multiplayer.get_remote_sender_id(), "invalidCreds")
				return
	AuthManager._loginToUserAccount(username)

@rpc("any_peer")
func requestPlayerList():
	receivePlayerList.rpc_id(multiplayer.get_remote_sender_id(), AuthManager.loggedInPlayerIds)
	
#@rpc("any_peer")
#func requestUserExistsStatus(username : String):
	#print("requesting status of " + username)
	#if len(AuthManager._checkUserExists(username.to_lower())) > 0:
		#terminateSession(multiplayer.get_remote_sender_id(), "userExists")
		#return false
	#terminateSession(multiplayer.get_remote_sender_id(), "nonexistentUser")

@rpc("any_peer")
func createInvite(to):
	var invite = inviteManager.Invite.new(multiplayer.get_remote_sender_id(), to)
	inviteManager.activeInvites.append(invite)
	
@rpc("any_peer")
func acceptInvite(from):
	if !inviteManager.acceptInvite(from, multiplayer.get_remote_sender_id()):
		print("This user does not have an invite from %s" % from)

@rpc("any_peer")
func denyInvite(from):
	if !inviteManager.denyInvite(from, multiplayer.get_remote_sender_id()):
		print("This user does not have an invite from %s" % from)
		
@rpc("any_peer") 
func retractInvite(to): 
	inviteManager.retractInvite(multiplayer.get_remote_sender_id(), to)
	
@rpc("any_peer") 
func retractAllInvites(): 
	inviteManager.retractAllInvites(multiplayer.get_remote_sender_id())
	
@rpc("any_peer")
func getInvites(type):
	var list
	match type:
		"incoming":
			list = inviteManager.getInboundInvites(multiplayer.get_remote_sender_id())
		"outgoing":
			list = inviteManager.getOutboundInvites(multiplayer.get_remote_sender_id())
	receiveInviteList.rpc_id(multiplayer.get_remote_sender_id(), list)
	
# GHOST FUNCTIONS
@rpc("any_peer") func closeSession(reason): pass
@rpc("any_peer") func receiveUserCreationStatus(return_value: bool, username): pass
@rpc("any_peer") func notifySuccessfulLogin(username : String): pass
@rpc("any_peer") func receivePrivateKey(keyString): pass 
@rpc("any_peer") func receivePlayerList(dict): pass
@rpc("any_peer") func receiveInvite(from, id): pass
@rpc("any_peer") func receiveInviteStatus(username, status): pass
@rpc("any_peer") func receiveInviteList(list): pass
@rpc("any_peer") func opponentDisconnect(): pass
