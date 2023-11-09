extends Node2D

var role = "telnet"
var ip_address = "192.168.1.25"
var port = 23
var level = 0
var environment_variables = {}
var possible_variables = {"LANG":"en_AU", "LOGNAME":"Clarence", "HOME":"/home/user", "SHELL":"/bin/qsh", "TERM":"qterm", "USER":"clarence"}

var allowed_prefix = "192.0.3"
var possible_prefixes = ["192.0.3", "128.50", "169.255.15", "100.128"]

#4 for testing, 2 in normal operation
func _ready():
    add_environment_variable()
    add_environment_variable()
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
    var env_list = "\n"
    print(environment_variables)
    print(possible_variables)
    var env_vars = environment_variables.keys()
    for env_variable in env_vars:
        env_list += env_variable + "\n"
    return env_list
