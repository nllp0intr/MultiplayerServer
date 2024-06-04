class_name InviteManager extends Node

@export var activeInvites : Array

signal newInvite(from, to)

class Invite:
	var inviteTo : int
	var inviteFrom : int
	var activeInvites : Array
	var inviteFromUsername
	var inviteToUsername
	
	func _init(from, to):
		self.inviteFrom = from
		self.inviteTo = to
		self.inviteToUsername = AuthManager.loggedInPlayerIds.find_key(inviteTo)
		self.inviteFromUsername = AuthManager.loggedInPlayerIds.find_key(inviteFrom)
		self.send()
	
	func send():
		MultiplayerManager.receiveInvite.rpc_id(inviteTo, inviteFromUsername, inviteFrom)
	
	func accept():
		MultiplayerManager.receiveInviteStatus.rpc_id(inviteFrom, inviteToUsername, "accept")
		MultiplayerManager.multiplayerRoundManager.createMatch([inviteFrom, inviteTo])
		
	func deny():
		MultiplayerManager.receiveInviteStatus.rpc_id(inviteFrom, inviteFromUsername, "deny")
		
	func cancel():
		MultiplayerManager.receiveInviteStatus.rpc_id(inviteTo, inviteFromUsername, "cancel")
	
func getInboundInvites(to):
	var invitesForPlayer = []
	for invite in activeInvites:
		if invite.inviteTo == to:
			invitesForPlayer.append({invite.inviteFromUsername:"username",invite.inviteFrom:"id"})
	return invitesForPlayer
	
func getOutboundInvites(from):
	var invitesFromPlayer = []
	for invite in activeInvites:
		if invite.inviteFrom == from:
			invitesFromPlayer.append({invite.inviteToUsername:"username",invite.inviteTo:"id"})
	return invitesFromPlayer

func acceptInvite(from, to):
	for invite in activeInvites:
		if invite.inviteFrom == from && invite.inviteTo == to:
			invite.accept()
			activeInvites.remove_at(activeInvites.find(invite))
			retractAllInvites(from)
			return true
	return false

func denyInvite(from, to):
	for invite in activeInvites:
		if invite.inviteFrom == from:
			invite.deny()
			activeInvites.remove_at(activeInvites.find(invite))
			return true
	return false

func retractInvite(from, to):
	for invite in activeInvites:
		if invite.inviteFrom == from && invite.inviteTo == to:
			invite.cancel()
			activeInvites.remove_at(activeInvites.find(invite))
			return true
	return false

func retractAllInvites(from):
	for invite in activeInvites:
		if invite.inviteFrom == from:
			invite.cancel()
			activeInvites.remove_at(activeInvites.find(invite))
