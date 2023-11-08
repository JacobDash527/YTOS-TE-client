import terminal_api

settings_filename = 'client_settings.txt'

#Default settings - don't change these!
ip = '127.0.0.1'
port = 9876
name = 'plague'
team = 'green'
role = 'telnet'
terminal = 'command'

def get_setting(setting_line):
    return setting_line[5:].strip()

#This could be more robust! But good enough for now!
with open (settings_filename, 'r') as settings:
    for line in settings.readlines():
      if line.startswith('addr:'):
          ip = get_setting(line)
      elif line.startswith('port:'):
          port = get_setting(line)
      elif line.startswith('user:'):
          name = get_setting(line)
      elif line.startswith('team:'):
          team = get_setting(line)
      elif line.startswith('role:'):
          role = get_setting(line)
      elif line.startswith('head'):
          head = get_setting(line)

print('Connecting to server...')

if terminal_api.connect(name, team, role, terminal, head, ip, port):
    print('Connected.')

    message = ''

    while message != 'quit':
        message = input('> ')
        if message == 'print':
            print(f'My ID: {terminal_api.connection_id}')
        #Should do basic checking for valid format, arguments, IPs
        elif message.startswith('telnet'):
            terminal_api.send(message)
        else:
            terminal_api.send(message)

    terminal_api.disconnect()
else:
    print("Failed to connect.")
