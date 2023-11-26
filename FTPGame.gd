extends Node2D

var role = "ftp"
var ip_address = "192.168.1.25"
var port = 21
var level = 0
var backend_files = {}
#The maximum number of files that can sit in the frontend
var max_files = 6
#Add more interesting prefixes
var possible_file_prefixes = ["goat", "tiger", "chicken", "trout", "salmon", "eagle", "blue", "red", "banana", "kiwi"]
var possible_file_extensions = ["png", "jpg", "mp3", "ogg", "exe", "bin"]
var dummy_contents = ["Generate some short nonsense for this list", "Try mockaroo's AI generated thing"]
var current_files = []
var forbidden_file_types = []
var download_file_types = []
#Files in the transfer queue get added periodically to current files
var transfer_queue = []
var upload_file_name = ""

var external_connections = {}

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    #Generate 4 files+extensions and add them to the backend files dictionary, along with randomly selected dummy_contents
    #Create directives
    
func create_directives():
    pass
    #Pick two extensions to make forbidden, append them to the forbidden array
    #Pick a file name to download - add it to the transfer queue
    #Pick a file name to request uploaded

#This gets called by the server when someone requests to push/pull to the game terminal
func add_keyword(sender, receiver, server, keyword):
    var success = false
    var response_message = "Unable to push/pull keyword. Unknown error."
    if len(backend_files) > len(receiver.keywords):
        if keyword in sender.keywords:
            var file_names = backend_files.keys()
            var file_name = file_names.pop_front()
            var still_looking = true
            while still_looking:
                if not (backend_files[file_name] in receiver.keywords):
                    still_looking = false
                    backend_files[file_name] = keyword
                    success = true
                if len(file_names) > 0:
                    file_name = file_names.pop_front()
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
    for file_name in backend_files:
        if backend_files[file_name] == keyword:
            backend_files[file_name] = dummy_contents[randi() % len(dummy_contents)]

#Retrieves the contents of a backend file
func get_file_contents(file_name):
    if backend_files.has(file_name):
        return backend_files[file_name]

func list_files():
    var file_names = backend_files.keys()
    file_names.shuffle()
    return "\n" + "\n".join(file_names)

func list_connections():
    return "\n" + "\n".join(external_connections.keys())

#Adds a file to the current_files array
func add_file(new_file):
    pass

#Slightly modified version of telnet one - the player has requested to rm a file
#The function should figure out if this was a good move and add or remove intel as necessary
#Plus - if this was an intruder's file created when they connected, kick them off
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

#Not entirely like telnet - when a file "expires" it isn't necessarily removed - 
#good files continue to earn intel and bad continue to subtract it
#"Expired" files should be removed around 25% of the time
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
#Decide what the FTP backend will do each second - it will report back on lost/gained intel from files
#It should also sometimes issue new directives and change forbidden files, files to upload and download
#This also checks the player "wait time" variable, which indicates how often a new set of files arrives on the server
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

#This will increase the maximum files on the server every X levels and also add another backend file every Y levels
#Decide what works for you
#Level ups should occur whenever a player downloads or uploads a file correctly
func level_up():
    pass
    """
    level += 1
    if level % 5 == 0:
        add_environment_variable()
    """

#Check for commands that an attacker can use in this function
#You will need to parse two attacker commands: ls and get <filename> -
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

#Check for commands that the owner can use in this function
#You will need to parse the following:
#ls
#rm <filename>
#get <filename>
#put <filename>
#port shift (exactly the same code as in telnet)
#drop spyware <ip> (costs 5 intel)
#enable * (costs 10 intel)
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
    else:
        server.send_terminal_message(player.game_terminal_id, "INVALID TELNET COMMAND")
