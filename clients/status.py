import terminal_api
import time

#Terminal type
terminal = 'status'

print('Connecting to server...')

if terminal_api.connect(terminal):
    print('Connected.')
    message = ''

    while terminal_api.active:
        if len(terminal_api.status_queue) > 0:
            message = terminal_api.status_queue.pop()
            print(message)
        time.sleep(1)

    terminal_api.disconnect()
else:
    print("Failed to connect.")
