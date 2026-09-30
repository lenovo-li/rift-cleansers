class_name NetConfig extends RefCounted
## 联机启动参数（菜单或命令行设置，跨场景重载保留）。
## 命令行（写在 -- 之后）：--host  --join=IP  --port=N  --lag=毫秒（单向模拟延迟）
##   --name=名字  --token=重连令牌  --char=角色 id  --map=地图 id  --bot（本地玩家由机器人控制，测试用）

enum Mode { SINGLE, HOST, CLIENT }

const DEFAULT_PORT: int = 24570
const MAX_CLIENTS: int = 3

static var mode: Mode = Mode.SINGLE
static var address: String = "127.0.0.1"
static var port: int = DEFAULT_PORT
static var lag_ms: int = 0
static var player_name: String = "玩家"
static var reconnect_token: String = ""
static var bot: bool = false
## 本地玩家选的角色（CharacterCatalog），单人和联机都用。
static var character_id: String = "iron_guard"
## 地图（MapCatalog）。联机时以主机为准：客户端 hello 带上自己的地图，不一致时主机回复 rpc_map 让客户端换图重进。
static var map_id: String = "ashen_city"
static var _parsed: bool = false


static func is_client() -> bool:
	return mode == Mode.CLIENT


static func is_host() -> bool:
	return mode == Mode.HOST


static func is_online() -> bool:
	return mode != Mode.SINGLE


## 解析命令行（只解析一次，之后菜单可以覆盖）。返回是否指定了联机模式。
static func parse_cmdline() -> bool:
	if _parsed:
		return mode != Mode.SINGLE
	_parsed = true
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--host":
			mode = Mode.HOST
		elif arg.begins_with("--join="):
			mode = Mode.CLIENT
			address = arg.get_slice("=", 1)
		elif arg.begins_with("--port="):
			port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--lag="):
			lag_ms = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--name="):
			player_name = arg.get_slice("=", 1)
		elif arg.begins_with("--token="):
			reconnect_token = arg.get_slice("=", 1)
		elif arg.begins_with("--char="):
			var c: String = arg.get_slice("=", 1)
			if CharacterCatalog.is_valid(c):
				character_id = c
		elif arg.begins_with("--map="):
			var m: String = arg.get_slice("=", 1)
			if MapCatalog.is_valid(m):
				map_id = m
		elif arg == "--bot":
			bot = true
	if reconnect_token.is_empty():
		reconnect_token = generate_token()
	return mode != Mode.SINGLE


static func generate_token() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]


static func reset() -> void:
	mode = Mode.SINGLE
	lag_ms = 0
	bot = false
