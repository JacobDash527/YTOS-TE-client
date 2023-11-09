extends Node2D
#TODO:
#Add IDs for status, command and game terminals per hacker
#Add chat functionality to send only to matching team colours

#Server listening port
const PORT = 9876

#Create the WebSocketServer instance
var _server = WebSocketServer.new()

var Hacker = load("res://Hacker.tscn")
var Telnet = load("res://TelnetGame.tscn")

#Clients stores connection id numbers as key and corresponding player name as value
var clients = {}
#Players stores player name as key and corresponding player object as value
var players = {}
#Games stores the hacker game scene as the value
var games = {}
var games_scenes = {}

var keywords = ["TANAGER", "PERFECT", "TOUCHPAPER", "BRIDEWELL", "CANDLEFLAME", "BARROW", "HARROW", "DRUMFIRE", "SEACHANGE", "PRIORITY", "VOTIVE", "RADIOSTATIC", "HIATUS", "REDSKY", "BOREA", "BELLWETHER", "INDIGOBIRD", "MINUTEHAND", "GLACIER", "BITTERTASTE", "SOFTPOINT", "UMBRAL", "DOWNRIVER", "GABARDINE", "CENTERPOINT", "OVERWINTER", "STAINEDGLASS", "BREAKNECK", "FLASHOVER", "MOONSTONE", "OREBODY", "GHOSTNOTE", "WEATHEREYE", "REDSHIFT"]

#Dummy keyword for testing
var keyword = keywords[randi() % len(keywords)]

var warm_colours = ["RED", "YELLOW", "ORANGE", "TOMATO", "VOLCANO", "SUMMER", "FLAMINGO", "SUNSET", "NEONRED", "MARISCHINO"]
var cool_colours = ["BLUE", "GREEN", "RIVER", "SEAFOAM", "BLIZZARD", "SKY", "AQUATIC", "ALGAE", "ARCTIC", "ELECTRICCYAN", "TURQUOISE"]

var green_score = 0
var orange_score = 0

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

const WAITING: int = 0
const IN_PROGRESS: int = 1
const ENDED_GREEN_WIN: int = 2
const ENDED_ORANGE_WIN: int = 3

var game_state = 0

func _ready():
    randomize()
    # Connect base signals to get notified of new client connections,
    # disconnections, and disconnect requests.
    _server.connect("client_connected", self, "_connected")
    _server.connect("client_disconnected", self, "_disconnected")
    _server.connect("client_close_request", self, "_close_request")
    # This signal is emitted when not using the Multiplayer API every time a
    # full packet is received.
    # Alternatively, you could check get_peer(PEER_ID).get_available_packets()
    # in a loop for each connected peer.
    _server.connect("data_received", self, "_on_data")
    # Start listening on the given port.
    var err = _server.listen(PORT)
    if err != OK:
        print("Unable to start server")
        set_process(false)
    $CanvasLayer/Panel/IPLabel.text = 'Server IP/s: '
    for address in IP.get_local_addresses():
        if (address.split('.').size() == 4) and not (address.begins_with('169') or address.begins_with('127')):
            $CanvasLayer/Panel/IPLabel.text += ' ( ' + address + ' ) '
    
    rng.randomize()
    
    #Set up dummy telnet terminal
    var telnet_dummy = Telnet.instance()
    add_child(telnet_dummy)
    games["192.168.1.100"] = telnet_dummy
    var environment_variables = telnet_dummy.environment_variables.keys()
    var keyword_hiding_place = environment_variables[randi() % len(environment_variables)]
    telnet_dummy.set_keyword(keyword_hiding_place, keyword)
    
func _connected(id, proto):
    # This is called when a new peer connects, "id" will be the assigned peer id,
    # "proto" will be the selected WebSocket sub-protocol (which is optional)
    var cnx = "Client %d connected with protocol: %s" % [id, proto]
    $CanvasLayer/Panel/ConnectionsLabel.text = cnx

func _close_request(id, code, reason):
    # This is called when a client notifies that it wishes to close the connection,
    # providing a reason string and close code.
    var cnx = "Client %d disconnecting with code: %d, reason: %s" % [id, code, reason]
    $CanvasLayer/Panel/ConnectionsLabel.text = cnx

#If a single terminal disconnects, kick all that player's terminals.
func _disconnected(connection_id, was_clean = false):
    # This is called when a client disconnects, "id" will be the one of the
    # disconnecting client, "was_clean" will tell you if the disconnection
    # was correctly notified by the remote peer before closing the socket.
    if clients.has(connection_id):
        var hacker_name = clients[connection_id]
        #Check in players first
        var player = players[hacker_name]
        $CanvasLayer/Panel/ConnectionsLabel.text = "Client %d disconnected, clean: %s" % [connection_id, str(was_clean)]
        $CanvasLayer/Panel/MessageLog.text += hacker_name + ' has left the server.\n'
        if clients.has(player.status_terminal_id):
            _server.disconnect_peer(player.status_terminal_id)
            clients.erase(player.status_terminal_id)
        if clients.has(player.command_terminal_id):
            _server.disconnect_peer(player.command_terminal_id)
            clients.erase(player.command_terminal_id)
        if clients.has(player.game_terminal_id):
            _server.disconnect_peer(player.game_terminal_id)
            clients.erase(player.game_terminal_id)
        remove_child(players[hacker_name])
        players.erase(hacker_name)
        $CanvasLayer/Panel/MessageLog.scroll_vertical=INF
    
func _process(delta):
    # Call this in _process or _physics_process.
    # Data transfer, and signals emission will only happen when calling this function.
    _server.poll()
    
func _on_data(connection_id):
    # Print the received packet, you MUST always use get_peer(id).get_packet to receive data,
    # and not get_packet directly when not using the MultiplayerAPI.
    var pkt = _server.get_peer(connection_id).get_packet()
    var incoming = pkt.get_string_from_utf8()
    var address = str(_server.get_peer_address(connection_id))
    $CanvasLayer/Panel/StatusLabel.text = incoming
    var hacker_name = ''
    var team = ''
    if clients.has(connection_id):
        hacker_name = clients[connection_id]
        team = players[hacker_name].team
    if incoming.begins_with('join:'):
        var hacker_details = incoming.right(5).split('|')
        if game_state != 1 and len(hacker_details) >= 4:
            hacker_name = hacker_details[0]
            team = hacker_details[1]
            var role = hacker_details[2]
            var terminal = hacker_details[3]
            if players.has(hacker_name):
                if players[hacker_name].address != address:
                    $CanvasLayer/Panel/MessageLog.text += hacker_name + ' is being impersonated!\n'
                    _server.get_peer(connection_id).put_packet('That name is taken!'.to_utf8())
                else:
                    add_terminal_id(hacker_name, terminal, connection_id)
            else:
                players[hacker_name] = create_hacker(hacker_name, team, role, address)
                $CanvasLayer/Panel/MessageLog.text += hacker_name + ' has entered the server.\n'
                $CanvasLayer/Panel/MessageLog.text += 'Connection from '+ address + '\n'
                $CanvasLayer/Panel/MessageLog.scroll_vertical=INF
                add_terminal_id(hacker_name, terminal, connection_id)
    elif incoming.begins_with('msg:'):
        var msg_content = incoming.right(4)
        $CanvasLayer/Panel/MessageLog.text += hacker_name + ": " + msg_content + '\n'
        $CanvasLayer/Panel/MessageLog.scroll_vertical=INF
        #This should only send to status term clients of the correct team
        for player in players.values():
            if player.team == team and player.status_terminal_id != 0:
                var msg = {}
                msg['name'] = hacker_name
                msg['content'] = msg_content
                var team_msg = 'msg:' + JSON.print(msg)
                _server.get_peer(player.status_terminal_id).put_packet(team_msg.to_utf8())
    elif incoming.begins_with('kill:'):
        var item = incoming.right(5)
        if item in players[hacker_name].items:
            players[hacker_name].items.erase(item)
            if item in warm_colours:
                change_score(team, 1)
            else:
                change_score(team, -1)
    #If correct, light up status on server, broadcast to team mates
    elif incoming.begins_with("keyword:"):
        var key_guess = incoming.right(8)
        if key_guess == keyword:
            _server.get_peer(connection_id).put_packet("YOU GOT THE KEYWORD!".to_utf8())
        else:
            _server.get_peer(connection_id).put_packet("Incorrect keyword".to_utf8())
    #Ugh. I have to make like 5 command parsers. Should check that the command terminal is being used here
    #Maybe modify the API to send cmd: at the start?
    elif incoming.begins_with("telnet"):
        var hacker = players[hacker_name]
        var arguments = incoming.right(7).split(" ")
        if len(arguments) >= 2:
            var target_ip = arguments[0]
            if games.has(target_ip) and games[target_ip].role == "telnet":
                hacker.game_connection = target_ip
                _server.get_peer(hacker.command_terminal_id).put_packet(("Successful connection to " + target_ip).to_utf8())
            else:
                _server.get_peer(hacker.command_terminal_id).put_packet(("Unable to connect.").to_utf8())
        else:
                _server.get_peer(hacker.command_terminal_id).put_packet(("Incorrect Telnet syntax.").to_utf8())
    elif incoming == "env":
        var hacker = players[hacker_name]
        var target_ip = hacker.game_connection
        if games.has(target_ip) and games[target_ip].role == "telnet":
            _server.get_peer(hacker.command_terminal_id).put_packet((games[target_ip].list_environment_variables().to_utf8()))
    elif incoming.begins_with("printenv"):
        var hacker = players[hacker_name]
        var target_ip = hacker.game_connection
        var arguments = incoming.split(" ")
        if games.has(target_ip) and games[target_ip].role == "telnet":
            if len(arguments) == 2 and games[target_ip].environment_variables.has(arguments[1]):
                _server.get_peer(hacker.command_terminal_id).put_packet((games[target_ip].get_variable(arguments[1]).to_utf8()))

func generate_game_ip_address():
    return str(rng.randi_range(1,254)) + "." + str(rng.randi_range(1,254)) + "." + str(rng.randi_range(1,254)) + "." + str(rng.randi_range(1,254))

func change_score(team, amount):
    if team == 'orange':
        orange_score += amount
        $CanvasLayer/OrangePanel/OrangeScoreLabel.text = str(orange_score)
    elif team == 'green':
        green_score += amount
        $CanvasLayer/GreenPanel/GreenScoreLabel.text = str(green_score)

#need to accommodate team too
func create_hacker(hacker_name, team, role, address):
    var hacker = Hacker.instance()
    hacker.train(hacker_name, team, role, address, generate_game_ip_address())
    add_child(hacker)
    return hacker

#This is very rudimentary - should send a JSON with other data
func send_status(hacker_name, type, message):
    var status_terminal_id = players[hacker_name].status_terminal_id
    if status_terminal_id != 0:
        _server.get_peer(status_terminal_id).put_packet(("status:"+type + ": " + message).to_utf8())

func add_terminal_id(hacker_name, terminal, connection_id):
    if terminal == 'status':
        players[hacker_name].set_status_terminal_id(connection_id)
    elif terminal == 'command':
        players[hacker_name].set_command_terminal_id(connection_id)
    elif terminal == 'game':
        games[players[hacker_name].game_ip_address] = players[hacker_name].role
        players[hacker_name].set_game_terminal_id(connection_id)
        _server.get_peer(connection_id).put_packet(("Your IP: " + players[hacker_name].game_ip_address).to_utf8())
    send_status(hacker_name, 'TERMINAL_CONNECTED', terminal)
    _server.get_peer(connection_id).put_packet(str(connection_id).to_utf8())
    clients[connection_id] = hacker_name

#Only send to status terminals?
func _on_ServerDataPulse_timeout():
    for player in players.values():
        if player.status_terminal_id != 0:
            var client_state = 'state:' + JSON.print(player.get_state())
            _server.get_peer(player.status_terminal_id).put_packet(client_state.to_utf8())

#Prototype - remove all warm colours, keep all cool colours
func _on_WaitTimer_timeout():
    for player in players.values():
        #Nested for to check if items have expired?
        player.wait_time -= 1
        if player.wait_time <= 0 and player.game_terminal_id != 0:
            player.wait_time = rng.randi_range(5,15)
            var colour = ""
            if player.wait_time % 2 == 0:
                colour = warm_colours[randi() %warm_colours.size()]
            else:
                colour = cool_colours[randi() %cool_colours.size()]
            player.items[colour] = rng.randi_range(15, 25)
            var item = 'item:' + colour
            _server.get_peer(player.game_terminal_id).put_packet(item.to_utf8())
