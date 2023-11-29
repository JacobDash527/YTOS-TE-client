extends Node

onready var settings_file = 'res://client_settings.txt'

var settings = []

var user
var team
var role
var addr
var port
var head
var terminal = 'game'
var connected = false

var client = WebSocketClient.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    var client_settings = File.new()
    client_settings.open(settings_file, File.READ)
    
    while not client_settings.eof_reached():
        settings.append(client_settings.get_line().split(':')[1])
    
    user = settings[0]
    team = settings[1]
    role = settings[2]
    addr = settings[3]
    port = int(settings[4])
    head = int(settings[5])

    client.connect("connection_closed", self, "_closed")
    client.connect("connection_error", self, "_closed")
    client.connect("connection_established", self, "_connected")
    client.connect("data_received", self, "_on_data")
    var err = client.connect_to_url("ws://" + addr + ":" + str(port))
    if err != OK:
        print("Unable to connect")
        set_process(false)
    else:
        print("Okay!")
    
func get_setting(setting_line):
    var setting_line_array = setting_line.split(":")
    if len(setting_line_array) == 2:
        return setting_line_array[1].strip_edges()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
    client.poll()

func _closed():
    $Game/Panel/Label.text = 'Lost connection to server...'

func _on_data() -> void:
    var pkt = client.get_peer(1).get_packet()
    var incoming = pkt.get_string_from_utf8()
    print('Server says: ' + incoming)
    $Game/Panel/Label.text = incoming
    
func _connected(protocol: String) -> void:
    print("CONNECTED!")
    var message = ('join:' + user + '|' + team + '|' + role + '|' + terminal + '|' + str(head)).to_utf8()
    client.get_peer(1).put_packet(message)


func _on_LineEdit_text_entered(new_text):
    client.get_peer(1).put_packet(new_text.to_utf8())
