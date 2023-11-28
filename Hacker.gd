extends Control

var hacker_name = 'Hacker'
var team = 'green'
var role = 'telnet'
var status_terminal_id = 0
var command_terminal_id = 0
var game_terminal_id = 0
var address = '127.0.0.1'
var game_ip_address = "192.168.1.10"
var game_connection = ""
var criteria = ""
var wait_time = 5
var abilities = []
var portrait = 1
var keywords = []
var dos_timer = 0

var ping_location: Vector2 = Vector2(800, 300)
var dos_location:Vector2 = Vector2(800, 300)
var telnet_location:Vector2 = Vector2(800, 300)


onready var lineStart = $HBoxContainer/PortraitSprite/Telnet.points[0]
onready var lineEnd = $HBoxContainer/PortraitSprite/Telnet.points[1]

func _process(_delta):
    set_up_colours()
    set_particle_ending($HBoxContainer/PortraitSprite/Ping, ping_location)
    set_particle_ending($HBoxContainer/PortraitSprite/Dos, dos_location)
    $HBoxContainer/PortraitSprite/Telnet.points[0] = lineStart
    $HBoxContainer/PortraitSprite/Telnet.points[1] = lineEnd

func stall():
    $HBoxContainer/PortraitSprite/Stall.visible = true
    $HBoxContainer/PortraitSprite/Stall/Timer.start()

func ping_person(h: Node):
    $HBoxContainer/PortraitSprite/Ping.emitting = true
    ping_location = h.rect_global_position

func dos_person(h : Node):
    $HBoxContainer/PortraitSprite/Dos.emitting = true
    dos_location = h.rect_global_position
    $HBoxContainer/PortraitSprite/Dos/Timer.start()

func set_particle_ending(particleNode: Particles2D, location : Vector2):
    var direction2D:Vector2 = particleNode.global_position.direction_to(location)
    particleNode.process_material.angle = -rad2deg(direction2D.angle())
    particleNode.process_material.direction = Vector3(direction2D.x, direction2D.y, 0)
    particleNode.process_material.initial_velocity = particleNode.global_position.distance_to(location)/particleNode.lifetime

func create_telnet_connection():
    $HBoxContainer/PortraitSprite/Telnet.points[0] = Vector2(32, 32)
    $Tween.interpolate_property(self, "lineEnd", Vector2(32, 32), telnet_location, 2.5, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 10.0)
    print("telnet_location: " + str(telnet_location))
    $Tween.start()

func close_telnet_connection():
    $Tween.stop_all()
    $Tween.remove_all()
    $Tween.interpolate_property(self, "lineStart", lineStart, lineEnd, 1.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
    $Tween.start()

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
    return "Hacker: " + hacker_name + " (" + team + ") " + role + " status:" + str(status_terminal_id) + " cmd:" + str(command_terminal_id) + " game:" + str(game_terminal_id) + " ip:" + address + " ability " + str(abilities)

func set_status_terminal_id(id):
    status_terminal_id = id
    
func set_command_terminal_id(id):
    command_terminal_id = id
    
func set_game_terminal_id(id):
    game_terminal_id = id

func add_ability(ability):
    abilities.append(ability)
    $HackerAbilityLabel.text += ability + "\n"

func set_portrait(portrait_id):
    var filesystem = File.new()
    var portrait_file_path = "res://portraits/" + portrait_id + ".png"
    if filesystem.file_exists(portrait_file_path):
        portrait = portrait_id
        var texture = load(portrait_file_path)
        $HBoxContainer/PortraitSprite.texture = texture

func set_up_colours():
    if team == 'green':
        $HBoxContainer/PortraitSprite/Pulse.modulate = Color("1dc146")
        $HBoxContainer/PortraitSprite/Ping.modulate = Color("1dc146")
        $HBoxContainer/PortraitSprite/Telnet.default_color = Color("1dc146")

func train(new_name, new_team, new_role, new_address, new_game_ip_address, new_portrait):
    hacker_name = new_name
    $HBoxContainer/HackerNameLabel.text = hacker_name
    team = new_team
    role = new_role
    address = new_address
    game_ip_address = new_game_ip_address
    set_portrait(new_portrait)
    set_up_colours()



func _on_Timer_timeout():
    $HBoxContainer/PortraitSprite/Dos.emitting = false


func _on_Stall_Timer_timeout():
    $HBoxContainer/PortraitSprite/Stall.visible = false
