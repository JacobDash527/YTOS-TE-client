import terminal_api

terminal = 'command'

print('Connecting to server...')

if terminal_api.connect(terminal):
    print('Connected.')

    message = ''

    while message != 'quit':
        message = input('> ')
        if message == 'print':
            print(f'My ID: {terminal_api.connection_id}')
        #Should do basic checking for valid format, arguments, IPs
        elif message.startswith('telnet'):
            terminal_api.send(message)
        elif message == "next":
            terminal_api.head += 1
            terminal_api.send(f"head:{terminal_api.head}")
        elif message == "back":
            terminal_api.head -= 1
            terminal_api.send(f"head:{terminal_api.head}")
        elif message == "save":
            terminal_api.save_settings()
        else:
            terminal_api.send(message)

    terminal_api.disconnect()
else:
    print("Failed to connect.")
