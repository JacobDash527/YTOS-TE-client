extends Node2D

const WAITING: int = 0
const IN_PROGRESS: int = 1
const ENDED_GREEN_WIN: int = 2
const ENDED_ORANGE_WIN: int = 3

var game_state = WAITING
var game_time = 300

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

var keywords = ["TANAGER", "PERFECT", "TOUCHPAPER", "BRIDEWELL", "CANDLEFLAME", "BARROW", "HARROW", "DRUMFIRE", "SEACHANGE", "PRIORITY", "VOTIVE", "RADIOSTATIC", "HIATUS", "REDSKY", "BOREA", "BELLWETHER", "INDIGOBIRD", "MINUTEHAND", "GLACIER", "BITTERTASTE", "SOFTPOINT", "UMBRAL", "DOWNRIVER", "GABARDINE", "CENTERPOINT", "OVERWINTER", "STAINEDGLASS", "BREAKNECK", "FLASHOVER", "MOONSTONE", "OREBODY", "GHOSTNOTE", "WEATHEREYE", "REDSHIFT"]

#Dummy keyword for testing
var keyword = keywords[randi() % len(keywords)]

var warm_colours = ["RED", "YELLOW", "ORANGE", "TOMATO", "VOLCANO", "SUMMER", "FLAMINGO", "SUNSET", "NEONRED", "MARISCHINO"]
var cool_colours = ["BLUE", "GREEN", "RIVER", "SEAFOAM", "BLIZZARD", "SKY", "AQUATIC", "ALGAE", "ARCTIC", "ELECTRICCYAN", "TURQUOISE"]

var green_score = 0
var orange_score = 0
var green_intel = 0
var orange_intel = 0

var orange_keywords = []
var green_keywords = []

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

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
    $CanvasLayer/Panel/IPLabel.text = 'Server IP: '
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
        if players.has(hacker_name):
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
            if players[hacker_name].team == "green":
                $CanvasLayer/GreenPanel.remove_child(players[hacker_name])
            else:
                $CanvasLayer/OrangePanel.remove_child(players[hacker_name])
            players.erase(hacker_name)
            rearrange_portraits()
            $CanvasLayer/Panel/MessageLog.scroll_vertical=INF
    
func _process(_delta):
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
    var hacker_name = ""
    var team = ""
    print(connection_id)
    if clients.has(connection_id):
        hacker_name = clients[connection_id]
        team = players[hacker_name].team
    if incoming.begins_with("join:"):
        if game_state == WAITING:
            var hacker_details = incoming.right(5).split('|')
            if game_state != 1 and len(hacker_details) >= 5:
                hacker_name = hacker_details[0]
                team = hacker_details[1]
                var team_numbers = get_team_sizes()
                if team_numbers[team] >= 4:
                    send_terminal_message(connection_id, team + " is full. Try reconnecting as another team?")
                else:
                    var role = hacker_details[2]
                    var terminal = hacker_details[3]
                    var portrait = hacker_details[4]
                    if players.has(hacker_name):
                        if players[hacker_name].address != address:
                            $CanvasLayer/Panel/MessageLog.text += hacker_name + " is being impersonated!\n"
                            send_terminal_message(connection_id, "That name is taken!")
                        else:
                            add_terminal_id(hacker_name, terminal, connection_id)
                    else:
                        players[hacker_name] = create_hacker(hacker_name, team, role, portrait, address)
                        rearrange_portraits()
                        $CanvasLayer/Panel/MessageLog.text += hacker_name + " has entered the server.\n"
                        $CanvasLayer/Panel/MessageLog.text += "Connection from "+ address + "\n"
                        $CanvasLayer/Panel/MessageLog.scroll_vertical=INF
                        add_terminal_id(hacker_name, terminal, connection_id)
        else:
            send_terminal_message(connection_id, "Game in progress. Connect another time.")
    #Can chat in any game state
    elif incoming.begins_with("msg:"):
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
                send_terminal_message(player.status_terminal_id, team_msg)
    elif incoming.begins_with("head:"):
        var portrait_number = incoming.right(5)
        players[hacker_name].set_portrait(portrait_number)
    #All other commands must be sent when the game is running?
    else:
        if game_state == IN_PROGRESS:
            #modify this to be game parser specific
            if incoming == "show cnx":            
                var player = players[hacker_name]
                if player.role == "telnet" and games.has(player.game_ip_address):
                    var telnet = games[player.game_ip_address]
                    send_terminal_message(player.game_terminal_id, telnet.list_connections())
            elif incoming.begins_with("kick "):
                var target_ip = incoming.right(5)
                var player = players[hacker_name]
                if games[player.game_ip_address].remove_connection(target_ip):
                    send_terminal_message(player.status_terminal_id, "TELNET: Malicious connection " + target_ip + " removed - intel gained.")
                    change_score(player.team, 1)
                    #Put this in a function ffs
                    if target_ip in games[player.game_ip_address].external_connections:
                        var disconnect_target = get_player_by_game_ip(target_ip)
                        disconnect_target.game_connection = ""
                        games[player.game_ip_address].external_connections.remove(target_ip)
                        send_terminal_message(disconnect_target.command_terminal_id, "TELNET: Connection lost!")
                else:
                    send_terminal_message(player.status_terminal_id, ("TELNET: Interferred with or removed valid connection " + target_ip + " - intel lost."))
                    change_score(player.team, -1)
            #should ensure only coming from command terminal
            elif incoming == "scan ips":
                var player = players[hacker_name]
                if connection_id == player.command_terminal_id:
                    if player.ability == "ipscan":
                        var intel_available = get_team_intel(player.team)
                        if intel_available >= 5:
                            change_intel(player.team, -5)
                            send_terminal_message(connection_id, "IP found: " + get_random_ip(player.team))
                        else:
                            send_terminal_message(connection_id, "insufficient intel to run a scan (<5)")
                    else:
                        send_terminal_message(connection_id, "command not found")
            #If correct, light up status on server, broadcast to team mates
            elif incoming.begins_with("keyword:"):
                var key_guess = incoming.right(8)
                if check_keyword(players[hacker_name].team, key_guess):
                    send_terminal_message(connection_id, "YOU GOT THE KEYWORD!")
                else:
                    send_terminal_message(connection_id, "Incorrect keyword.")
            #Ugh. I have to make like 5 command parsers. Should check that the command terminal is being used here
            #Maybe modify the API to send cmd: at the start?
            elif incoming.begins_with("telnet"):
                var hacker = players[hacker_name]
                var arguments = incoming.right(7).split(" ")
                if len(arguments) >= 2:
                    var target_ip = arguments[0]
                    if games.has(target_ip) and games[target_ip].role == "telnet":
                        hacker.game_connection = target_ip
                        send_terminal_message(hacker.command_terminal_id, "Successful connection to " + target_ip)
                        var ttl = games[target_ip].add_connection(hacker.game_ip_address)
                        send_terminal_message(hacker.command_terminal_id, "You have " + ttl + " seconds left.")
                    else:
                        send_terminal_message(hacker.command_terminal_id, "Unable to connect.")
                else:
                        send_terminal_message(hacker.command_terminal_id, "Incorrect Telnet syntax.")
            elif incoming == "env":
                var hacker = players[hacker_name]
                var target_ip = hacker.game_connection
                if games.has(target_ip) and games[target_ip].role == "telnet":
                    send_terminal_message(hacker.command_terminal_id, (games[target_ip].list_environment_variables()))
            elif incoming.begins_with("printenv"):
                var hacker = players[hacker_name]
                var target_ip = hacker.game_connection
                var arguments = incoming.split(" ")
                if games.has(target_ip) and games[target_ip].role == "telnet":
                    if len(arguments) == 2 and games[target_ip].environment_variables.has(arguments[1]):
                        send_terminal_message(hacker.command_terminal_id, games[target_ip].get_variable(arguments[1]))
        else:
            send_terminal_message(connection_id, "Unable to run commands - game not in progress.")

func get_team_intel(team):
    var intel = 0
    if team == "orange":
        intel = orange_intel
    else:
        intel = green_intel
    return intel

#Returns a random game IP address for opposing team
func get_random_ip(team):
    var addresses = []
    var address = "0.0.0.0"
    for player in players.values():
        if player.team != team:
            addresses.append(player.game_ip_address)
    if len(addresses) > 0:
        address = addresses[randi() % len(addresses)]
    else:
        address = "192.168.1.100"
    return address

func generate_game_ip_address():
    return str(rng.randi_range(1,254)) + "." + str(rng.randi_range(1,254)) + "." + str(rng.randi_range(1,254)) + "." + str(rng.randi_range(1,254))

func change_score(team, amount):
    #When the score changes, so does the intel
    change_intel(team, amount)
    if team == 'orange':
        orange_score += amount
        $CanvasLayer/OrangePanel/OrangeScoreLabel.text = str(orange_score)
    elif team == 'green':
        green_score += amount
        $CanvasLayer/GreenPanel/GreenScoreLabel.text = str(green_score)

func change_intel(team, amount):
    if team == 'orange':
        orange_intel += amount
        $CanvasLayer/OrangePanel/OrangeIntelLabel.text = str(orange_intel)
    elif team == 'green':
        green_intel += amount
        $CanvasLayer/GreenPanel/GreenIntelLabel.text = str(green_intel)

func create_hacker(hacker_name, team, role, portrait, address):
    var hacker = Hacker.instance()
    hacker.train(hacker_name, team, role, address, generate_game_ip_address(), portrait)
    if team == "green":
        $CanvasLayer/GreenPanel.add_child(hacker)
    else:
        $CanvasLayer/OrangePanel.add_child(hacker)
    return hacker

#This is very rudimentary - should send a JSON with other data
func send_status(hacker_name, type, message):
    var status_terminal_id = players[hacker_name].status_terminal_id
    if status_terminal_id != 0:
        send_terminal_message(status_terminal_id, ("status:"+type + ": " + message))

func add_terminal_id(hacker_name, terminal, connection_id):
    if terminal == "status":
        players[hacker_name].set_status_terminal_id(connection_id)
    elif terminal == "command":
        players[hacker_name].set_command_terminal_id(connection_id)
    elif terminal == "game":
        if players[hacker_name].role == "telnet":
            var new_telnet = Telnet.instance()
            games[players[hacker_name].game_ip_address] = new_telnet
            add_child(new_telnet)
            var environment_variables = new_telnet.environment_variables.keys()
            var keyword_hiding_place = environment_variables[randi() % len(environment_variables)]
            var new_keyword = keywords[randi() % len(keywords)]
            new_telnet.set_keyword(keyword_hiding_place, new_keyword)
            add_keyword(players[hacker_name].team, new_keyword)
        players[hacker_name].set_game_terminal_id(connection_id)
        send_terminal_message(connection_id, "Your IP: " + players[hacker_name].game_ip_address)
    send_status(hacker_name, "TERMINAL_CONNECTED", terminal)
    send_terminal_message(connection_id, str(connection_id))
    clients[connection_id] = hacker_name

#Add a new keyword to a team
func add_keyword(team, team_keyword):
    if team == "orange":
        orange_keywords.append(team_keyword)
    else:
        green_keywords.append(team_keyword)

#Check if a keyword has been assigned to a team
func check_keyword(team, guess):
    var result = false
    if team == "orange":
        result = guess in green_keywords
    else:
        result = guess in orange_keywords
    return result

#Only send to status terminals? Is this deprecated?
func _on_ServerDataPulse_timeout():
    for player in players.values():
        if player.status_terminal_id != 0:
            var client_state = 'state:' + JSON.print(player.get_state())
            send_terminal_message(player.status_terminal_id, client_state.to_utf8())

#Ugh, this is inefficient/bad - switch to while loop and single return
func get_player_by_game_ip(game_ip):
    for player in players.values():
        if player.game_ip_address == game_ip:
            return player
    return false

func update_game_time():
    var mins = str(game_time / 60)
    var secs = str(game_time % 60)
    if len(secs) == 1:
        secs = "0" + secs
    $CanvasLayer/Panel/GameTimerLabel.text = mins + ":" + secs

#Needs to check for keywords found?
#Oh no, the label is too big and needs to shift left to show winner, then shift back after? messy.
func end_game():
    if green_score > orange_score:
        game_state = WAITING
        $CanvasLayer/Panel/GameTimerLabel.text = "GREEN WINS"
        $WaitTimer.stop()
        $CanvasLayer/StartGameButton.text = "Start game"
    elif orange_score > green_score:
        game_state = WAITING
        $CanvasLayer/Panel/GameTimerLabel.text = "ORANGE WINS"
        $WaitTimer.stop()
        $CanvasLayer/StartGameButton.text = "Start game"
    else:
        #Tie game overtime
        game_time = 30

#Switch on when game is in progress, off when not.
#Should check game status as well as number of players in each team - early end if a team is gone
func _on_WaitTimer_timeout():
    game_time -= 1
    update_game_time()
    if game_time <= 0:
        end_game()
    else:
        for player in players.values():
            player.wait_time -= 1
            if player.game_terminal_id != 0:
                var terminal = games[player.game_ip_address]
                var items = terminal.expire_items()
                for item in items:
                    if item in terminal.external_connections:
                        var disconnect_target = get_player_by_game_ip(item)
                        disconnect_target.game_connection = ""
                        terminal.external_connections.erase(item)
                        send_terminal_message(disconnect_target.command_terminal_id, "TELNET: Connection lost!")
                    if items[item]:
                        send_terminal_message(player.status_terminal_id, "Intel lost to " + item)
                        change_intel(player.team, -1)
                    else:
                        send_terminal_message(player.status_terminal_id, "Intel gained from " + item)
                        change_score(player.team, 1)
                if player.wait_time <= 0:
                    player.wait_time = rng.randi_range(5,15)
                    
                    if player.role == "telnet":
                        var telnet_game = games[player.game_ip_address]
                        var criteria = telnet_game.get_criteria()
                        if player.criteria != criteria:
                            player.criteria = criteria
                            message_random_team_mate(player, "TELNET @ " + player.game_ip_address + ": " + criteria)
                        var connection_ip = telnet_game.add_connection("dummy")
                        if connection_ip:
                            send_terminal_message(player.status_terminal_id, "TELNET: New inbound connection!")
                        
func message_random_team_mate(relevant_player, message):
    var relevant_player_status_terminal_id = relevant_player.status_terminal_id
    var team_mates = []
    for player in players.values():
        if player.team == relevant_player.team:
            team_mates.append(player.status_terminal_id)
    if len(team_mates) == 0:
        send_terminal_message(relevant_player_status_terminal_id, message)
    else:
        var nextTeamMate = 0
        var count = 0
        #Triggering an error - maybe I can't use this function?
        while (_server.get_peer(nextTeamMate) == null):
            count += 1
            if count > 1000:
                return
            nextTeamMate = team_mates[randi() % team_mates.size()]
        send_terminal_message(nextTeamMate, message)

func send_terminal_message(terminal_id : int, msg : String):
    if (terminal_id != 0):
        _server.get_peer(terminal_id).put_packet(msg.to_utf8())

func get_team_sizes():
    var team_numbers = {}
    team_numbers["orange"] = 0
    team_numbers["green"] = 0
    for player in players.values():
        if player.team == "orange":
            team_numbers["orange"] += 1
        else:
            team_numbers["green"] += 1
    return team_numbers

func both_teams_exist():
    var team_numbers = get_team_sizes()
    var result = false
    if team_numbers["green"] > 0 and team_numbers["orange"] > 0:
        result = true
    return result

func rearrange_portraits():
    var green_x = 38
    var green_y = 154
    var orange_x = 38
    var orange_y = 154
    for player in players.values():
        if player.team == "green":
            player.position = Vector2(green_x, green_y)
            green_y += 80
        else:
            player.position = Vector2(orange_x, orange_y)
            orange_y += 80

#Should send a message to clear terminals on game start?
func _on_StartGameButton_pressed():
    if game_state == WAITING and both_teams_exist():
        game_state = IN_PROGRESS
        game_time = 300
        $WaitTimer.start()
        $CanvasLayer/StartGameButton.text = "End game"
    elif game_state == IN_PROGRESS:
        game_state = WAITING
        $WaitTimer.stop()
        $CanvasLayer/StartGameButton.text = "Start game"
    else:
        $CanvasLayer/Panel/StatusLabel.text = "Unable to start - missing a team!"
        
