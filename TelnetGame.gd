extends Node2D

var role = "telnet"
var ip_address = "192.168.1.25"
var port = 23
var level = 0
var environment_variables = {}
var possible_variables = {"LANG":"en_AU", "LOGNAME":"Clarence", "HOME":"/home/user", "SHELL":"/bin/qsh", "TERM":"qterm", "USER":"clarence"}

var allowed_prefix = "192.0.3"
var possible_prefixes = ["192.0.3", "128.50", "169.255.15", "100.128"]
var connections = {}
var external_connections = []

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

#4 for testing, 2 in normal operation
func _ready():
    rng.randomize()
    add_environment_variable()
    add_environment_variable()
    allowed_prefix = possible_prefixes[randi() % possible_prefixes.size()]
    
#Pulls an env var at random and removes it from the possible list, adding it to the actual list
func add_environment_variable():
    var environment_keys = possible_variables.keys()
    var environment_variable = environment_keys[randi() % len(environment_keys)]
    var variable_value = possible_variables[environment_variable]
    environment_variables[environment_variable] = variable_value
    possible_variables.erase(environment_variable)
    
func set_keyword(environment_variable, keyword):
    if environment_variables.has(environment_variable):
        environment_variables[environment_variable] = keyword

func get_variable(environment_variable):
    if environment_variables.has(environment_variable):
        return environment_variables[environment_variable]
        
func list_environment_variables():
    var env_vars = environment_variables.keys()
    env_vars.shuffle()
    return "\n" + "\n".join(env_vars)

func list_connections():
    return "\n" + "\n".join(connections.keys())

func get_octet():
    return str(rng.randi_range(1,254))   

func add_connection(new_ip):
    var connection_ip = false
    if new_ip == "dummy":
        if randi() % 3 == 1:
            connection_ip = get_octet() + "." + get_octet() + "." + get_octet() + "." + get_octet()
        else:
            var octet_array = [allowed_prefix]
            for _i in range(3-allowed_prefix.count(".")):
                octet_array.append(get_octet())
            connection_ip = ".".join(octet_array)
        if !connections.has(connection_ip):
            connections[connection_ip] = rng.randi_range(15,25)
        return connection_ip
    else:
        external_connections.append(new_ip)
        var ttl = rng.randi_range(15,25)
        connections[new_ip] = ttl
        return str(ttl)

func remove_connection(target_ip):
    var good_move = false
    if connections.has(target_ip):
        if !target_ip.begins_with(allowed_prefix):
            good_move = true
        connections.erase(target_ip)
    return good_move

func expire_connections():
    var expired = {}
    for connection in connections:
        connections[connection] -= 1
        if connections[connection] <= 0:
            expired[connection] = remove_connection(connection)
    return expired

func expire_items():
    return expire_connections()

func get_criteria():
    return "accept all connections from " + allowed_prefix

func level_up():
    level += 1
    if level % 5 == 0:
        add_environment_variable()

func parse_command(command, player, server):
    if command == "show cnx":
        server.send_terminal_message(player.game_terminal_id, list_connections())
    elif command.begins_with("kick "):
        var games = server.games
        var target_ip = command.right(len("kick "))
        if games[player.game_ip_address].remove_connection(target_ip):
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
    else:
        server.send_terminal_message(player.game_terminal_id, "INVALID TELNET COMMAND")
