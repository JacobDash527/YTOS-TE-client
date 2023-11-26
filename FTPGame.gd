extends Node2D

var role = "ftp"
var ip_address = "192.168.1.25"
var port = 23
var level = 0
var backend_files = {}
#Add more interesting prefixes
var possible_file_prefixes = ["goat", "tiger", "chicken", "trout", "salmon", "eagle", "blue", "red", "banana", "kiwi"]
var possible_file_extensions = ["png", "jpg", "mp3", "ogg", "exe", "bin"]

var connections = {}
var external_connections = []

var rng : RandomNumberGenerator = RandomNumberGenerator.new()

#4 for testing, 2 in normal operation
func _ready():
    rng.randomize()
    #Create files

