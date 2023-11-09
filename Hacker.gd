extends Node2D

export var hacker_name = 'Hacker'
export var team = 'green'
export var role = 'telnet'
export var status_terminal_id = 0
export var command_terminal_id = 0
export var game_terminal_id = 0
export var address = '127.0.0.1'
var game_ip_address = "192.168.1.10"
var game_connection = ""
var criteria = ""
var wait_time = 5
var ability = "ipscan"

#Deprecated?    
func get_state():
    var state = {}
    state['id'] = status_terminal_id
    state['name'] = hacker_name
    state['role'] = role
    state['team'] = team
    state['address'] = address
    return state

func to_string():
    return "Hacker: " + hacker_name + " (" + team + ") " + role + " status:" + str(status_terminal_id) + " cmd:" + str(command_terminal_id) + " game:" + str(game_terminal_id) + " ip:" + address

func set_status_terminal_id(id):
    status_terminal_id = id
    
func set_command_terminal_id(id):
    command_terminal_id = id
    
func set_game_terminal_id(id):
    game_terminal_id = id

func train(new_name, new_team, new_role, new_address, new_game_ip_address):
    hacker_name = new_name
    team = new_team
    role = new_role
    address = new_address
    game_ip_address = new_game_ip_address
