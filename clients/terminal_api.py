from websocket import create_connection
import threading
import asyncio
import json
import os

path = os.path.dirname(__file__)
settings_filename = os.path.join(path,'client_settings.txt')

active = True
last_server_message = ''
server_message = ''

#variables from server:
#encounter_state (WAITING, IN_PROGRESS, ENDED_FAIL, ENDED_WIN, UDEAD)

playername = 'Hacker'
role = 'telnet'

server_fails = 0
status_queue = []

#Default settings - don't change these!
ip = '127.0.0.1'
port = 9876
name = 'plague'
team = 'green'
role = 'telnet'
head = 1
terminal = 'command'

def get_setting(setting_line):
    return setting_line[5:].strip()

def save_settings():
    with open (settings_filename, 'w') as settings:
        settings.write(f'ip:{ip}\n')
        settings.write(f'port:{port}\n')
        settings.write(f'user:{name}\n')
        settings.write(f'team:{team}\n')
        settings.write(f'role:{role}\n')
        settings.write(f'head:{head}\n')

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
          head = int(get_setting(line))

#Listener thread receives responses from the server
#It writes to global variables for access via other functions
def listener(server):
  global server_message
  global last_server_message
  global server_fails
  global active
  global status_queue
  while active:
    #This try/except is too broad - should only capture network issues
    try:
      server_message = server.recv().decode("utf-8")
      if server_message.startswith('state:'):
        state = json.loads(server_message[6:])
        global playername 
        playername = state['name']
        global connection_id 
        connection_id = state['id']
      elif server_message.startswith('msg:'):
        message = json.loads(server_message[4:])
        sender = message['name']
        content = message['content']
        status_queue.append(sender+': '+content) 
        #print(f'{sender}: {content}', end='\n> ')
      elif server_message.startswith('item:'):
        item = server_message[5:]
        print(f'New item: {item}', end='\n> ')
      elif server_message.startswith('status:'):
        status_queue.append(server_message[7:])
        print(f'New item: {item}', end='\n> ')
      else:
        if last_server_message != server_message:
            print(server_message, end='\n> ')
        else:
            last_server_message = server_message
    except:
      #Should log failures
      server_fails += 1

def send(message):
  global server
  server.send(message)

def remove_item(item):
  send(f'kill:{item}')

def disconnect():
  global server
  global active
  active = False
  server.close()

#Join request sent using: "join:<name>|<team>|<role>"
#For robustness in future, should be base64 encoded or similar
def connect(terminal):
  global server
  connected = False
  try:
    server = create_connection(f'ws://{ip}:{port}')
    server.send(f'join:{name}|{team}|{role}|{terminal}|{head}')
    conn_id = server.recv()
    print(conn_id)
    message = ''
    listener_thread = threading.Thread(target = listener, args=(server,))
    listener_thread.start()
    connected = True
  except:    
    print("Error connecting to the server.")
  return connected
