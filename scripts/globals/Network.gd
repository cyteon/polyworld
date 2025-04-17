extends Node

# will be used to see if server compatable with client
const compatability_ver: int = 1
const backend_url: String = "https://polyworld.xyz"

# -- Other -- #

func ping_server(host: String, port: int) -> Dictionary:
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	var timeout: float = 2.0
	
	udp.set_dest_address(host, port)
	
	var payload: PackedByteArray = (
		PackedByteArray([0xFF, 0xFF, 0xFF, 0xFF, 0x54]) 
		+ "Source Engine Query".to_utf8_buffer() 
		+ PackedByteArray([0x00]))
	
	udp.put_packet(payload)
	
	var start_time = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_time < int(timeout * 1000):
		if udp.get_available_packet_count() > 0:
			var packet: PackedByteArray = udp.get_packet()
			
			if packet[4] == 0x41:
				var retry: PackedByteArray = payload + packet.slice(5, packet.size())
				udp.put_packet(retry)
				
				start_time = Time.get_ticks_msec()
			elif packet[4] == 0x49:
				print(packet.hex_encode())
				var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
				buffer.data_array = packet
				buffer.seek(4)
				
				var header = buffer.get_u8()
				var protocol = buffer.get_u8()
				var name_ = _read_str(buffer)
				var map = _read_str(buffer)
				var folder = _read_str(buffer)
				var game = _read_str(buffer)
				var app_id = buffer.get_u16()
				var players = buffer.get_u8()
				var max_players = buffer.get_u8()
				var bots = buffer.get_u8()
				var server_type = char(buffer.get_u8())
				var os = _read_str(buffer)
				var vac = buffer.get_u8()
				#var password = buffer.get_u8()
				var version = _read_str(buffer)
				var edf = buffer.get_u8()
				
				# other stuff
				var port_ = 0
				var steamID = 0
				var keywords = ""
				
				if edf & 0x80:
					port_ = buffer.get_u16()
				
				if edf & 0x10:
					steamID = buffer.get_u64()
				
				if edf & 0x20:
					keywords = _read_str(buffer)
				
				if edf & 0x01:
					app_id = buffer.get_u32()
				
				print("protocol: %s" % protocol)
				print("header: %s" % header)
				print("name: %s" % name_)
				print("map: %s" % map)
				print("folder: %s" % folder)
				print("game: %s" % game)
				print("app_id: %s" % app_id)
				print("players: %s" % players)
				print("max_players: %s" % max_players)
				print("bots: %s" % bots)
				print("server_type: %s" % server_type)
				print("os: %s" % os)
				#print("password: %s" % password)
				print("vac: %s" % vac)
				print("version: %s" % version)
				print("edf: %s" % edf)
				print("other:")
				print("port: %s" % port_)
				print("steamID: %s" % steamID)
				print("keywords: %s" % keywords)
	
	print("[Client] Server ping timeouted")
	
	return {}

func _read_str(buffer: StreamPeerBuffer) -> String:
	var result := ""
	
	while buffer.get_position() < buffer.data_array.size():
		var byte := buffer.get_u8()
		
		if byte == 0:
			break
			
		result += char(byte)
	
	return result

# -- Hybrid -- #
# aka: Server/Client -> Server/Client

signal despawn_item(path: NodePath)
signal spawn_item(bytes: PackedByteArray, name_: String) 

@rpc("any_peer", "call_local")
func _despawn_item(path: NodePath):
	despawn_item.emit(path)

@rpc("any_peer", "call_remote")
func _spawn_item(bytes: PackedByteArray, name_: String):
	spawn_item.emit(bytes, name_)

# -- Client -> Client -- #
signal play_item_anim(peer: int)
signal set_holding(peer: int, scene: String) 
signal ready_to_send_to(id: int)

@rpc("any_peer", "call_remote")
func _play_item_anim(peer: int):
	play_item_anim.emit(peer)

# server will also recieve this and store it for syncing reasons
@rpc("any_peer", "call_remote")
func _set_holding(peer: int, scene: String):
	set_holding.emit(peer, scene)

@rpc("any_peer", "call_remote")
func _ready_to_send_to(id: int):
	ready_to_send_to.emit(id)

# -- Server -> Client -- #
signal disconnected(reason: String, details: String)
signal authentication_ok()
signal add_players(ids)
signal remove_player(id: int)
signal take_damage(damage: int)
signal spawn_scene(node: NodePath, scene: String, position: Vector3, name_: String)
signal set_state(position: Vector3, health: int, stamina: float, hunger: float, hotbar: PackedByteArray, inventory: PackedByteArray)

@rpc("authority")
func _disconnect(reason: String, details: String):
	print("[Client] Disconnected from server with reason: %s" % reason)
	disconnected.emit(reason, details)

@rpc("authority")
func _authentication_ok():
	authentication_ok.emit()

@rpc("authority")
func _add_players(ids):
	add_players.emit(ids)

@rpc("authority")
func _remove_player(id):
	remove_player.emit(id)

@rpc("authority")
func _take_damage(damage: int):
	take_damage.emit(damage)

@rpc("authority")
func _spawn_scene(node: NodePath, scene: String, position: Vector3, name_: String):
	spawn_scene.emit(node, scene, position, name_)

@rpc("authority")
func _set_state(position: Vector3, health: int, stamina: float, hunger: float, hotbar: PackedByteArray, inventory: PackedByteArray):
	set_state.emit(position, health, stamina, hunger, hotbar, inventory)

# -- Client -> Server -- #

signal world_loaded()
signal authenticate(unique_id: Variant, auth_ticket: Dictionary)
signal attack_player(target_id: int, damage: int)
signal attack_entity(entity: NodePath, damage: int)
signal inv_data(hotbar: PackedByteArray, inventory: PackedByteArray)

@rpc("any_peer", "call_remote")
func _world_loaded():
	world_loaded.emit()

@rpc("any_peer", "call_remote")
func _authenticate(unique_id: Variant, auth_ticket: Dictionary):
	authenticate.emit(unique_id, auth_ticket)

@rpc("any_peer", "call_remote")
func _attack_player(target_id: int, damage: int):
	attack_player.emit(target_id, damage)

@rpc("any_peer", "call_remote")
func _attack_entity(entity: NodePath, damage: int):
	attack_entity.emit(entity, damage)

@rpc("any_peer", "call_remote")
func _inv_data(hotbar: PackedByteArray, inventory: PackedByteArray):
	inv_data.emit(hotbar, inventory)
