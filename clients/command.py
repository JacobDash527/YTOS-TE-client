import terminal_api
import os
import platform
import time
from itertools import islice
commands = ['print','next','back','save','scan ips','env','disconnect','help','cls','quit','msg','printenv','keyword','telnet','push','pull','stall','dos','portscan']
commandsdesc = {
    'print':'Print your current IP.',
    'next':'Changes your portrait to the right.',
    'back':'Changes your portrait to the left.',
    'save':'Saves all settings.',
    'msg:<message content>':'Sends a message to your team.',
    'scan ips':'Sends a request to the server for an IP scan. May fail if insufficient intel. Can only be run when not connected to a device.',
    "keyword:<keyword>":"Submits an opponent's keyword for verification. If correct, adds 10 intel/score. If incorrect, removes 10.",
    'telnet:<ip><port>':"Attempts to initiate a connection to a telnet device at a cost of intel.",
    'env':'List all environment variables on target device, if connected via telnet.',
    'printenv:<env variable>':'Outputs the contents of an environment variable, if connected via telnet.',
    'disconnect':'Closes a connection to a device.',
    'push <keyword><name>':'Pushes your keyword to a teammate.',
    'pull <keyword><name>':'Pulls a keywrod from your teammate.',
    'stall':'Adds 45 seconds to the game timer.',
    'portscan <ip>':'Returns the open port of the targeted IP address.',
    'dos <ip>':'Locks out the target IP from their terminals for 10 seconds.',
    'cls':'Clear terminal.',
    'quit':'Exits the game.'
}



terminal = 'command'
console = terminal_api.console
console.print('Connecting to server...')

current_os = "Windows"
if platform.system() != "Windows":
    current_os = "Other"
    os.system('clear')
else:
    os.system('cls')
    os.system(f'mode con: cols={terminal_api.command_width} lines={terminal_api.command_height}')

if terminal_api.connect(terminal):
    console.print('Connected.')
    team_colour = terminal_api.team_colour

    terminal_api.prompt = f"[{team_colour}]{terminal_api.name}[/{team_colour}]@[{team_colour}]{terminal_api.game_ip_address}[/{team_colour}]>"
    
    if team_colour == 'green':
        opponent_colour = 'orange1'
    else:
        opponent_colour = 'green'

    message = ''

    while message != 'quit':
        terminal_api.prompt2 = f"[{team_colour}]{terminal_api.name}[/{team_colour}]@[bold white]{terminal_api.game_connection['connection_type']}[/bold white]@[{opponent_colour}]{terminal_api.game_connection['connection_ip']}[/{opponent_colour}]>"
        if terminal_api.game_connection['connection_ip'] != '':
            message = console.input(terminal_api.prompt2)
        else:
            message = console.input(terminal_api.prompt)
        if message == '':
            continue
        if any(message.startswith(command) for command in commands):
            if message == 'print':
                print(f'My ID: {terminal_api.game_ip_address}')
            elif message == "next":
                terminal_api.head += 1
                terminal_api.send(f"head:{terminal_api.head}")
            elif message == "back":
                terminal_api.head -= 1
                terminal_api.send(f"head:{terminal_api.head}")
            elif message == "save":
                terminal_api.save_settings()
            elif message == "scan ips":
                terminal_api.send(message)
            elif message == "env":
                terminal_api.send(message)
            elif message == 'disconnect':
                terminal_api.game_connection['connection_ip'] = ''
                terminal_api.game_connection['connection_type'] = ''
                terminal_api.send(message)
            elif message == 'cls':
                os.system('cls')
            elif message == 'quit':
                continue
            elif message == 'help':
                console.print('Error: help requires an argument, e.g. help 1')
            elif message.startswith('help') and len(message.split(' ')) != 2:
                console.print('Error: invalid argument for help, e.g. help 1')
            elif message.startswith('help') and len(message.split(' ')) == 2:
                try:
                    n = int(message.split(' ')[1])
                    for command in islice(commandsdesc,-5+(n*5),0+(n*5)):
                        l1 = []
                        fline = True
                        desc = commandsdesc[command].split(' ')
                        for i in range(len(desc)):
                            l1.append(desc[i])
                            if fline == True:
                                if len(l1) == 7:
                                    print(
                                        command.ljust(20),
                                        ' '.join(l1)
                                    )
                                    fline = False
                                    l1 = []
                                elif desc[i] == desc[-1]:
                                    print(
                                        command.ljust(20),
                                        ' '.join(l1)
                                    )
                                    fline = False
                                    l1 = []
                            else:
                                if len(l1) == 7:
                                    print(
                                        ''.ljust(20),
                                        ' '.join(l1)
                                    )
                                    l1 = []
                                elif desc[i] == desc[-1]:
                                    print(
                                        ''.ljust(20),
                                        ' '.join(l1)
                                    )
                                    l1 = []
                except(ValueError):
                    console.print('Error: invalid argument for help, e.g. help 1')
                    # console.print(f"{command:<25}")
            elif message == 'msg' or message == 'msg:':
                console.print('Error: msg requires an argument, e.g. msg:Hello!')
            elif message == 'keyword' or message == 'keyword:':
                console.print('Error: keyword requires an argument, e.g. keyword:SECRETWORD')
            elif message == 'telnet':
                console.print('Error: telnet require arguments, e.g. telnet 123.324.234.523 7343')
            elif message == 'printenv':
                console.print('Error: printenv requires an argument, e.g. printenv FILES')
            else:
                terminal_api.send(message)                
        else:
            console.print("[red]Error: Command not found. Type[/red] [bold white]'help'[/bold white] [red]for a list of available commands[/red]")
        time.sleep(0.2)
    terminal_api.disconnect()
                    
else:
    print("Failed to connect.")
