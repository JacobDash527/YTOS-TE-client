import terminal_api
import time
import os
import platform
#check to see how we can fill the screen on the windows laptops
#Does this break macs?

current_os = "Windows"

if platform.system() != "Windows":
    current_os = "Other"

#Size the cmd prompt. EMBIGGEN!
if current_os == "Windows":
    os.system('mode con: cols=100 lines=60')
console = terminal_api.console

#Win10 default cmd prompt size appears to be 120 chars wide by 30 chars tall
#This gives us limited vertical real estate - 
#todo: store the last X messages in a list and print them when new messages arrive
chat_log = []
MAX_CHAT_LOG_HISTORY = 5

#Number of seconds to wait between status updates
UPDATE_DELAY = 1

game_log = []
MAX_GAME_LOG_HISTORY = 3

#Terminal type
terminal = 'status'

player_name_colour_options = ["cyan", "magenta", "red", "yellow"]
player_name_colours = {}

team_colour = "orange1"
if terminal_api.team == "green":
    team_colour = "green"

my_colour = player_name_colour_options.pop(0)
player_name_colours[terminal_api.name] = my_colour

def clear_screen():
    if current_os == "Windows":
        os.system('cls')
    else:
        os.system('clear')

#Top line info always appears at the top of the console - username and IP address
def print_top_line_info():
    console.print(f"[{team_colour}]User[/{team_colour}] [{my_colour}]{terminal_api.name}[{my_colour}] [{team_colour}]connected from {terminal_api.game_ip_address}[/{team_colour}]")

#Chatlog currently appears directly under the top line info - maybe would be better at the bottom? Currently max 5 lines
def print_chat_log():
    for chat_message in chat_log:
        console.print(chat_message)
        
def print_game_log():
    for game_message in game_log:
        console.print(game_message)

print('Connecting to server...')

if terminal_api.connect(terminal):
    clear_screen()

    while terminal_api.active:
        clear_screen() 
        print_top_line_info()
        for i in range(len(terminal_api.status_queue)):             
            message = terminal_api.status_queue.pop(0)
            if message.startswith("msg:"):
                message = message[4:]
                colon_position = message.find(':')
                msg_sender = message[0:colon_position]
                msg_content = message[colon_position+1:]
                name_colour = ""
                if msg_sender not in player_name_colours:                    
                    player_name_colours[msg_sender] = player_name_colour_options.pop(0)
                name_colour = player_name_colours[msg_sender]
                chat_log.append(f"[{name_colour}]{msg_sender}:[/{name_colour}]{msg_content}")
                if len(chat_log) > MAX_CHAT_LOG_HISTORY:
                    chat_log.pop(0)
            elif message.startswith("game:"):
                message = message[5:]
                game_log.append(message)
                if len(game_log) > MAX_GAME_LOG_HISTORY:
                    game_log.pop(0)
        print_chat_log()
        print_game_log()
        time.sleep(UPDATE_DELAY)

    terminal_api.disconnect()
else:
    print("Failed to connect.")
