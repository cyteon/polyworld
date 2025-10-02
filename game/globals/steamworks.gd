extends Node

var steam_id: int
var steam_username: String

func _ready() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("[SteamWorks] %s" % initialize_response)
	
	if initialize_response.status == OK:
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()

func _process(_delta: float) -> void:
	Steam.run_callbacks()

# replacement for Steam.pingServer, that also support domains
func ping_server(host: String, port: int) -> Dictionary:
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	udp.set_dest_address(host, port)
	
	var payload: PackedByteArray = (
		PackedByteArray([0xFF, 0xFF, 0xFF, 0xFF, 0x54]) 
		+ "Source Engine Query".to_utf8_buffer() 
		+ PackedByteArray([0x00]))
	udp.put_packet(payload)
	
	var timeout: float = 2.0
	var start_time = Time.get_ticks_msec()
	
	while Time.get_ticks_msec() - start_time < int(timeout * 1000):
		if udp.get_available_packet_count() > 0:
			var packet: PackedByteArray = udp.get_packet()
			
			if packet[4] == 0x41:
				print("[SteamWorks] Got challenge packet request while querying server")
				
				var retry: PackedByteArray = payload + packet.slice(5, packet.size())
				udp.put_packet(retry)
				
				start_time = Time.get_ticks_msec()
			elif packet[4] == 0x49:
				print("[SteamWorks] Got server query response")
				
				var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
				buffer.data_array = packet
				buffer.seek(4)
				
				var data = {
					"header": buffer.get_u8(),
					"protocol": buffer.get_u8(),
					"name": read_str(buffer),
					"map": read_str(buffer),
					"folder": read_str(buffer),
					"game": read_str(buffer),
					"app_id": buffer.get_u16(),
					"players": buffer.get_u8(),
					"max_players": buffer.get_u8(),
					"bots": buffer.get_u8(),
					"server_type": char(buffer.get_u8()),
					"server_os": char(buffer.get_u8()),
					"requires_password": int(buffer.get_u8()) == 1,
					"vac": int(buffer.get_u8()) == 1,
					"version": read_str(buffer),
					"edf": buffer.get_u8(),
					"ping": Time.get_ticks_msec() - start_time
				}
				
				if data.edf & 0x80:
					data["port"] = buffer.get_u16()
				
				if data.edf & 0x10:
					data["steam_id"] = buffer.get_u64()
				
				if data.edf & 0x20:
					data["keywords"] = read_str(buffer)
				
				if data.edf & 0x01:
					data["app_id"] = buffer.get_u32()
				
				return data
	
	print("[SteamWorks] Querying server info timed out")
	
	return {}

func read_str(buffer: StreamPeerBuffer) -> String:
	var result := ""

	while buffer.get_position() < buffer.data_array.size():
		var byte := buffer.get_u8()
		
		if byte == 0:
			break
			
		result += char(byte)

	return result
