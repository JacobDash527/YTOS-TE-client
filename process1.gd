extends Node2D

var cpu_slots = [[40,43,'null'], [95,43,'null'], [150,43,'null'], [205,43,'null']]
var idle_slots = [[40,124,'null'], [95,124,'null'], [150,124,'null'], [205,124,'null'],[260,124,'null'], [315,124,'null'], [40,189,'null'], [95,189,'null'], [150,189,'null'], [205,189,'null'], [260,189,'null'], [315,189,'null'], [40,254,'null'], [95,254,'null'], [150,254,'null'], [205,254,'null'], [260,254,'null'], [315,254,'null'], [40,319,'null'], [95,319,'null'], [150,319,'null'], [205,319,'null'], [260,319,'null'], [315,319,'null']] 

var y = 0
var x = 0
var slot_num = 0
var num_processes = 1
var cpu_slots_filled = 0

#$button2D/Button/RichTextLabel.text = '2'
#for later I guess

#func input(data):
#	var type = data.split(':')[]0
#	data = data.right(6).split('|')
#
#	if type == 's_prc':
#		pass
#	elif type == 's_rge':
#		pass

func _ready():
    for i in range(1, 10):
        _on_Button_pressed()
    generate_processes()
    test_loading()

func _process(delta):
    yield(get_tree().create_timer(0.1), "timeout")
    for button in get_tree().get_nodes_in_group('buttons'):
        var time_left = button.get_node('process_timer').time_left
        if time_left <= 80 and time_left >= 70:
            button.icon = load("res://process_icons/yellow_process.png")
        elif time_left <= 70 and time_left >= 60:
            button.icon = load("res://process_icons/orange_process.png")
        elif time_left <= 60 and time_left >= 45:
            button.icon = load("res://process_icons/red_process.png")
        elif time_left <= 45 and time_left >= 30:
            button.icon = load("res://process_icons/dark_red_process.png")
        elif time_left <= 30 and time_left >= 15:
            button.icon = load("res://process_icons/bing_chilling_process.png")

func test_loading():
    var bar_complete = false
    while bar_complete == false:
        yield(get_tree().create_timer(0.01), "timeout")
        var scl = $ProcessNode/Button/Sprite.scale
        var pos = $ProcessNode/Button/Sprite.position
        $ProcessNode/Button/Sprite.scale = Vector2(scl[0] + 0.005, 0.04)
        $ProcessNode/Button/Sprite.position = Vector2(pos[0] + 0.366, 117)
        if scl[0] >= 0.753:
            bar_complete = true

func generate_processes():
    if num_processes == 25:
        pass
    else:
        var rng = RandomNumberGenerator.new()
        rng.randomize()
        rng = rng.randi_range(5,10)
        
        yield(get_tree().create_timer(rng), "timeout")
        _on_Button_pressed()
        generate_processes()

func _on_Button_pressed():
    if num_processes == 25:
        pass
    else:
        var process = Node2D.new()
        var process_button = Button.new()
        var PID = RichTextLabel.new()
        var timer = Timer.new()
        
        process_button.icon = load("res://process_icons/green_process.png")
        process_button.add_to_group('buttons')
        process_button.flat = true
        process_button.name = str(str(num_processes), '|IDLE')
        
        PID.text = str(num_processes)
        PID.margin_left = 92
        PID.margin_top = 12
        PID.margin_right = 129
        PID.margin_bottom = 35
        PID.rect_scale = Vector2(3, 2)
        
        timer.wait_time = 90
        timer.autostart = true
        timer.name = 'process_timer'
        timer.one_shot = true
        
        process_button.add_child(timer)
        process_button.add_child(PID)
        process.add_child(process_button)
        
        num_processes += 1
        
        for i in idle_slots:
            if i[2] == 'null':
                x = i[0]
                y = i[1]
                i[2] = process_button.name
                break
            else:
                pass

        process.position = Vector2(x, y)
        process.scale = Vector2(0.378, 0.393)
        add_child(process)

        for button in get_tree().get_nodes_in_group("buttons"):
            button.connect("pressed", self, "_some_button_pressed", [button])

func _some_button_pressed(button):
    var bname = button.name.split('|')
    
    if bname[1] == 'IDLE':
        if cpu_slots_filled == 4:
            pass
        else:
            for i in idle_slots:
                if i[2] == button.name:
                    i[2] = 'null'
                    for j in cpu_slots:
                            if j[2] == 'null':
                                x = j[0]
                                y = j[1]
                                button.get_parent().position = Vector2(x, y)
                                button.name = str(bname[0], '|CPU')
                                j[2] = button.name
                                cpu_slots_filled += 1
                                button.get_node('process_timer').stop()
                                process_process(button)
                                break
                            else:
                                pass
                else:
                    pass

    elif bname[1] == 'CPU':
        for i in cpu_slots:
            if i[2] == button.name:
                i[2] = 'null'
                for j in idle_slots:
                        if j[2] == 'null':
                            x = j[0]
                            y = j[1]
                            button.get_parent().position = Vector2(x, y)
                            button.name = str(bname[0], '|IDLE')
                            j[2] = button.name
                            cpu_slots_filled += -1
                            if button.has_node('bar'):
                                button.get_node('bar').queue_free()
                            button.get_node('process_timer').start()
                            break
                        else:
                            pass
            else:
                pass

func process_process(button):
#	button.icon = load("res://loading_bar.png")
#	yield(get_tree().create_timer(10), "timeout")
    
    var bar = Sprite.new()
    bar.texture = load("res://loading_bar.png")
    bar.name = 'bar'
    bar.scale = Vector2(0.046, 0.04)
    bar.position = Vector2(15.525, 117)
    button.add_child(bar)
    
    var bar_complete = false
    while bar_complete == false:
        yield(get_tree().create_timer(0.01), "timeout")
        if button.has_node('bar'):
            bar = button.get_node('bar')
            var scl = bar.scale
            var pos = bar.position
            bar.scale = Vector2(scl[0] + 0.005, 0.04)
            bar.position = Vector2(pos[0] + 0.366, 117)
            if scl[0] >= 0.753:
                bar_complete = true
        else:
            pass
    
    button.remove_child(bar)
    button.icon = load("res://process_icons/green_process.png")
