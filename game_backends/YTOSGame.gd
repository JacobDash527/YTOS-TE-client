extends Node2D

var role = "ytos"
var ip_address = "192.168.1.25"
var port = 45
var level = 0
var backend_processes = {}
#The maximum number of files that can sit in the frontend
var max_processes = 6
#Add more noise?
var dummy_contents = ["844bc488e305bb7a86e24da174dc0d91","5a7c9c5da0167d05b9895743410d8f8e","2137c2bc3fb16db33b0d994fb9771bdc","9c54983be63c46f2cd850883579665cd","ed0404c8c10704a953412ae633c6f6b2"]
var current_processes = []

var external_connections = {}

var green_prc = 0
var orange_prc = 0

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    #Generate 4 files+extensions and add them to the backend files dictionary, along with randomly selected dummy_contents
    #Create directives

#This may all be done client side?
func create_directives():
    pass

#This gets called by the server when someone requests to push/pull to the game terminal
func add_keyword(sender, receiver, server, keyword):
    var success = false
    var response_message = "Unable to push/pull keyword. Unknown error."
    if len(backend_processes) > len(receiver.keywords):
        if keyword in sender.keywords:
            var process_names = backend_processes.keys()
            var process_name = process_names.pop_front()
            var still_looking = true
            while still_looking:
                if not (backend_processes[process_name] in receiver.keywords):
                    still_looking = false
                    backend_processes[process_name] = keyword
                    success = true
                if len(process_names) > 0:
                    process_name = process_names.pop_front()
                else:
                    still_looking = false
        else:
            response_message = "Unable to move keyword - sender does not own it."
    else:
        response_message = "Unable to move keyword - insufficient space on receiver."
    if success:
        response_message = "Success. Keyword moved to " + receiver.hacker_name + "."
        sender.keywords.erase(keyword)
        receiver.keywords.append(keyword)
        server.games[sender.game_ip_address].remove_keyword(keyword)
        server.send_team_details(receiver.team)
    return response_message

#Removes a keyword from the backend files and replaces it with dummy content
func remove_keyword(keyword):
    for process_name in backend_processes:
        if backend_processes[process_name] == keyword:
            backend_processes[process_name] = dummy_contents[randi() % len(dummy_contents)]

#Retrieves the contents of a backend process
func get_process_contents(process_name):
    if backend_processes.has(process_name):
        return backend_processes[process_name]

func list_files():
    var process_names = backend_processes.keys()
    process_names.shuffle()
    return "\n" + "\n".join(process_names)

func list_connections():
    return "\n" + "\n".join(external_connections.keys())

#Adds a process to the current_processes array
func add_process(new_process):
    pass

#Slightly modified version of telnet one - the player has requested to kill a process
#The function should figure out if this was a good move and add or remove intel as necessary
#Plus - if this was an intruder's process created when they connected, kick them off
func remove_file(target_file, server):
    var good_move = false
    """
    if connections.has(target_ip):
        if !target_ip.begins_with(allowed_prefix):
            good_move = true
        connections.erase(target_ip)
    if external_connections.has(target_ip):
        var disconnect_target = server.get_player_by_game_ip(target_ip)
        external_connections.erase(target_ip)
        if disconnect_target:
            disconnect_target.game_connection = ""
            server.send_terminal_message(disconnect_target.command_terminal_id, "TELNET: Connection lost!")
            server.send_terminal_message(disconnect_target.command_terminal_id, "disconnect")
            server.send_terminal_message(disconnect_target.status_terminal_id, "disconnect")
    return good_move
    """

#Not entirely like telnet - all this needs to do is kick off any expired external connections
func expire_files(server):
    var expired = {}
    """
    for connection in connections:
        connections[connection] -= 1
        if connections[connection] <= 0:
            expired[connection] = remove_connection(connection, server)
    return expired
    """

#Generic function - executes whenever the game server ticks (currently once per second)
#Decide what the YTOS backend will do each second - it will expire old external connections
func tick(player, server):
    pass
    """
    var items = expire_connections(server)
    for item in items:
        if items[item]:
            server.send_status(player.hacker_name, "game", "Intel lost to " + item)
            server.change_intel(player.team, -1)
        else:
            server.send_status(player.hacker_name, "game", "Intel gained from " + item)
            server.change_score(player.team, 1)
    if player.wait_time <= 0:
        player.wait_time = rng.randi_range(5,15)

        var criteria = get_criteria()
        if player.criteria != criteria:
            player.criteria = criteria
            server.message_random_team_mate(player, player.hacker_name + " (telnet): " + criteria)
        var connection_ip = add_connection("dummy")
        if connection_ip:
            server.send_status(player.hacker_name, "game","TELNET: New inbound connection!")
    """

#Decide what works for you
#Level ups should occur whenever a player ???
func level_up():
    pass
    """
    level += 1
    if level % 5 == 0:
        add_environment_variable()
    """

#Check for commands that an attacker can use in this function
#You will need to parse two attacker commands: ps and lsof <PID>
func parse_attacker_command(command, player, server):
    pass
    """
    if command == "env":
        server.send_terminal_message(player.command_terminal_id, list_environment_variables())
    elif command.begins_with("printenv"):
        var arguments = command.split(" ")
        if len(arguments) == 2 and environment_variables.has(arguments[1]):
            server.send_terminal_message(player.command_terminal_id, get_variable(arguments[1]))
    else:
        server.send_terminal_message(player.command_terminal_id, "INVALID TELNET COMMAND")
    """

#Check for commands that the owner can use in this function - I think only upgrades/special abilities (tbd)?
#You will need to parse the following:
#port shift (exactly the same code as in telnet)
func parse_command(command, player, server):
    if command == "show cnx":
        server.send_terminal_message(player.game_terminal_id, list_connections())
    elif command.begins_with("kick "):
        var games = server.games
        var target_ip = command.right(len("kick "))
        if games[player.game_ip_address].remove_connection(target_ip, server):
            server.send_status(player.hacker_name, "game", "TELNET: Malicious connection " + target_ip + " removed - intel gained.")
            server.change_score(player.team, 1)
            games[player.game_ip_address].level_up()
            #Put this in a function ffs - need unified disconnection
            if target_ip in games[player.game_ip_address].external_connections:
                var disconnect_target = server.get_player_by_game_ip(target_ip)
                disconnect_target.game_connection = ""
                games[player.game_ip_address].external_connections.erase(target_ip)
                server.send_terminal_message(disconnect_target.command_terminal_id, "TELNET: Connection lost!")
                server.send_terminal_message(disconnect_target.command_terminal_id, "disconnect")
                server.send_terminal_message(disconnect_target.status_terminal_id, "disconnect")
                server.send_status(disconnect_target.hacker_name, "disconnect", "telnet:" + target_ip)
        else:
            server.send_status(player.hacker_name, "game", "TELNET: Interferred with or removed valid connection " + target_ip + " - intel lost.")
            server.change_score(player.team, -1)
    elif command == "port shift":
        var intel_cost = server.intel_costs["port shift"]
        if server.get_team_intel(player.team) >= intel_cost:
            server.change_intel(player.team, -1 * intel_cost)
            port = rng.randi_range(port+1, port+20)
            server.send_terminal_message(player.game_terminal_id, "Port changed to " + str(port))
            server.play_sound("port_shift")
        else:
            server.send_terminal_message(player.game_terminal_id, "Insufficient intel to shift ports (<"+str(intel_cost)+")")
    elif command.begins_with("process_greened|"):
        if command.split('|') == "green":
            green_prc += 1
            if green_prc == 10:
                green_prc = 0
                server.green_score += 1
                server.GREEN_SCORE_LABEL.text = str(server.green_score)
        elif command.split('|') == "orange":
            orange_prc += 1
            if orange_prc == 10:
                orange_prc = 0
                server.orange_score += 1
                server.ORANGE_SCORE_LABEL.text = str(server.orange_score)
    else:
        server.send_terminal_message(player.game_terminal_id, "INVALID TELNET COMMAND")
