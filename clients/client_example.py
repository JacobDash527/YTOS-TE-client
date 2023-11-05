import terminal_api

#These settings need to be pulled from a text file
ip = '127.0.0.1'
port = 9876
name = 'plague'
team = 'green'
role = 'telnet'

print("Connecting to server...")

if terminal_api.connect(name, team, role, ip, port,):
    print('Connected.')
    print('Remove all warm colours, keep all cool colours.')

    message = ''

    while message != 'quit':
        message = input('> ')
        if message == 'print':
            print(f'My ID: {terminal_api.connection_id}')
        elif message.startswith('rem:'):
            terminal_api.remove_item(message[4:])
        else:
            terminal_api.send(message)

    terminal_api.disconnect()
else:
    print("Failed to connect.")