extends Control

const SIZE := Vector2(1280, 800)
const INK := Color("101f2b")
const PANEL := Color("152735")
const GOLD := Color("b9a779")
const PAPER := Color("e0dfd2")
const MUTED := Color("82979e")
const ACCENT := Color("8dbbb9")
const IDS := ["boon", "dialogue", "voyage", "defeat", "tide", "bell", "lantern"]
const TITLES := ["旧部的馈赠", "雾中的对话", "循金线出航", "败北与回溯", "涨潮", "钟声", "提灯"]
const BOON_LINE := "海雾还未散，先带上这一缕冥火。"
const LINES := ["海雾还未散，先带上这一缕冥火。", "若归途已断，就让提灯指向前路。", "我在岸边，等下一次钟响。"]
const CARD_NAMES := ["余烬", "回声", "归潮"]
const CARD_LINES := [["攻击留下微光", "占位增益 · 不接入战斗"], ["格挡唤醒余响", "占位增益 · 不接入战斗"], ["亡魂随潮归来", "占位增益 · 不接入战斗"]]

class Foreground extends Control:
    var host: Control
    func _draw() -> void:
        host.paint_foreground(self)

var cfg: Dictionary
var title_fonts: Array[Font] = []
var body_font: Font
var font_set := 0
var effect: ColorRect
var fx: ShaderMaterial
var foreground: Foreground
var scene_index := 0
var t := 0.0
var previous_t := -1.0
var chosen := -1
var confirm_at := -1.0
var hover_index := -1
var hover_from := Vector3.ZERO
var hover_to := Vector3.ZERO
var hover_at := 0.0
var expression_at := -1.0
var expression_from := 0.0
var expression_to := 0.0
var muted := false
var paused := false
var show_hud := true
var speed := 1.0
var capture := false
var capture_frame := 0
var capture_busy := false
var capture_queue: Array[int] = []
var capture_root := ""
var capture_manifests: Array = []
var event_log: Array = []
var emitted: Dictionary = {}
var sound_cache: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
var audio_cursor := 0
var self_test := false
var quit_after := -1.0
var single_scene := -1
var start_at := 0.0
var test_failures: Array[String] = []

func _ready() -> void:
    if not load_parameters():
        get_tree().quit(1)
        return
    title_fonts = [load_font_file("res://fonts/veil-antiqua.woff2"), load_font_file("res://fonts/veil-manuscript.woff2")]
    body_font = load_font_file("res://fonts/t56-sans.ttf")
    for f in title_fonts + [body_font]:
        if f == null or f.get_font_name().is_empty():
            push_error("T56: bundled font failed to load")
            get_tree().quit(1)
            return
    for arg in OS.get_cmdline_user_args():
        if arg == "--capture": capture = true
        elif arg == "--self-test": self_test = true
        elif arg == "--mute": muted = true
        elif arg == "--clean": show_hud = false
        elif arg.begins_with("--scene="): single_scene = IDS.find(arg.get_slice("=", 1))
        elif arg.begins_with("--font="): font_set = clampi(int(arg.get_slice("=", 1)) - 1, 0, 1)
        elif arg.begins_with("--out="): capture_root = arg.trim_prefix("--out=")
        elif arg.begins_with("--at="): start_at = float(arg.get_slice("=", 1))
        elif arg.begins_with("--quit-after="): quit_after = float(arg.get_slice("=", 1))
    if capture and DisplayServer.get_name() == "headless":
        push_error("T56: --capture needs a rendering display; headless cannot produce PNGs")
        get_tree().quit(2)
        return
    if capture_root.is_empty():
        capture_root = ProjectSettings.globalize_path("res://").path_join("../../shots/t56").simplify_path()
    fx = ShaderMaterial.new()
    fx.shader = load("res://transition.gdshader")
    for key in ["wave_cycles", "wave_secondary_cycles", "wave_amplitude", "wave_secondary_amplitude", "wave_phase", "wave_secondary_phase", "grain_strength"]:
        fx.set_shader_parameter(key, cfg.transition[key])
    effect = ColorRect.new()
    effect.size = SIZE
    effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    effect.material = fx
    add_child(effect)
    foreground = Foreground.new()
    foreground.host = self
    foreground.size = SIZE
    foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(foreground)
    for i in range(8):
        var player := AudioStreamPlayer.new()
        add_child(player)
        audio_players.append(player)
    if capture:
        if single_scene >= 0: capture_queue.append(single_scene)
        else: capture_queue.assign(range(IDS.size()))
        DirAccess.make_dir_recursive_absolute(capture_root)
        FileAccess.open(capture_root.path_join(".gdignore"), FileAccess.WRITE).close()
        select_scene(capture_queue.pop_front())
    else:
        select_scene(maxi(0, single_scene))
        t = start_at
    if self_test:
        run_self_test.call_deferred()

func load_font_file(path: String) -> FontFile:
    # Raw font bytes also work on the first CLI launch, before editor imports.
    var font := FontFile.new()
    font.data = FileAccess.get_file_as_bytes(path)
    return font

func load_parameters() -> bool:
    var parser := JSON.new()
    var err := parser.parse(FileAccess.get_file_as_string("res://motion.json"))
    if err != OK or not parser.data is Dictionary:
        push_error("T56: motion.json parse failed: " + parser.get_error_message())
        return false
    cfg = parser.data
    # Validate the whole schema, including easing names, before any playback.
    var groups := {"common": ["enter_ms", "exit_ms", "stagger_ms", "hover_ms", "hover_scale", "hover_brighten", "unfocused_brightness", "confirm_press_ms", "confirm_release_ms", "confirm_scale", "skip_threshold_ms", "breath_ms", "breath_amplitude"], "boon": ["background_brightness", "portrait_start_ms", "text_start_ms", "character_ms", "cards_after_text_ms", "flight_ms", "edge_flash_ms", "capture_hover_hold_ms", "capture_hover_gap_ms", "capture_confirm_delay_ms", "capture_tail_ms"], "dialogue": ["speaker_ms", "listener_brightness", "listener_retreat_px", "expression_ms", "character_ms", "capture_read_ms", "capture_expression_read_ms", "capture_tail_ms"], "voyage": ["route_ms"], "transition": ["preview_hold_ms", "wave_cycles", "wave_secondary_cycles", "wave_amplitude", "wave_secondary_amplitude", "wave_phase", "wave_secondary_phase", "grain_strength"], "defeat": ["slow_ms", "simulation_scale", "unit_cycle_ms", "black_ms", "lantern_line_ms", "capture_tail_ms"], "capture": ["fps", "tail_ms"], "sound": ["sample_rate", "gain", "attack_ms", "cues"]}
    for group in groups:
        if not cfg.get(group) is Dictionary:
            push_error("T56: missing motion group " + group)
            return false
        for key in groups[group]:
            if not cfg[group].has(key) or (key != "cues" and (not (cfg[group][key] is float or cfg[group][key] is int) or cfg[group][key] < 0)):
                push_error("T56: invalid/missing parameter " + group + "." + key)
                return false
            if key.ends_with("_ms") and cfg[group][key] == 0 and key != "portrait_start_ms":
                push_error("T56: duration must be positive: " + key)
                return false
    for kind in ["tide", "bell", "lantern"]:
        var keys := ["cover_ms", "hold_ms", "reveal_ms"] if kind != "lantern" else ["ignite_ms", "hold_ms", "reveal_ms"]
        for key in keys:
            if cfg.transition.get(kind, {}).get(key, 0) <= 0:
                push_error("T56: invalid transition timing " + kind + "." + key)
                return false
    for name in ["enter", "exit", "hover", "confirm", "flight", "brightness", "expression", "typewriter", "route", "transition", "lantern"]:
        var curve: Dictionary = cfg.get("curves", {}).get(name, {})
        if not curve.get("type", "") in ["linear", "smoothstep", "cubic_in", "cubic_out", "cubic_in_out", "back_out"]:
            push_error("T56: unknown easing " + name)
            return false
        if curve.type == "back_out" and not curve.has("overshoot"):
            push_error("T56: back_out requires overshoot")
            return false
    if cfg.capture.fps != 30 or cfg.sound.sample_rate < 8000 or cfg.common.hover_scale < 1:
        push_error("T56: capture fps must be 30; sample rate >= 8000; hover scale >= 1")
        return false
    for cue_name in ["portrait", "card", "hover", "confirm", "slot", "voice", "route", "tide", "bell", "lantern"]:
        var cue: Dictionary = cfg.sound.cues.get(cue_name, {})
        for key in ["hz", "duration_ms", "decay", "harmonic"]:
            if not cue.has(key) or cue[key] <= 0:
                push_error("T56: invalid sound " + cue_name + "." + key)
                return false
    return true

func seconds(group: String, key: String) -> float:
    return float(cfg[group][key]) / 1000.0

func trans_seconds(kind: String, key: String) -> float:
    return float(cfg.transition[kind][key]) / 1000.0

func progress(at: float, duration: float, time: float = -1.0) -> float:
    return clampf(((t if time < 0 else time) - at) / maxf(duration, 0.000001), 0.0, 1.0)

func easing(value: float, curve_name: String) -> float:
    var x := clampf(value, 0, 1)
    var curve: Dictionary = cfg.curves[curve_name]
    match curve.type:
        "linear": return x
        "cubic_in": return x * x * x
        "cubic_out": return 1.0 - pow(1.0 - x, 3)
        "cubic_in_out": return 4 * x * x * x if x < 0.5 else 1 - pow(-2 * x + 2, 3) / 2
        "back_out":
            # Solve the back coefficient from the requested peak overshoot.
            var lo := 0.0
            var hi := 8.0
            for i in range(24):
                var c := (lo + hi) / 2
                if 4 * pow(c, 3) / (27 * pow(c + 1, 2)) < float(curve.overshoot): lo = c
                else: hi = c
            var b := (lo + hi) / 2
            return 1 + (b + 1) * pow(x - 1, 3) + b * pow(x - 1, 2)
        _: return x * x * (3 - 2 * x)

func card_start() -> float:
    return seconds("boon", "text_start_ms") + BOON_LINE.length() * seconds("boon", "character_ms") + seconds("boon", "cards_after_text_ms")

func cards_ready() -> float:
    return card_start() + 2 * seconds("common", "stagger_ms") + seconds("common", "enter_ms")

func confirmation_duration() -> float:
    return flight_arrival() + seconds("boon", "edge_flash_ms")

func flight_arrival() -> float:
    return seconds("common", "confirm_press_ms") + seconds("common", "confirm_release_ms") + seconds("boon", "flight_ms")

func auto_confirm_at() -> float:
    return cards_ready() + 3 * (seconds("boon", "capture_hover_hold_ms") + seconds("boon", "capture_hover_gap_ms")) + seconds("boon", "capture_confirm_delay_ms")

func dialogue_starts() -> Array[float]:
    var starts: Array[float] = [seconds("common", "enter_ms")]
    for i in range(LINES.size() - 1):
        starts.append(starts[-1] + LINES[i].length() * seconds("dialogue", "character_ms") + seconds("dialogue", "capture_read_ms") + seconds("dialogue", "expression_ms") + seconds("dialogue", "capture_expression_read_ms"))
    return starts

func duration_for(index: int) -> float:
    match index:
        0: return auto_confirm_at() + confirmation_duration() + seconds("boon", "capture_tail_ms")
        1: return dialogue_starts()[-1] + LINES[-1].length() * seconds("dialogue", "character_ms") + seconds("dialogue", "expression_ms") + seconds("dialogue", "capture_tail_ms")
        2: return seconds("voyage", "route_ms") + transition_duration("tide") + seconds("capture", "tail_ms")
        3: return seconds("defeat", "slow_ms") + trans_seconds("bell", "cover_ms") + seconds("defeat", "black_ms") + trans_seconds("lantern", "ignite_ms") + seconds("defeat", "lantern_line_ms") + trans_seconds("lantern", "reveal_ms") + seconds("defeat", "capture_tail_ms")
        _: return seconds("transition", "preview_hold_ms") + transition_duration(IDS[index]) + seconds("capture", "tail_ms")

func transition_duration(kind: String) -> float:
    return trans_seconds(kind, "ignite_ms" if kind == "lantern" else "cover_ms") + trans_seconds(kind, "hold_ms") + trans_seconds(kind, "reveal_ms")

func playback_end() -> float:
    if scene_index == 0:
        return cards_ready() if chosen < 0 else confirm_at + confirmation_duration()
    return duration_for(scene_index) - seconds("capture", "tail_ms") if scene_index != 1 and scene_index != 3 else duration_for(scene_index) - seconds(IDS[scene_index], "capture_tail_ms")

func select_scene(index: int) -> void:
    for player in audio_players: player.stop()
    scene_index = index
    t = 0
    previous_t = -1
    chosen = -1
    confirm_at = -1
    hover_index = -1
    hover_from = Vector3.ZERO
    hover_to = Vector3.ZERO
    hover_at = 0
    expression_at = -1
    expression_from = 0
    expression_to = 0
    emitted.clear()
    event_log.clear()
    capture_frame = 0
    if capture:
        var folder := capture_root.path_join(IDS[index])
        DirAccess.make_dir_recursive_absolute(folder)
        # Remove only this take's numbered frames; never touch other files.
        for file in DirAccess.get_files_at(folder):
            if file.begins_with("frame_") and file.ends_with(".png") and file.trim_prefix("frame_").trim_suffix(".png").is_valid_int():
                DirAccess.remove_absolute(folder.path_join(file))
    print("T56_SCENE ", IDS[index], " duration=", snappedf(duration_for(index), 0.001))

func _process(delta: float) -> void:
    if cfg.is_empty() or fx == null or self_test or capture_busy: return
    if capture:
        t = float(capture_frame) / float(cfg.capture.fps)
        automate_capture()
    elif not paused:
        t += delta * speed
    dispatch_events()
    update_effect()
    queue_redraw()
    foreground.queue_redraw()
    previous_t = t
    if capture:
        capture_busy = true
        save_frame.call_deferred()
    elif quit_after >= 0 and t >= start_at + quit_after:
        get_tree().quit()

func automate_capture() -> void:
    if scene_index != 0: return
    var cycle := seconds("boon", "capture_hover_hold_ms") + seconds("boon", "capture_hover_gap_ms")
    var elapsed := t - cards_ready()
    var index := int(floor(elapsed / cycle))
    var focus := index if index >= 0 and index < 3 and fmod(maxf(0, elapsed), cycle) < seconds("boon", "capture_hover_hold_ms") else -1
    set_hover(focus)
    if t >= auto_confirm_at() and chosen < 0:
        chosen = 1
        confirm_at = auto_confirm_at()

func save_frame() -> void:
    await RenderingServer.frame_post_draw
    var picture := get_viewport().get_texture().get_image()
    var folder := capture_root.path_join(IDS[scene_index])
    var path := folder.path_join("frame_%05d.png" % capture_frame)
    if picture == null or picture.is_empty() or picture.save_png(path) != OK:
        push_error("T56_CAPTURE failed: " + path)
        get_tree().quit(3)
        return
    capture_frame += 1
    if capture_frame > ceili(duration_for(scene_index) * float(cfg.capture.fps)):
        var manifest := {"scene": IDS[scene_index], "fps": cfg.capture.fps, "frames": capture_frame, "first_sample_s": 0, "last_sample_s": float(capture_frame - 1) / float(cfg.capture.fps), "timeline_duration_s": duration_for(scene_index), "font_set": font_set + 1, "parameters": cfg, "events": event_log}
        FileAccess.open(folder.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "  "))
        capture_manifests.append(manifest)
        print("T56_CAPTURE ", IDS[scene_index], " frames=", capture_frame, " fps=30 out=", folder)
        if capture_queue.is_empty():
            FileAccess.open(capture_root.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(capture_manifests, "  "))
            print("T56_CAPTURE_DONE scenes=", capture_manifests.size())
            get_tree().quit()
        else: select_scene(capture_queue.pop_front())
    capture_busy = false

func cue(name: String, at: float, token: String) -> void:
    if emitted.has(token) or t < at: return
    emitted[token] = true
    var record := {"cue": name, "at_s": snappedf(at, 0.0001), "observed_s": snappedf(t, 0.0001), "skipped": t - at > 1.0 / float(cfg.capture.fps)}
    event_log.append(record)
    print("T56_SFX ", IDS[scene_index], " ", JSON.stringify(record))
    if muted or self_test or record.skipped: return
    if not sound_cache.has(name): sound_cache[name] = synthesize(name)
    var player := audio_players[audio_cursor % audio_players.size()]
    audio_cursor += 1
    player.stream = sound_cache[name]
    player.play()

func synthesize(name: String) -> AudioStreamWAV:
    var p: Dictionary = cfg.sound.cues[name]
    var rate := int(cfg.sound.sample_rate)
    var duration := float(p.duration_ms) / 1000.0
    var count := int(duration * rate)
    var bytes := PackedByteArray()
    bytes.resize(count * 2)
    for i in range(count):
        var sample_t := float(i) / rate
        var envelope := minf(1, sample_t / seconds("sound", "attack_ms")) * exp(-float(p.decay) * sample_t / duration) * (1 - sample_t / duration)
        var wave := sin(TAU * float(p.hz) * sample_t) + float(p.harmonic) * sin(TAU * float(p.hz) * 2.76 * sample_t)
        bytes.encode_s16(i * 2, int(clampf(wave * envelope * float(cfg.sound.gain), -1, 1) * 32767))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.data = bytes
    return stream

func dispatch_events() -> void:
    match scene_index:
        0:
            cue("portrait", seconds("boon", "portrait_start_ms"), "portrait")
            for i in range(3): cue("card", card_start() + i * seconds("common", "stagger_ms"), "card%d" % i)
            if chosen >= 0:
                cue("confirm", confirm_at, "confirm")
                cue("slot", confirm_at + flight_arrival(), "slot")
        1:
            cue("portrait", 0, "portrait")
            for i in range(3): cue("voice", dialogue_starts()[i], "line%d" % i)
        2:
            cue("route", 0, "route")
            cue("tide", seconds("voyage", "route_ms"), "tide")
        3:
            cue("bell", seconds("defeat", "slow_ms"), "bell")
            cue("lantern", defeat_lantern_at(), "lantern")
        _:
            cue(IDS[scene_index], seconds("transition", "preview_hold_ms"), IDS[scene_index])

func defeat_lantern_at() -> float:
    return seconds("defeat", "slow_ms") + trans_seconds("bell", "cover_ms") + seconds("defeat", "black_ms")

func defeat_reveal_at() -> float:
    return defeat_lantern_at() + trans_seconds("lantern", "ignite_ms") + seconds("defeat", "lantern_line_ms")

func transition_state(kind: String, local_t: float) -> Dictionary:
    var cover := trans_seconds(kind, "ignite_ms" if kind == "lantern" else "cover_ms")
    var hold := trans_seconds(kind, "hold_ms")
    var reveal := trans_seconds(kind, "reveal_ms")
    var p := 0.0
    var destination := local_t >= cover
    if kind == "lantern":
        p = easing(progress(cover + hold, reveal, maxf(0, local_t)), "lantern")
    elif local_t < cover: p = easing(progress(0, cover, maxf(0, local_t)), "transition")
    elif local_t < cover + hold: p = 1
    else: p = 1 - easing(progress(cover + hold, reveal, local_t), "transition")
    return {"p": p, "destination": destination, "finished": local_t >= cover + hold + reveal}

func update_effect() -> void:
    fx.set_shader_parameter("mode", 0)
    fx.set_shader_parameter("desaturate", 0.0)
    fx.set_shader_parameter("vignette", 0.0)
    fx.set_shader_parameter("phase", t)
    effect.visible = true
    if scene_index == 2 and t >= seconds("voyage", "route_ms"):
        var state := transition_state("tide", t - seconds("voyage", "route_ms"))
        set_effect(1, state.p)
    elif scene_index >= 4:
        var kind: String = IDS[scene_index]
        var local_t := t - seconds("transition", "preview_hold_ms")
        if local_t >= 0: set_effect(scene_index - 3, transition_state(kind, local_t).p)
    elif scene_index == 3:
        var slow := seconds("defeat", "slow_ms")
        var fade := easing(progress(0, slow), "brightness")
        fx.set_shader_parameter("desaturate", fade)
        fx.set_shader_parameter("vignette", fade * 0.9)
        if t < slow: set_effect(4, fade)
        elif t < defeat_lantern_at(): set_effect(2, easing(progress(slow, trans_seconds("bell", "cover_ms")), "transition"))
        else:
            fx.set_shader_parameter("desaturate", 0.0)
            fx.set_shader_parameter("vignette", 0.0)
            set_effect(3, easing(progress(defeat_reveal_at(), trans_seconds("lantern", "reveal_ms")), "lantern"))

func set_effect(mode: int, p: float) -> void:
    fx.set_shader_parameter("mode", mode)
    fx.set_shader_parameter("progress", p)

func set_hover(index: int) -> void:
    if index == hover_index: return
    hover_from = hover_weights()
    hover_to = Vector3.ZERO
    if index >= 0: hover_to[index] = 1
    hover_at = t
    hover_index = index
    if index >= 0: cue("hover", t, "hover_%d_%f" % [index, t])

func hover_weights() -> Vector3:
    return hover_from.lerp(hover_to, easing(progress(hover_at, seconds("common", "hover_ms")), "hover"))

func card_rect(index: int) -> Rect2:
    return Rect2(486 + index * 242, 294, 216, 310)

func _input(event: InputEvent) -> void:
    if capture or self_test: return
    if event is InputEventKey and event.pressed and not event.echo:
        var key: int = event.keycode
        if key >= KEY_1 and key <= KEY_7: select_scene(key - KEY_1)
        elif key == KEY_R: select_scene(scene_index)
        elif key == KEY_F: font_set = 1 - font_set
        elif key == KEY_H: show_hud = not show_hud
        elif key == KEY_M:
            muted = not muted
            if muted:
                for player in audio_players: player.stop()
        elif key == KEY_P: paused = not paused
        elif key == KEY_BRACKETLEFT: speed = maxf(0.25, speed / 2)
        elif key == KEY_BRACKETRIGHT: speed = minf(2.0, speed * 2)
        elif key == KEY_F5:
            var before := cfg
            if load_parameters():
                for player in audio_players: player.stop()
                sound_cache.clear()
                select_scene(scene_index)
                for parameter in ["wave_cycles", "wave_secondary_cycles", "wave_amplitude", "wave_secondary_amplitude", "wave_phase", "wave_secondary_phase", "grain_strength"]:
                    fx.set_shader_parameter(parameter, cfg.transition[parameter])
            else: cfg = before
        elif key == KEY_TAB: select_scene(4 if scene_index < 4 else 4 + (scene_index - 3) % 3)
        elif key == KEY_E and scene_index == 1:
            expression_from = expression_value()
            expression_to = 1.0 if expression_from < 0.5 else 0.0
            expression_at = t
        elif key == KEY_N and scene_index == 1:
            for at in dialogue_starts():
                if at > t:
                    t = at
                    break
        elif key == KEY_LEFT and scene_index == 0 and t >= cards_ready(): set_hover((hover_index + 2) % 3)
        elif key == KEY_RIGHT and scene_index == 0 and t >= cards_ready(): set_hover((hover_index + 1) % 3)
        elif key == KEY_ENTER and scene_index == 0 and t >= cards_ready() and chosen < 0: choose(maxi(0, hover_index))
        elif key == KEY_SPACE or key == KEY_END: skip_to_end()
        elif key == KEY_ESCAPE: get_tree().quit()
    elif event is InputEventMouseMotion and scene_index == 0 and t >= cards_ready() and chosen < 0:
        var found := -1
        for i in range(3):
            if card_rect(i).has_point(event.position): found = i
        set_hover(found)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if t < playback_end(): skip_to_end()
        elif scene_index == 0 and chosen < 0:
            for i in range(3):
                if card_rect(i).has_point(event.position):
                    choose(i)
                    break

func choose(index: int) -> void:
    chosen = index
    confirm_at = t

func skip_to_end() -> void:
    if playback_end() * 1000 > float(cfg.common.skip_threshold_ms):
        var end := playback_end()
        if end > t:
            for player in audio_players: player.stop()
            t = end
            print("T56_SKIP ", IDS[scene_index], " end_s=", t, " chosen=", chosen)
            dispatch_events()
            update_effect()
            queue_redraw()
            foreground.queue_redraw()

func _draw() -> void:
    if cfg.is_empty() or body_font == null: return
    draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
    match scene_index:
        0: paint_boon()
        1: paint_dialogue()
        2:
            var state := transition_state("tide", t - seconds("voyage", "route_ms"))
            if t >= seconds("voyage", "route_ms") and state.destination: paint_destination("登陆部署", "墨潮退去，新的岸线显现。", false)
            else: paint_voyage()
        3:
            if t >= defeat_lantern_at(): paint_destination("沉钟湾", "潮声还在，归途尚未结束。", true)
            else: paint_battle()
        _:
            var state := transition_state(IDS[scene_index], t - seconds("transition", "preview_hold_ms"))
            if t >= seconds("transition", "preview_hold_ms") and state.destination:
                paint_destination("沉钟湾" if scene_index != 4 else "登陆部署", "一盏微光，接住下一段旅程。", scene_index != 4)
            else: paint_voyage()

func text_at(value: String, pos: Vector2, font: Font, size_px: int, color: Color = PAPER, width: float = -1) -> void:
    draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, size_px, color)

func title(value: String, subtitle: String) -> void:
    var position := Vector2(56, 150)
    for character in value:
        text_at(character, position, title_fonts[font_set], 46)
        position.x += title_fonts[font_set].get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x + 4
    text_at(subtitle, Vector2(58, 190), body_font, 18, MUTED)

func panel(rect: Rect2, accent: Color = GOLD) -> void:
    draw_rect(rect, PANEL)
    draw_line(rect.position + Vector2(0, 0.5), rect.position + Vector2(rect.size.x, 0.5), Color(accent, 0.6), 1)
    draw_line(rect.position + Vector2(0, rect.size.y - 0.5), rect.end - Vector2(0, 0.5), Color(accent, 0.35), 1)

func typed(line: String, start: float, character_time: float) -> String:
    var p := easing(progress(start, line.length() * character_time), "typewriter")
    return line.left(int(floor(p * line.length())))

func paint_boon() -> void:
    paint_sea(0.0)
    draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 1 - float(cfg.boon.background_brightness)))
    title("旧部的馈赠", "选择一份余火，带往下一片岸。")
    var enter := easing(progress(seconds("boon", "portrait_start_ms"), seconds("common", "enter_ms")), "enter")
    portrait(Vector2(245 + (enter - 1) * 460, 430), 1.15, 1.0, 0, false, ACCENT)
    panel(Rect2(56, 590, 382, 100), ACCENT)
    text_at("引路人 · 占位", Vector2(74, 620), title_fonts[font_set], 24, ACCENT)
    var line := typed(BOON_LINE, seconds("boon", "text_start_ms"), seconds("boon", "character_ms"))
    text_at(line.left(16), Vector2(74, 650), body_font, 18)
    text_at(line.substr(16), Vector2(74, 675), body_font, 18)
    var weights := hover_weights()
    var total_focus := clampf(weights.x + weights.y + weights.z, 0, 1)
    for i in range(3):
        var at := card_start() + i * seconds("common", "stagger_ms")
        if t < at: continue
        var p := easing(progress(at, seconds("common", "enter_ms")), "enter")
        var rect := card_rect(i)
        rect.position.y += (1 - p) * 300
        var scale_factor := lerpf(1, float(cfg.common.hover_scale), weights[i])
        var brightness := lerpf(1, float(cfg.common.unfocused_brightness), total_focus - weights[i]) + float(cfg.common.hover_brighten) * weights[i]
        var alpha := progress(at, seconds("common", "enter_ms"))
        if chosen >= 0:
            if chosen != i: alpha *= 1 - easing(progress(confirm_at, seconds("common", "exit_ms")), "exit")
            else:
                var press := seconds("common", "confirm_press_ms")
                var release := seconds("common", "confirm_release_ms")
                if t < confirm_at + press: scale_factor *= lerpf(1, float(cfg.common.confirm_scale), easing(progress(confirm_at, press), "confirm"))
                else: scale_factor *= lerpf(float(cfg.common.confirm_scale), 1, easing(progress(confirm_at + press, release), "enter"))
                alpha *= 1 - progress(confirm_at + press + release, seconds("boon", "flight_ms"))
        if alpha > 0:
            draw_set_transform(rect.get_center(), 0, Vector2.ONE * scale_factor)
            paint_card(i, Rect2(-rect.size / 2, rect.size), brightness, alpha, weights[i])
            draw_set_transform(Vector2.ZERO)
    var slot := Vector2(1117, 665)
    draw_rect(Rect2(slot - Vector2(22, 22), Vector2(44, 44)), PANEL)
    draw_rect(Rect2(slot - Vector2(22, 22), Vector2(44, 44)), Color(GOLD, 0.65), false, 1)
    text_at("馈赠槽位", Vector2(985, 673), body_font, 18, MUTED)
    if chosen >= 0:
        var flight_start := confirm_at + seconds("common", "confirm_press_ms") + seconds("common", "confirm_release_ms")
        var p := easing(progress(flight_start, seconds("boon", "flight_ms")), "flight")
        if t >= flight_start and p < 1:
            var start := card_rect(chosen).get_center()
            for j in range(14):
                var tail := clampf(p - float(j) / 70, 0, 1)
                var point := bezier(start, Vector2(1110, 235), slot, tail)
                draw_circle(point, lerpf(7, 1, float(j) / 14), Color(ACCENT, (1 - float(j) / 14) * 0.75))
        if p >= 1:
            draw_circle(slot, 7, ACCENT)
            text_at("馈赠已生效", Vector2(790, 673), title_fonts[font_set], 24, PAPER)
        var flash_at := flight_start + seconds("boon", "flight_ms")
        var flash := sin(progress(flash_at, seconds("boon", "edge_flash_ms")) * PI)
        draw_rect(Rect2(0, 0, 5, 800), Color(ACCENT, flash * 0.6))
        draw_rect(Rect2(1275, 0, 5, 800), Color(ACCENT, flash * 0.6))

func paint_card(index: int, rect: Rect2, brightness: float, alpha: float, focus: float) -> void:
    var breath := 1 + sin(t * TAU / seconds("common", "breath_ms")) * float(cfg.common.breath_amplitude)
    draw_rect(rect, Color(PANEL * brightness, alpha))
    draw_rect(rect, Color(GOLD * brightness * breath, alpha * (0.42 + focus * 0.4)), false, 1)
    var center := rect.position + Vector2(rect.size.x / 2, 94)
    draw_arc(center, 37, -PI * 0.7, PI * 0.7, 48, Color(ACCENT * brightness, alpha * 0.7), 1, true)
    var diamond := PackedVector2Array([center + Vector2(0, -23), center + Vector2(14, 0), center + Vector2(0, 23), center + Vector2(-14, 0)])
    draw_colored_polygon(diamond, Color(ACCENT * brightness, alpha * 0.2))
    draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(GOLD * brightness, alpha), 1, true)
    text_at(CARD_NAMES[index], rect.position + Vector2(24, 180), title_fonts[font_set], 24, Color(PAPER * brightness, alpha))
    text_at(CARD_LINES[index][0], rect.position + Vector2(24, 220), body_font, 18, Color(PAPER * brightness, alpha * 0.9))
    text_at("占位增益", rect.position + Vector2(24, 250), body_font, 18, Color(MUTED * brightness, alpha))
    draw_line(rect.position + Vector2(24, 276.5), rect.position + Vector2(rect.size.x - 24, 276.5), Color(GOLD, alpha * 0.3), 1)
    text_at("0%d" % (index + 1), rect.position + Vector2(24, 301), body_font, 18, Color(GOLD, alpha * 0.75))
    if chosen == index:
        var flash := sin(progress(confirm_at + seconds("common", "confirm_press_ms"), seconds("common", "confirm_release_ms")) * PI)
        draw_rect(rect, Color(ACCENT, flash * 0.35))

func bezier(a: Vector2, b: Vector2, c: Vector2, p: float) -> Vector2:
    return (1 - p) * (1 - p) * a + 2 * (1 - p) * p * b + p * p * c

func portrait(center: Vector2, scale_factor: float, brightness: float, expression: float, flipped: bool, accent: Color) -> void:
    draw_set_transform(center, 0, Vector2(-scale_factor if flipped else scale_factor, scale_factor))
    var coat := PackedVector2Array([Vector2(-96, 115), Vector2(-78, -5), Vector2(-39, -48), Vector2(38, -48), Vector2(82, -5), Vector2(106, 115)])
    draw_colored_polygon(coat, Color("233b49") * brightness)
    draw_colored_polygon(PackedVector2Array([Vector2(-39, -48), Vector2(0, 19), Vector2(38, -48)]), INK * brightness)
    draw_circle(Vector2(0, -105), 52, Color("384e57") * brightness)
    draw_colored_polygon(PackedVector2Array([Vector2(-52, -105), Vector2(-48, -143), Vector2(2, -166), Vector2(47, -138), Vector2(53, -102), Vector2(22, -130), Vector2(-34, -126)]), Color("1a303e") * brightness)
    draw_line(Vector2(-25, -101), Vector2(-11, -101), Color(PAPER * brightness, 0.55), 1)
    draw_line(Vector2(10, -101), Vector2(24, -101), Color(PAPER * brightness, 0.55), 1)
    # Two mouths/brows are drawn simultaneously; expression is an alpha crossfade.
    draw_line(Vector2(-9, -77), Vector2(11, -77), Color(PAPER * brightness, 0.45 * (1 - expression)), 1)
    draw_arc(Vector2(0, -83), 12, 0.2, PI - 0.2, 16, Color(PAPER * brightness, 0.65 * expression), 1, true)
    draw_line(Vector2(-27, -115), Vector2(-9, -120), Color(PAPER * brightness, expression * 0.5), 1)
    draw_line(Vector2(-40, -42), Vector2(-7, 20), Color(accent * brightness, 0.65), 1)
    draw_line(Vector2(-7, 20), Vector2(-24, 108), Color(accent * brightness, 0.65), 1)
    draw_circle(Vector2(-7, 20), 4, GOLD * brightness)
    draw_set_transform(Vector2.ZERO)

func dialogue_turn() -> int:
    var index := 0
    for i in range(LINES.size()):
        if t >= dialogue_starts()[i]: index = i
    return index

func expression_value() -> float:
    if expression_at >= 0:
        return lerpf(expression_from, expression_to, easing(progress(expression_at, seconds("dialogue", "expression_ms")), "expression"))
    var turn := dialogue_turn()
    var at: float = dialogue_starts()[turn] + LINES[turn].length() * seconds("dialogue", "character_ms")
    return easing(progress(at, seconds("dialogue", "expression_ms")), "expression")

func paint_dialogue() -> void:
    title("雾中的对话", "说话者的明度，承担唯一的焦点。")
    var enter := easing(progress(0, seconds("common", "enter_ms")), "enter")
    var turn := dialogue_turn()
    var at := dialogue_starts()[turn]
    var p := easing(progress(at, seconds("dialogue", "speaker_ms")), "brightness")
    var target := 1.0 if turn % 2 == 0 else 0.0
    var left_focus := target if turn == 0 else lerpf(1 - target, target, p)
    var listener := float(cfg.dialogue.listener_brightness)
    var retreat := float(cfg.dialogue.listener_retreat_px)
    portrait(Vector2(300 + (enter - 1) * 420 - (1 - left_focus) * retreat, 430), 1.35, lerpf(listener, 1, left_focus), expression_value() if target > 0 else 0, false, ACCENT)
    portrait(Vector2(980 - (enter - 1) * 420 + left_focus * retreat, 430), 1.35, lerpf(1, listener, left_focus), expression_value() if target < 1 else 0, true, GOLD)
    panel(Rect2(170, 591, 940, 116), ACCENT if target > 0 else GOLD)
    text_at("引路人 · 占位" if target > 0 else "渡魂人 · 占位", Vector2(198, 629), title_fonts[font_set], 24, ACCENT if target > 0 else GOLD)
    text_at(typed(LINES[turn], at, seconds("dialogue", "character_ms")), Vector2(198, 675), body_font, 24)

func route_points() -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(81): points.append(bezier(Vector2(260, 512), Vector2(620, 205), Vector2(1020, 430), float(i) / 80))
    return points

func paint_sea(sim_time: float) -> void:
    for row in range(8):
        var points := PackedVector2Array()
        for col in range(61):
            var x := float(col) * SIZE.x / 60
            points.append(Vector2(x, 280 + row * 57 + sin(x / 135 + row * 0.8 + sim_time) * 6))
        draw_polyline(points, Color("31434b") * Color(1, 1, 1, 0.25), 1, true)

func paint_voyage() -> void:
    paint_sea(0)
    title("循金线出航", "金线先行，船标随后抵达。")
    var points := route_points()
    draw_polyline(points, Color(GOLD, 0.2), 1, true)
    var p := easing(progress(0, seconds("voyage", "route_ms")), "route") if scene_index == 2 else 1.0
    var visible_count := maxi(2, int(p * (points.size() - 1)) + 1)
    draw_polyline(points.slice(0, visible_count), GOLD, 1, true)
    for point in [points[0], points[-1]]:
        draw_arc(point, 10, 0, TAU, 32, GOLD, 1, true)
    var ship := bezier(points[0], Vector2(620, 205), points[-1], p)
    draw_colored_polygon(PackedVector2Array([ship + Vector2(-14, 5), ship + Vector2(16, 5), ship + Vector2(7, 14), ship + Vector2(-6, 14)]), GOLD)
    draw_line(ship + Vector2(0, -18), ship + Vector2(0, 4), PAPER, 1)
    draw_colored_polygon(PackedVector2Array([ship + Vector2(2, -18), ship + Vector2(2, 1), ship + Vector2(13, 1)]), Color(PAPER, 0.6))
    panel(Rect2(56, 605, 362, 82))
    text_at("沉钟湾   →   未知岸线", Vector2(76, 641), title_fonts[font_set], 24)
    text_at("航路占位 · 不接入大地图", Vector2(76, 670), body_font, 18, MUTED)

func paint_battle() -> void:
    title("最后一道余火", "钟响之前，画面褪色，四周渐暗。")
    var sim_time := t * float(cfg.defeat.simulation_scale) / seconds("defeat", "unit_cycle_ms")
    draw_colored_polygon(PackedVector2Array([Vector2(130, 560), Vector2(380, 300), Vector2(850, 330), Vector2(1140, 550), Vector2(850, 670), Vector2(350, 650)]), Color("30454b"))
    for i in range(11):
        var pos := Vector2(350 + i * 52 + sin(sim_time * TAU + i) * 18, 470 + sin(i * 1.8) * 62)
        draw_circle(pos - Vector2(0, 16), 7, ACCENT if i < 5 else GOLD)
        draw_rect(Rect2(pos - Vector2(6, 8), Vector2(12, 22)), Color("60777a") if i < 5 else Color("81765e"))
    draw_line(Vector2(640, 355), Vector2(640, 478), GOLD, 1)
    draw_colored_polygon(PackedVector2Array([Vector2(640, 357), Vector2(705, 357), Vector2(690, 396), Vector2(640, 396)]), Color("866f4c"))

func paint_destination(heading: String, subtitle: String, hub: bool) -> void:
    paint_sea(0)
    title(heading, subtitle)
    var shape := PackedVector2Array([Vector2(210, 540), Vector2(390, 345), Vector2(520, 410), Vector2(700, 305), Vector2(890, 395), Vector2(1050, 535), Vector2(920, 615), Vector2(390, 620)])
    draw_colored_polygon(shape, Color("283f49"))
    if hub:
        draw_rect(Rect2(588, 340, 105, 192), PANEL)
        draw_colored_polygon(PackedVector2Array([Vector2(569, 340), Vector2(640, 280), Vector2(711, 340)]), Color("344d56"))
        draw_rect(Rect2(628, 420, 24, 52), Color("a48f59"))
        draw_line(Vector2(390, 566.5), Vector2(920, 566.5), Color(GOLD, 0.45), 1)
    else:
        for i in range(3):
            draw_rect(Rect2(460 + i * 130, 450, 88, 60), PANEL)
            draw_line(Vector2(460 + i * 130, 450.5), Vector2(548 + i * 130, 450.5), Color(GOLD, 0.5), 1)
    panel(Rect2(56, 615, 402, 72))
    text_at("画面已展开 · 演出终态", Vector2(76, 659), body_font, 24)

func paint_foreground(canvas: Control) -> void:
    if cfg.is_empty(): return
    var lamp := 0.0
    var quote := false
    if scene_index == 3 and t >= defeat_lantern_at():
        lamp = easing(progress(defeat_lantern_at(), trans_seconds("lantern", "ignite_ms")), "lantern") * (1 - progress(defeat_reveal_at(), trans_seconds("lantern", "reveal_ms")))
        quote = t < defeat_reveal_at()
    elif scene_index == 6:
        var at := seconds("transition", "preview_hold_ms")
        lamp = easing(progress(at, trans_seconds("lantern", "ignite_ms")), "lantern") * (1 - progress(at + trans_seconds("lantern", "ignite_ms") + trans_seconds("lantern", "hold_ms"), trans_seconds("lantern", "reveal_ms"))) if t >= at else 0.0
    if lamp > 0:
        var center := Vector2(640, 368)
        for i in range(28, 0, -1): canvas.draw_circle(center, i * 3, Color(GOLD, lamp * 0.003 * (1 - float(i) / 29)))
        canvas.draw_rect(Rect2(center - Vector2(15, 26), Vector2(30, 48)), Color(GOLD, lamp), false, 1)
        canvas.draw_arc(center - Vector2(0, 30), 8, PI, TAU, 20, Color(GOLD, lamp), 1, true)
        canvas.draw_circle(center, 5, Color(PAPER, lamp))
        if quote:
            canvas.draw_rect(Rect2(367, 500, 546, 72), Color(INK, lamp))
            canvas.draw_string(title_fonts[font_set], Vector2(402, 546), "提灯还亮着。我们回去。", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(PAPER, lamp))
    if not show_hud: return
    canvas.draw_rect(Rect2(0, 0, 1280, 73), INK)
    canvas.draw_string(body_font, Vector2(56, 44), "亡者归航  /  动效校准", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MUTED)
    canvas.draw_string(body_font, Vector2(750, 44), "%02d / 07   %s" % [scene_index + 1, TITLES[scene_index]], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
    canvas.draw_line(Vector2(56, 72.5), Vector2(1224, 72.5), Color(GOLD, 0.35), 1)
    canvas.draw_rect(Rect2(0, 724, 1280, 76), INK)
    canvas.draw_line(Vector2(56, 724.5), Vector2(1224, 724.5), Color(GOLD, 0.35), 1)
    var state := "可选择" if scene_index == 0 and chosen < 0 and t >= cards_ready() else ("已结束" if t >= playback_end() else "演出中 · 点击跳过")
    var label := "A 思源宋 + 思源黑" if font_set == 0 else "B 霞鹜文楷 + 思源黑"
    canvas.draw_string(body_font, Vector2(56, 751), "%s  ·  %.3f s  ·  %.2f×   |   %s" % [state, t, speed, label], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPER)
    canvas.draw_string(body_font, Vector2(56, 784), "1–4 演出   5–7 转场   R 重播   F 字体   E 表情   N 换人   P 暂停   [ ] 速度   M 静音   H 面板", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MUTED)

func check(condition: bool, label: String) -> void:
    if not condition: test_failures.append(label)

func run_self_test() -> void:
    muted = true
    for f in title_fonts + [body_font]:
        for character in "亡者归航馈赠冥火增益提灯沉钟湾败北回溯":
            check(f.has_char(character.unicode_at(0)), "glyph " + character + " in " + f.get_font_name())
    var peak := 1.0
    for i in range(1001): peak = maxf(peak, easing(float(i) / 1000, "enter"))
    check(absf(peak - 1 - float(cfg.curves.enter.overshoot)) < 0.001, "back overshoot")
    for i in range(IDS.size()):
        select_scene(i)
        t = playback_end() / 2
        skip_to_end()
        check(is_equal_approx(t, playback_end()), "skip " + IDS[i])
        update_effect()
        if i >= 2:
            var expected := 1.0 if i == 3 or i == 6 else 0.0
            check(absf(float(fx.get_shader_parameter("progress")) - expected) < 0.001, "transition terminal reveal " + IDS[i])
    select_scene(0)
    t = cards_ready()
    set_hover(2)
    t += seconds("common", "hover_ms")
    check(hover_weights().is_equal_approx(Vector3(0, 0, 1)), "hover end")
    choose(2)
    t += seconds("common", "confirm_press_ms")
    skip_to_end()
    check(chosen == 2 and is_equal_approx(t, confirm_at + confirmation_duration()), "confirm skip preserves choice")
    for kind in ["tide", "bell", "lantern"]:
        var cover := trans_seconds(kind, "ignite_ms" if kind == "lantern" else "cover_ms")
        var state := transition_state(kind, cover + trans_seconds(kind, "hold_ms") / 2)
        check(state.destination and is_equal_approx(state.p, 0.0 if kind == "lantern" else 1.0), "full cover " + kind)
    select_scene(1)
    t = playback_end()
    check(is_equal_approx(expression_value(), 1), "dialogue terminal expression")
    select_scene(0)
    for frame in range(ceili(duration_for(0) * float(cfg.capture.fps)) + 1):
        t = float(frame) / float(cfg.capture.fps)
        automate_capture()
        dispatch_events()
    check(chosen == 1, "capture confirms second card")
    for sound in ["card", "hover", "confirm", "slot"]:
        var expected := 3 if sound == "card" or sound == "hover" else 1
        var count := 0
        for event in event_log:
            if event.cue == sound:
                count += 1
                check(event.observed_s - event.at_s <= 1.0 / float(cfg.capture.fps) + 0.0002, "capture cue timing " + sound)
        check(count == expected, "capture cue count " + sound)
    for name in cfg.sound.cues:
        var stream := synthesize(name)
        check(stream.data.size() == int(float(cfg.sound.cues[name].duration_ms) / 1000 * cfg.sound.sample_rate) * 2, "audio " + name)
    print("T56_SELF_TEST ", JSON.stringify({"passed": test_failures.is_empty(), "failures": test_failures, "scenes": IDS.size(), "fonts": [title_fonts[0].get_font_name(), title_fonts[1].get_font_name(), body_font.get_font_name()], "peak_overshoot": peak - 1}))
    get_tree().quit(0 if test_failures.is_empty() else 1)
