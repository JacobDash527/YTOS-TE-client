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

var intel_costs = {"scan ips":5, "telnet":10}

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
    rng.randomize()
    keywords.shuffle()
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
    $CanvasLayer/HBox/Panel/VBox/IPLabel.text = 'Server IP: '
    for address in IP.get_local_addresses():
        if (address.split('.').size() == 4) and not (address.begins_with('169') or address.begins_with('127')):
            $CanvasLayer/HBox/Panel/VBox/IPLabel.text +=  ' (' + address + ') '
    
func _connected(id, proto):
    # This is called when a new peer connects, "id" will be the assigned peer id,
    # "proto" will be the selected WebSocket sub-protocol (which is optional)
    var cnx = "Client %d connected with protocol: %s" % [id, proto]
    $CanvasLayer/HBox/Panel/VBox/ConnectionsLabel.text = cnx

func _close_request(id, code, reason):
    # This is called when a client notifies that it wishes to close the connection,
    # providing a reason string and close code.
    var cnx = "Client %d disconnecting with code: %d, reason: %s" % [id, code, reason]
    $CanvasLayer/HBox/Panel/VBox/ConnectionsLabel.text = cnx

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
            log_to_console(hacker_name + " has left the server.")
            $CanvasLayer/HBox/Panel/VBox/ConnectionsLabel.text = "Client %d disconnected, clean: %s" % [connection_id, str(was_clean)]
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
                $CanvasLayer/HBox/GreenPanel/VBox/Players.remove_child(player)
                remove_keyword("orange", player.keyword)
            else:
                $CanvasLayer/HBox/OrangePanel/VBox/Players.remove_child(player)
                remove_keyword("green", player.keyword)
            players.erase(hacker_name)

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
    $CanvasLayer/HBox/Panel/VBox/StatusLabel.text = incoming
    var hacker_name = ""
    var team = ""
    if clients.has(connection_id):
        hacker_name = clients[connection_id]
        if players.has(hacker_name):
            team = players[hacker_name].team
    if incoming.begins_with("join:"):
        if game_state == WAITING:
            var hacker_details = incoming.right(5).split('|')
            if game_state != 1 and len(hacker_details) >= 5:
                hacker_name = hacker_details[0]
                team = hacker_details[1].to_lower()
                var team_numbers = get_team_sizes()
                if team_numbers[team] >= 4:
                    send_terminal_message(connection_id, team + " is full. Try reconnecting as another team?")
                    _server.disconnect_peer(connection_id)
                else:
                    var role = hacker_details[2]
                    var terminal = hacker_details[3]
                    var portrait = hacker_details[4]
                    if players.has(hacker_name):
                        if players[hacker_name].address != address:
                            log_to_console(hacker_name + " is being impersonated!")
                            send_terminal_message(connection_id, "That name is taken!")
                        else:
                            add_terminal_id(hacker_name, terminal, connection_id)
                    else:
                        players[hacker_name] = create_hacker(hacker_name, team, role, portrait, address)
                        log_to_console(hacker_name + " has entered the server.")
                        log_to_console("Connection from "+ address)
                        add_terminal_id(hacker_name, terminal, connection_id)
        else:
            send_terminal_message(connection_id, "Game in progress. Connect another time.")
            _server.disconnect_peer(connection_id)
    #Can chat in any game state
    elif incoming.begins_with("command:msg:"):
        var msg_content = incoming.right(len("command:msg:"))
        for player in players.values():
            if player.team == team and player.status_terminal_id != 0:
                var msg = {}
                msg['name'] = hacker_name
                msg['content'] = msg_content
                var team_msg = 'msg:' + JSON.print(msg)
                send_terminal_message(player.status_terminal_id, team_msg)
    elif incoming.begins_with("command:head:"):
        var portrait_number = incoming.right(len("command:head:"))
        if players.has(hacker_name):
            print("Port num: " + portrait_number)
            players[hacker_name].set_portrait(portrait_number)
    #All other commands must be sent when the game is running?
    else:
        if game_state == IN_PROGRESS:
            if incoming.begins_with("game:"):
                var client_request = incoming.right(len("game:"))
                if players.has(hacker_name):
                    var player = players[hacker_name]
                    if games.has(player.game_ip_address):
                        var game = games[player.game_ip_address]
                        game.parse_command(client_request, player, self)
            #Command terminal parsing
            elif incoming.begins_with("command:"):
                var client_request = incoming.right(len("command:"))
                if client_request == "scan ips":
                    var player = players[hacker_name]
                    var intel_cost = intel_costs["scan ips"]
                    if player.ability == "scan ips":
                        var intel_available = get_team_intel(player.team)
                        if intel_available >= intel_cost:
                            change_intel(player.team, -1 * intel_cost)
                            send_terminal_message(connection_id, "IP found: " + get_random_ip(player.team))
                        else:
                            send_terminal_message(connection_id, "insufficient intel to run a scan (<" + str(intel_cost) + ")")
                #If correct, light up status on server, broadcast to team mates
                elif client_request.begins_with("keyword:"):
                    if players[hacker_name].game_connection == "":
                        var key_guess = client_request.right(8)
                        if check_keyword(players[hacker_name].team, key_guess):
                            send_terminal_message(connection_id, "Keyword registered.")
                            log_to_console(hacker_name + " has found a keyword!")
                            remove_keyword(players[hacker_name].team, key_guess)
                        else:
                            send_terminal_message(connection_id, "Incorrect keyword.")
                    else:
                        send_terminal_message(connection_id, "Invalid command. Disconnect to register a keyword.")
                #Ugh. I have to make like 5 command parsers. Should check that the command terminal is being used here
                elif client_request.begins_with("telnet"):
                    var hacker = players[hacker_name]
                    var arguments = client_request.right(7).split(" ")
                    var intel_cost = intel_costs["telnet"]
                    if get_team_intel(hacker.team) >= intel_cost:
                        change_intel(hacker.team, -1 * intel_cost)
                        if len(arguments) >= 2:
                            var target_ip = arguments[0]
                            if games.has(target_ip) and games[target_ip].role == "telnet":
                                hacker.game_connection = target_ip
                                send_terminal_message(hacker.command_terminal_id, "Successful connection to " + target_ip)
                                send_terminal_message(hacker.command_terminal_id, "connection:" + "telnet:" + target_ip)
                                send_terminal_message(hacker.status_terminal_id, "connection:" + "telnet:" + target_ip)
                                var ttl = games[target_ip].add_connection(hacker.game_ip_address)
                                send_status(hacker.hacker_name, "connection", "telnet:" + target_ip + ":" + str(ttl))
                                send_terminal_message(hacker.command_terminal_id, "You have " + ttl + " seconds left.")
                            else:
                                send_terminal_message(hacker.command_terminal_id, "Unable to connect.")
                        else:
                                send_terminal_message(hacker.command_terminal_id, "Incorrect Telnet syntax.")
                    else:
                        send_terminal_message(connection_id, "insufficient intel to connect (<" + str(intel_cost) + ")")
                elif client_request == "env":
                    var hacker = players[hacker_name]
                    var target_ip = hacker.game_connection
                    if games.has(target_ip) and games[target_ip].role == "telnet":
                        send_terminal_message(hacker.command_terminal_id, (games[target_ip].list_environment_variables()))
                elif client_request.begins_with("printenv"):
                    var hacker = players[hacker_name]
                    var target_ip = hacker.game_connection
                    var arguments = client_request.split(" ")
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
    if team == "orange":
        orange_score += amount
        if orange_score < 0:
            orange_score = 0
        $CanvasLayer/HBox/OrangePanel/VBox/OrangeScoreLabel.text = str(orange_score)
    elif team == "green":
        green_score += amount
        if green_score < 0:
            green_score = 0
        $CanvasLayer/HBox/GreenPanel/VBox/GreenScoreLabel.text = str(green_score)

func change_intel(team, amount):
    if team == "orange":
        orange_intel += amount
        if orange_intel < 0:
            orange_intel = 0
        $CanvasLayer/HBox/OrangePanel/VBox/OrangeIntelLabel.text = str(orange_intel)
    elif team == "green":
        green_intel += amount
        if green_intel < 0:
            green_intel = 0
        $CanvasLayer/HBox/GreenPanel/VBox/GreenIntelLabel.text = str(green_intel)

func create_hacker(hacker_name, team, role, portrait, address):
    var hacker = Hacker.instance()
    hacker.train(hacker_name, team, role, address, generate_game_ip_address(), portrait)
    if team == "green":
        $CanvasLayer/HBox/GreenPanel/VBox/Players.add_child(hacker)
    else:
        $CanvasLayer/HBox/OrangePanel/VBox/Players.add_child(hacker)
    return hacker

#All status messages should prepend "status:" except chat messages
func send_status(hacker_name, type, message):
    var status_terminal_id = players[hacker_name].status_terminal_id
    if status_terminal_id != 0:
        send_terminal_message(status_terminal_id, ("status:"+type + ":" + message))

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
            var new_keyword = keywords.pop_front()
            new_telnet.set_keyword(keyword_hiding_place, new_keyword)
            add_keyword(players[hacker_name].team, new_keyword)
            players[hacker_name].keyword = new_keyword
        players[hacker_name].set_game_terminal_id(connection_id)
        send_team_details(players[hacker_name].team)
    send_terminal_message(connection_id, players[hacker_name].game_ip_address)
    send_status(hacker_name, "TERMINAL_CONNECTED", terminal)
    clients[connection_id] = hacker_name

#Add a new keyword to a team
func add_keyword(team, team_keyword):
    if team == "orange":
        orange_keywords.append(team_keyword)
        $CanvasLayer/HBox/OrangePanel/VBox/OrangeKeywordLabel.text += "*"
    else:
        green_keywords.append(team_keyword)
        $CanvasLayer/HBox/GreenPanel/VBox/GreenKeywordLabel.text += "*"

#Check if a keyword has been assigned to a team
func check_keyword(team, guess):
    var result = false
    if team == "orange":
        result = guess in green_keywords
    else:
        result = guess in orange_keywords
    return result

#Removes keyword for the OPPOSITE team
func remove_keyword(team, keyword):
    if team == "orange":
        green_keywords.erase(keyword)
        $CanvasLayer/HBox/GreenPanel/VBox/GreenKeywordLabel.text = ""
        for i in range(len(green_keywords)):
            $CanvasLayer/HBox/GreenPanel/VBox/GreenKeywordLabel.text += "*"
    else:
        orange_keywords.erase(keyword)
        $CanvasLayer/HBox/OrangePanel/VBox/OrangeKeywordLabel.text = ""
        for i in range(len(orange_keywords)):
            $CanvasLayer/HBox/OrangePanel/VBox/OrangeKeywordLabel.text += "*"
    if (len(green_keywords) == 0 or len(orange_keywords) == 0) and game_state == IN_PROGRESS:
        end_game()

#Only send to status terminals? Is this deprecated?
func _on_ServerDataPulse_timeout():
    for player in players.values():
        if player.status_terminal_id != 0:
            var client_state = 'state:' + JSON.print(player.get_state())
            send_terminal_message(player.status_terminal_id, client_state)

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
    $CanvasLayer/HBox/Panel/VBox/GameTimerLabel.text = mins + ":" + secs

func end_game():
    var winner = ""
    if len(green_keywords) == 0:
        winner = "ORANGE"
    elif len(orange_keywords) == 0:
        winner = "GREEN"
    else:
        var team_numbers = get_team_sizes()
        if team_numbers["green"] == 0:
            winner = "ORANGE"
        elif team_numbers["orange"] == 0:
            winner = "GREEN"
        else:
            if green_score > orange_score:
                winner = "GREEN"
            elif orange_score > green_score:
                winner = "ORANGE"
            else:
                #Tie game overtime
                game_time = 30
    if winner != "":
        game_state = WAITING
        $CanvasLayer/HBox/Panel/VBox/GameTimerLabel.text = winner + " WINS"
        $WaitTimer.stop()
        $CanvasLayer/HBox/Panel/VBox/StartGameButton.text = "Start game"
        green_keywords.clear()
        orange_keywords.clear()

#Switch on when game is in progress, off when not.
#Should check game status as well as number of players in each team - early end if a team is gone
func _on_WaitTimer_timeout():
    if both_teams_exist():
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
                            send_status(player.hacker_name, "game", "Intel lost to " + item)
                            change_intel(player.team, -1)
                        else:
                            send_status(player.hacker_name, "game", "Intel gained from " + item)
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
                                send_status(player.hacker_name, "game","TELNET: New inbound connection!")
    else:
        end_game()
                        
func message_random_team_mate(relevant_player, message):
    var target_team_mate_name = relevant_player.hacker_name
    var team_mates = []
    for player in players.values():
        if player.team == relevant_player.team:
            team_mates.append(player.hacker_name)
    if len(team_mates) > 0:
        target_team_mate_name = team_mates[randi() % team_mates.size()]
    send_status(target_team_mate_name, "game", message)

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

func send_status_to_all_team_mates(team, type, message):
    for player in players.values():
        if player.team == team and player.status_terminal_id != 0:
            send_status(player.hacker_name, type, message)

func send_team_details(target_team):
    for player in players.values():
        if player.team == target_team:
            var player_details = player.hacker_name + "|" + player.role + "|" + player.game_ip_address + "|" + player.keyword
            send_status_to_all_team_mates(target_team, "team", player_details)
    
#Should send a message to clear terminals on game start?
func _on_StartGameButton_pressed():
    if game_state == WAITING and both_teams_exist():
        var incomplete_players = get_player_names_with_incomplete_terminals()
        if len(incomplete_players) == 0:
            game_state = IN_PROGRESS
            game_time = 300
            green_score = 0
            green_intel = 0
            orange_score = 0
            orange_intel = 0
            change_score("green", 0)
            change_score("orange", 0)
            $WaitTimer.start()
            $CanvasLayer/HBox/Panel/VBox/StartGameButton.text = "End game"
        else:
            for player_name in incomplete_players:
                log_to_console(player_name + " has not connected all terminals.")
    elif game_state == IN_PROGRESS:
        game_state = WAITING
        $WaitTimer.stop()
        $CanvasLayer/HBox/Panel/VBox/StartGameButton.text = "Start game"
    else:
        $CanvasLayer/HBox/Panel/VBox/StatusLabel.text = "Unable to start - missing a team!"

func get_player_names_with_incomplete_terminals():
    var incomplete_players = []
    for player in players.values():
        if player.status_terminal_id == 0 or player.game_terminal_id == 0 or player.command_terminal_id == 0:
            incomplete_players.append(player.hacker_name)
    return incomplete_players
    
func log_to_console(console_message):
    $CanvasLayer/HBox/Panel/VBox/MessageLog.text += console_message + "\n"
    $CanvasLayer/HBox/Panel/VBox/MessageLog.scroll_vertical=INF
