import terminal_api

settings_filename = 'client_settings.txt'

terminal = 'game'

print('Connecting to server...')

if terminal_api.connect(terminal):
    print('Connected.')

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
