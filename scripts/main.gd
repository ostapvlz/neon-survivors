extends Node2D
# NEON SURVIVORS: ECHOES OF DAWN
# Godot 4.3+. Portrait mobile roguelite prototype.
# Move: drag on the left side of the screen. Attacks are automatic.
# Desktop testing: hold left mouse button and drag.

const W := 720.0
const H := 1280.0
const PLAYER_SPEED := 340.0
const XP_BASE := 7

const PLANETS := [
    {"name":"АРКАДИЯ-9", "subtitle":"Мёртвый сад", "desc":"Здесь замолчали первые колонии. Под корнями деревьев спрятан фрагмент навигационного ядра.", "boss":"КОРНЕВОЙ СТРАЖ", "enemy":"Споровики", "color":Color("74e6a0"), "boss_hp":520.0},
    {"name":"КРАСНЫЙ ПРИТОК", "subtitle":"Пустыня машин", "desc":"Песок помнит войну. Автоматические фабрики продолжают собирать армию без хозяев.", "boss":"ОСАДНЫЙ ТИТАН", "enemy":"Ржавые дроны", "color":Color("ff9b62"), "boss_hp":760.0},
    {"name":"НИКС", "subtitle":"Ледяная тишина", "desc":"Подо льдом передаётся сигнал. Он повторяет голос пропавшей экспедиции.", "boss":"ЛЕДЯНАЯ МАТРИАРХ", "enemy":"Крио-осколки", "color":Color("81d9ff"), "boss_hp":980.0},
    {"name":"ВЕЛЕС", "subtitle":"Город-призрак", "desc":"Городские башни питаются энергией людей. В центре ждёт тот, кто включил маяк.", "boss":"АРХИВАРИУС", "enemy":"Фантомы", "color":Color("c49aff"), "boss_hp":1250.0},
    {"name":"НУЛЕВОЕ СОЛНЦЕ", "subtitle":"Источник сигнала", "desc":"За разломом находится разум, который обещал спасти человечество. Но спасение оказалось клеткой.", "boss":"ЭХО-ПРАЙМ", "enemy":"Порождения разлома", "color":Color("ff668e"), "boss_hp":1750.0}
]

const UPGRADES := [
    {"name":"Плазменное ядро", "info":"Урон оружия +30%", "id":"damage"},
    {"name":"Ускоритель катушки", "info":"Скорость стрельбы +20%", "id":"rate"},
    {"name":"Расщепитель", "info":"Дополнительный снаряд", "id":"multi"},
    {"name":"Наноброня", "info":"Получаемый урон меньше", "id":"armor"},
    {"name":"Грави-магнит", "info":"Радиус сбора опыта +50%", "id":"magnet"},
    {"name":"Ремонтный рой", "info":"Восстановить 35 здоровья", "id":"heal"}
]

var state := "menu"
var planet_index := 0
var unlocked_planet := 0
var player := Vector2(360, 850)
var hp := 100.0
var max_hp := 100.0
var damage := 26.0
var fire_delay := 0.58
var projectile_count := 1
var armor := 0.0
var magnet_radius := 125.0
var level := 1
var xp := 0
var coins := 0
var lifetime_kills := 0
var run_kills := 0
var elapsed := 0.0
var spawn_timer := 0.0
var shot_timer := 0.0
var boss_spawned := false
var boss_defeated := false
var boss_data: Dictionary = {}
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var upgrade_options: Array[Dictionary] = []
var joystick_active := false
var joystick_origin := Vector2.ZERO
var move_vector := Vector2.ZERO
var story_text := ""
var story_title := ""
var story_next := "play"
var story_page := 0
var selected_skin := 0
var skins := [
    {"name":"Пилот", "price":0, "color":Color("55dfff")},
    {"name":"Солнечный", "price":180, "color":Color("ffd36a")},
    {"name":"Призрак", "price":350, "color":Color("c49aff")},
    {"name":"Кровавый", "price":600, "color":Color("ff668e")}
]
var owned_skins := [true, false, false, false]
var player_color := Color("55dfff")
var message := ""
var message_timer := 0.0

func _ready() -> void:
    get_viewport().content_scale_size = Vector2i(720, 1280)
    _load_game()
    player_color = skins[selected_skin].color
    randomize()

func _process(delta: float) -> void:
    message_timer = maxf(0.0, message_timer - delta)
    if state != "play":
        queue_redraw()
        return
    elapsed += delta
    _move_player(delta)
    _spawn_enemies(delta)
    _update_enemies(delta)
    _update_bullets(delta)
    _update_gems(delta)
    _update_particles(delta)
    _shoot(delta)
    if not boss_spawned and elapsed >= 85.0:
        _spawn_boss()
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var p := _to_world(event.position)
        if event.pressed:
            _handle_tap(p)
            if state == "play" and p.x < 430 and p.y > 170:
                joystick_active = true
                joystick_origin = p
                move_vector = Vector2.ZERO
        else:
            joystick_active = false
            move_vector = Vector2.ZERO
    elif event is InputEventScreenDrag:
        if joystick_active and state == "play":
            var p := _to_world(event.position)
            move_vector = (p - joystick_origin).limit_length(1.0)
    elif event is InputEventMouseButton:
        if event.pressed:
            var p := _to_world(event.position)
            _handle_tap(p)
            if state == "play" and p.x < 430 and p.y > 170:
                joystick_active = true
                joystick_origin = p
        else:
            joystick_active = false
            move_vector = Vector2.ZERO
    elif event is InputEventMouseMotion and joystick_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        move_vector = (_to_world(event.position) - joystick_origin).limit_length(1.0)

func _to_world(p: Vector2) -> Vector2:
    return p * Vector2(W, H) / get_viewport_rect().size

func _handle_tap(p: Vector2) -> void:
    if state == "menu":
        if Rect2(90, 720, 540, 105).has_point(p):
            _show_story("ПРОЛОГ", "Год 2189. Земная сеть колоний погасла за одну ночь. Из глубины космоса пришёл сигнал, обещающий вернуть потерянных. Ты — пилот-разведчик последнего корабля «Искра». На пяти мирах нужно собрать фрагменты ядра и выяснить, кто зовёт человечество.", "play")
        elif Rect2(90, 850, 540, 90).has_point(p):
            state = "shop"
        elif Rect2(90, 965, 540, 80).has_point(p):
            state = "planets"
    elif state == "story":
        if p.y > 1030 or p.y > 600:
            state = story_next
            if state == "play":
                _start_run()
    elif state == "planets":
        for i in range(5):
            if Rect2(65, 310 + i * 145, 590, 112).has_point(p) and i <= unlocked_planet:
                planet_index = i
                _show_story("МИССИЯ: " + PLANETS[i].name, PLANETS[i].desc, "play")
                return
        if p.y < 150:
            state = "menu"
    elif state == "shop":
        if p.y < 150:
            state = "menu"
        else:
            for i in range(skins.size()):
                var r := Rect2(70, 280 + i * 175, 580, 130)
                if r.has_point(p):
                    _buy_skin(i)
                    return
    elif state == "upgrade":
        for i in range(upgrade_options.size()):
            if Rect2(55, 470 + i * 145, 610, 112).has_point(p):
                _apply_upgrade(upgrade_options[i].id)
                state = "play"
                return
    elif state == "gameover":
        if Rect2(75, 790, 570, 100).has_point(p):
            _start_run()
        elif Rect2(75, 920, 570, 90).has_point(p):
            state = "menu"
    elif state == "victory":
        if Rect2(75, 840, 570, 100).has_point(p):
            state = "menu"

func _show_story(title: String, body: String, next_state: String) -> void:
    story_title = title
    story_text = body
    story_next = next_state
    state = "story"

func _start_run() -> void:
    state = "play"
    player = Vector2(360, 850)
    hp = max_hp
    damage = 26.0
    fire_delay = 0.58
    projectile_count = 1
    armor = 0.0
    magnet_radius = 125.0
    level = 1
    xp = 0
    run_kills = 0
    elapsed = 0.0
    spawn_timer = 0.2
    shot_timer = 0.2
    boss_spawned = false
    boss_defeated = false
    enemies.clear()
    bullets.clear()
    gems.clear()
    particles.clear()
    joystick_active = false
    move_vector = Vector2.ZERO

func _move_player(delta: float) -> void:
    player += move_vector * PLAYER_SPEED * delta
    player.x = clampf(player.x, 35, W - 35)
    player.y = clampf(player.y, 160, H - 45)

func _spawn_enemies(delta: float) -> void:
    spawn_timer -= delta
    if spawn_timer > 0:
        return
    spawn_timer = maxf(0.28, 1.05 - elapsed * 0.004)
    var side := randi_range(0, 3)
    var pos := Vector2.ZERO
    match side:
        0: pos = Vector2(randf_range(0, W), -35)
        1: pos = Vector2(W + 35, randf_range(150, H))
        2: pos = Vector2(randf_range(0, W), H + 35)
        3: pos = Vector2(-35, randf_range(150, H))
    var variant := randi_range(0, 2)
    var radius := [16.0, 22.0, 13.0][variant]
    var health := [34.0, 82.0, 24.0][variant] * (1.0 + planet_index * 0.18)
    var speed := [90.0, 55.0, 145.0][variant] + elapsed * 0.10 + planet_index * 8
    var col: Color = PLANETS[planet_index].color
    enemies.append({"pos":pos, "hp":health, "max_hp":health, "speed":speed, "radius":radius, "color":col, "damage": [9.0, 15.0, 7.0][variant], "boss":false, "flash":0.0})

func _spawn_boss() -> void:
    boss_spawned = true
    var data: Dictionary = PLANETS[planet_index]
    var pos := Vector2(360, 230)
    var bhp := float(data.boss_hp)
    boss_data = {"pos":pos, "hp":bhp, "max_hp":bhp, "speed":48.0 + planet_index * 4, "radius":58.0, "color":Color("ff527c"), "damage":27.0 + planet_index * 3, "boss":true, "flash":0.0}
    enemies.append(boss_data)
    message = "ВНИМАНИЕ: " + str(data.boss)
    message_timer = 4.0

func _update_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var e: Dictionary = enemies[i]
        var pos: Vector2 = e.pos
        pos += (player - pos).normalized() * float(e.speed) * delta
        e.pos = pos
        e.flash = maxf(0.0, float(e.flash) - delta)
        var contact := player.distance_to(pos) < 30.0 + float(e.radius)
        if contact:
            hp -= maxf(1.0, float(e.damage) - armor) * delta * 1.6
            if hp <= 0:
                hp = 0
                _end_run(false)
                return
        enemies[i] = e

func _shoot(delta: float) -> void:
    shot_timer -= delta
    if shot_timer > 0 or enemies.is_empty():
        return
    shot_timer = fire_delay
    var target: Dictionary = {}
    var best := INF
    for e in enemies:
        var d: float = player.distance_squared_to(e.pos)
        if d < best:
            best = d
            target = e
    if target.is_empty():
        return
    var aim: Vector2 = (target.pos - player).normalized()
    for n in range(projectile_count):
        var spread := deg_to_rad((float(n) - float(projectile_count - 1) / 2.0) * 12.0)
        var dir := aim.rotated(spread)
        bullets.append({"pos":player + dir * 32, "vel":dir * 650.0, "life":1.6, "damage":damage})

func _update_bullets(delta: float) -> void:
    for i in range(bullets.size() - 1, -1, -1):
        var b: Dictionary = bullets[i]
        b.pos += b.vel * delta
        b.life -= delta
        var hit_index := -1
        for j in range(enemies.size() - 1, -1, -1):
            if b.pos.distance_to(enemies[j].pos) < float(enemies[j].radius) + 9:
                hit_index = j
                break
        if hit_index >= 0:
            var e: Dictionary = enemies[hit_index]
            e.hp -= float(b.damage)
            e.flash = 0.12
            if e.hp <= 0:
                if bool(e.boss):
                    _boss_killed()
                    enemies.remove_at(hit_index)
                else:
                    run_kills += 1
                    lifetime_kills += 1
                    coins += 2
                    gems.append({"pos":e.pos, "phase":randf() * TAU})
                    _burst(e.pos, e.color)
                    enemies.remove_at(hit_index)
            else:
                enemies[hit_index] = e
            bullets.remove_at(i)
        elif b.life <= 0 or b.pos.x < -30 or b.pos.x > W + 30 or b.pos.y < -30 or b.pos.y > H + 30:
            bullets.remove_at(i)
        else:
            bullets[i] = b

func _boss_killed() -> void:
    boss_defeated = true
    coins += 100 + planet_index * 40
    unlocked_planet = maxi(unlocked_planet, mini(4, planet_index + 1))
    _save_game()
    if planet_index == 4:
        state = "victory"
    else:
        _end_run(true)

func _end_run(won: bool) -> void:
    state = "gameover"
    coins += int(run_kills / 3)
    _save_game()
    if won:
        message = "ПЛАНЕТА ОЧИЩЕНА"
    else:
        message = "СИГНАЛ ПОТЕРЯН"
    message_timer = 3.0

func _update_gems(delta: float) -> void:
    for i in range(gems.size() - 1, -1, -1):
        var g: Dictionary = gems[i]
        g.phase += delta * 3
        var d: float = player.distance_to(g.pos)
        if d < magnet_radius:
            g.pos = g.pos.move_toward(player, (250.0 + (magnet_radius - d) * 2.2) * delta)
        if g.pos.distance_to(player) < 34:
            xp += 1
            gems.remove_at(i)
            var need := XP_BASE + (level - 1) * 3
            if xp >= need:
                xp -= need
                level += 1
                _open_upgrades()
                return
        else:
            gems[i] = g

func _open_upgrades() -> void:
    upgrade_options.clear()
    var pool := UPGRADES.duplicate(true)
    pool.shuffle()
    for i in range(3):
        upgrade_options.append(pool[i])
    state = "upgrade"

func _apply_upgrade(id: String) -> void:
    match id:
        "damage": damage *= 1.30
        "rate": fire_delay *= 0.80
        "multi": projectile_count += 1
        "armor": armor += 3.0
        "magnet": magnet_radius *= 1.5
        "heal": hp = minf(max_hp, hp + 35.0)

func _burst(pos: Vector2, col: Color) -> void:
    for i in range(8):
        var a := randf() * TAU
        particles.append({"pos":pos, "vel":Vector2.RIGHT.rotated(a) * randf_range(50, 170), "life":0.35, "color":col})

func _update_particles(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        particles[i].life -= delta
        particles[i].pos += particles[i].vel * delta
        if particles[i].life <= 0:
            particles.remove_at(i)

func _buy_skin(index: int) -> void:
    if owned_skins[index]:
        selected_skin = index
        player_color = skins[index].color
        message = "Облик выбран"
    elif coins >= int(skins[index].price):
        coins -= int(skins[index].price)
        owned_skins[index] = true
        selected_skin = index
        player_color = skins[index].color
        message = "Новый облик открыт!"
    else:
        message = "Недостаточно монет"
    message_timer = 2.0
    _save_game()

func _load_game() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://save.cfg") == OK:
        coins = int(cfg.get_value("profile", "coins", 0))
        unlocked_planet = int(cfg.get_value("profile", "unlocked_planet", 0))
        selected_skin = int(cfg.get_value("profile", "selected_skin", 0))
        lifetime_kills = int(cfg.get_value("profile", "kills", 0))
        owned_skins = cfg.get_value("profile", "owned_skins", [true, false, false, false])
        if owned_skins.size() != skins.size():
            owned_skins = [true, false, false, false]
        selected_skin = clampi(selected_skin, 0, skins.size() - 1)
        if not owned_skins[selected_skin]:
            selected_skin = 0

func _save_game() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("profile", "coins", coins)
    cfg.set_value("profile", "unlocked_planet", unlocked_planet)
    cfg.set_value("profile", "selected_skin", selected_skin)
    cfg.set_value("profile", "kills", lifetime_kills)
    cfg.set_value("profile", "owned_skins", owned_skins)
    cfg.save("user://save.cfg")

func _draw() -> void:
    draw_rect(Rect2(0, 0, W, H), Color("080d24"))
    _draw_background()
    if state == "play" or state == "upgrade":
        _draw_world()
        _draw_hud()
        if state == "upgrade":
            _draw_upgrade()
    elif state == "menu":
        _draw_menu()
    elif state == "story":
        _draw_story()
    elif state == "planets":
        _draw_planets()
    elif state == "shop":
        _draw_shop()
    elif state == "gameover":
        _draw_gameover()
    elif state == "victory":
        _draw_victory()
    if message_timer > 0:
        draw_string(ThemeDB.fallback_font, Vector2(35, 245), message, HORIZONTAL_ALIGNMENT_CENTER, 650, 23, Color("ffe58c"))

func _draw_background() -> void:
    for x in range(0, 721, 60):
        draw_line(Vector2(x, 0), Vector2(x, H), Color(0.15, 0.27, 0.48, 0.16), 1)
    for y in range(0, 1281, 60):
        draw_line(Vector2(0, y), Vector2(W, y), Color(0.15, 0.27, 0.48, 0.16), 1)
    for i in range(28):
        var sx := float((i * 137 + 41) % 720)
        var sy := float((i * 211 + 19) % 1280)
        draw_circle(Vector2(sx, sy), 1.5, Color(0.55, 0.75, 1, 0.35))

func _draw_world() -> void:
    for g in gems:
        draw_circle(g.pos, 9, Color(0.1, 0.95, 0.78, 0.18))
        draw_circle(g.pos, 5 + sin(float(g.phase)) * 1.2, Color("65ffe0"))
    for b in bullets:
        draw_circle(b.pos, 9, Color(0.2, 0.9, 1, 0.18))
        draw_circle(b.pos, 5, Color("a5fbff"))
    for e in enemies:
        var col: Color = e.color if float(e.flash) <= 0 else Color.WHITE
        var radius: float = e.radius
        draw_circle(e.pos, radius + 9, Color(col.r, col.g, col.b, 0.16))
        draw_circle(e.pos, radius, col)
        if bool(e.boss):
            draw_arc(e.pos, radius + 13, 0, TAU, 48, Color("ffb3ca"), 4)
            draw_rect(Rect2(e.pos.x - 65, e.pos.y - radius - 25, 130 * float(e.hp) / float(e.max_hp), 7), Color("ff527c"))
        else:
            draw_circle(e.pos + Vector2(-5, -4), 3, Color("fff1d6"))
            draw_circle(e.pos + Vector2(6, -4), 3, Color("fff1d6"))
    for p in particles:
        draw_circle(p.pos, 3, p.color)
    draw_circle(player, 44, Color(player_color.r, player_color.g, player_color.b, 0.12))
    draw_circle(player, 30, player_color)
    draw_circle(player, 20, Color("e8fbff"))
    draw_circle(player + Vector2(0, -3), 9, Color("2279d8"))
    if joystick_active:
        draw_circle(joystick_origin, 58, Color(0.55, 0.8, 1, 0.12))
        draw_circle(joystick_origin, 58, Color(0.55, 0.8, 1, 0.45), false, 3)
        draw_circle(joystick_origin + move_vector * 42, 24, Color(0.55, 0.9, 1, 0.55))

func _draw_hud() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(25, 48), str(PLANETS[planet_index].name), HORIZONTAL_ALIGNMENT_LEFT, 500, 24, Color("9cf7ff"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 82), "УР. %d   УБИЙСТВА %d   МОНЕТЫ %d" % [level, run_kills, coins], HORIZONTAL_ALIGNMENT_LEFT, 650, 16, Color("d8e7ff"))
    draw_rect(Rect2(25, 101, 280, 15), Color(0.12, 0.17, 0.29))
    draw_rect(Rect2(25, 101, 280 * hp / max_hp, 15), Color("ff557c"))
    draw_string(ThemeDB.fallback_font, Vector2(320, 114), "%d%%" % int(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
    var need := XP_BASE + (level - 1) * 3
    draw_rect(Rect2(25, 127, 280, 8), Color(0.12, 0.17, 0.29))
    draw_rect(Rect2(25, 127, 280.0 * float(xp) / need, 8), Color("62f5ce"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 163), "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("c6d7ff"))
    if boss_spawned and not boss_defeated:
        draw_string(ThemeDB.fallback_font, Vector2(360, 205), "БОСС: " + str(PLANETS[planet_index].boss), HORIZONTAL_ALIGNMENT_CENTER, 650, 19, Color("ff8ba5"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 1220), "ВЕДИ ПАЛЕЦ ПО ЛЕВОЙ ЧАСТИ ЭКРАНА", HORIZONTAL_ALIGNMENT_LEFT, 650, 14, Color(0.72, 0.82, 1, 0.65))

func _draw_menu() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(50, 330), "NEON", HORIZONTAL_ALIGNMENT_CENTER, 620, 86, Color("65eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 410), "SURVIVORS", HORIZONTAL_ALIGNMENT_CENTER, 620, 58, Color("f3fbff"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 475), "ЭХО РАССВЕТА", HORIZONTAL_ALIGNMENT_CENTER, 620, 25, Color("ff82a0"))
    draw_string(ThemeDB.fallback_font, Vector2(60, 585), "Пилот «Искры» • Последняя экспедиция", HORIZONTAL_ALIGNMENT_CENTER, 600, 18, Color("c6d7ff"))
    _button(Rect2(90, 720, 540, 105), "НАЧАТЬ ИГРУ")
    _button(Rect2(90, 850, 540, 90), "МАГАЗИН ОБЛИКОВ")
    _button(Rect2(90, 965, 540, 80), "ВЫБОР ПЛАНЕТ")
    draw_string(ThemeDB.fallback_font, Vector2(50, 1140), "Монеты: %d     Открыто планет: %d/5" % [coins, unlocked_planet + 1], HORIZONTAL_ALIGNMENT_CENTER, 620, 18, Color("8ef7e8"))

func _draw_story() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(50, 260), "ЖУРНАЛ КОРАБЛЯ «ИСКРА»", HORIZONTAL_ALIGNMENT_CENTER, 620, 22, Color("65eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 390), story_title, HORIZONTAL_ALIGNMENT_CENTER, 610, 32, Color("ff9db2"))
    _draw_wrapped(story_text, Vector2(75, 500), 570, 29, Color("e3edff"))
    _button(Rect2(90, 1080, 540, 90), "ПРОДОЛЖИТЬ")

func _draw_planets() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(50, 105), "КАРТА СЕКТОРА", HORIZONTAL_ALIGNMENT_CENTER, 620, 34, Color("65eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(40, 155), "Выбери доступную планету", HORIZONTAL_ALIGNMENT_CENTER, 640, 18, Color("c6d7ff"))
    for i in range(5):
        var r := Rect2(65, 310 + i * 145, 590, 112)
        var unlocked := i <= unlocked_planet
        draw_rect(r, Color(0.08, 0.16, 0.30, 0.98) if unlocked else Color(0.04, 0.07, 0.13, 0.95))
        draw_rect(r, PLANETS[i].color if unlocked else Color("46516a"), false, 2)
        draw_string(ThemeDB.fallback_font, Vector2(88, r.position.y + 43), str(PLANETS[i].name), HORIZONTAL_ALIGNMENT_LEFT, 530, 23, Color.WHITE if unlocked else Color("778097"))
        draw_string(ThemeDB.fallback_font, Vector2(88, r.position.y + 77), str(PLANETS[i].subtitle) + ("  •  ДОСТУПНА" if unlocked else "  •  ЗАКРЫТА"), HORIZONTAL_ALIGNMENT_LEFT, 530, 16, Color("a9c4e8"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 190), "Нажми на открытую планету", HORIZONTAL_ALIGNMENT_CENTER, 620, 17, Color("8ef7e8"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 1200), "НАЗАД", HORIZONTAL_ALIGNMENT_CENTER, 620, 22, Color("ff9db2"))

func _draw_shop() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(50, 105), "АНГАР «ИСКРЫ»", HORIZONTAL_ALIGNMENT_CENTER, 620, 34, Color("65eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 160), "Монеты: %d" % coins, HORIZONTAL_ALIGNMENT_CENTER, 620, 20, Color("ffe58c"))
    for i in range(skins.size()):
        var r := Rect2(70, 280 + i * 175, 580, 130)
        draw_rect(r, Color(0.08, 0.16, 0.30, 0.98))
        draw_rect(r, skins[i].color, false, 3)
        draw_circle(Vector2(120, r.position.y + 65), 25, skins[i].color)
        draw_string(ThemeDB.fallback_font, Vector2(170, r.position.y + 55), str(skins[i].name), HORIZONTAL_ALIGNMENT_LEFT, 400, 23, Color.WHITE)
        var label := "ВЫБРАНО" if selected_skin == i else ("КУПЛЕНО" if owned_skins[i] else "ЦЕНА: %d" % int(skins[i].price))
        draw_string(ThemeDB.fallback_font, Vector2(170, r.position.y + 91), label, HORIZONTAL_ALIGNMENT_LEFT, 400, 17, Color("8ef7e8"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 1210), "НАЗАД", HORIZONTAL_ALIGNMENT_CENTER, 620, 22, Color("ff9db2"))

func _draw_upgrade() -> void:
    draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.07, 0.84))
    draw_string(ThemeDB.fallback_font, Vector2(50, 365), "СИСТЕМА ОБНОВЛЕНА", HORIZONTAL_ALIGNMENT_CENTER, 620, 34, Color("83ffe5"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 415), "Выбери один модуль", HORIZONTAL_ALIGNMENT_CENTER, 620, 20, Color.WHITE)
    for i in range(upgrade_options.size()):
        var r := Rect2(55, 470 + i * 145, 610, 112)
        draw_rect(r, Color(0.08, 0.16, 0.30, 0.98))
        draw_rect(r, Color("4cebd7"), false, 3)
        draw_string(ThemeDB.fallback_font, Vector2(82, r.position.y + 48), str(upgrade_options[i].name), HORIZONTAL_ALIGNMENT_LEFT, 550, 23, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(82, r.position.y + 82), str(upgrade_options[i].info), HORIZONTAL_ALIGNMENT_LEFT, 550, 17, Color("9cf7ff"))

func _draw_gameover() -> void:
    draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.07, 0.86))
    draw_string(ThemeDB.fallback_font, Vector2(50, 430), "СИГНАЛ ПОТЕРЯН", HORIZONTAL_ALIGNMENT_CENTER, 620, 40, Color("ff7291"))
    draw_string(ThemeDB.fallback_font, Vector2(50, 510), "Уровень %d   •   Уничтожено %d" % [level, run_kills], HORIZONTAL_ALIGNMENT_CENTER, 620, 22, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(50, 560), "Получено монет: %d" % int(run_kills / 3), HORIZONTAL_ALIGNMENT_CENTER, 620, 19, Color("ffe58c"))
    _button(Rect2(75, 790, 570, 100), "ЕЩЁ ОДИН ЗАБЕГ")
    _button(Rect2(75, 920, 570, 90), "В ГЛАВНОЕ МЕНЮ")

func _draw_victory() -> void:
    draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.07, 0.90))
    draw_string(ThemeDB.fallback_font, Vector2(50, 340), "ЭХО ЗАТИХЛО", HORIZONTAL_ALIGNMENT_CENTER, 620, 42, Color("83ffe5"))
    _draw_wrapped("Ты собрал пять фрагментов ядра и добрался до источника сигнала. Эхо-Прайм оказался архивом сознаний колонистов, пытавшимся сохранить людей любой ценой. Ты отключил систему и вернул колониям свободу. Впервые за много лет корабль «Искра» получил настоящий сигнал с Земли.", Vector2(75, 470), 570, 28, Color("e3edff"))
    _button(Rect2(75, 840, 570, 100), "В ГЛАВНОЕ МЕНЮ")

func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.08, 0.18, 0.32, 0.98))
    draw_rect(r, Color("4cebd7"), false, 3)
    draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 15, r.position.y + r.size.y * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 30, 24, Color.WHITE)

func _draw_wrapped(text: String, origin: Vector2, max_width: float, line_height: float, col: Color) -> void:
    var words := text.split(" ")
    var line := ""
    var y := origin.y
    for word in words:
        var test := line + (" " if line != "" else "") + word
        if ThemeDB.fallback_font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x > max_width:
            draw_string(ThemeDB.fallback_font, Vector2(origin.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, max_width, 21, col)
            y += line_height
            line = word
        else:
            line = test
    if line != "":
        draw_string(ThemeDB.fallback_font, Vector2(origin.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, max_width, 21, col)
