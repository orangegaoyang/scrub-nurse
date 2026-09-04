extends Node
## Conductor autoload: 手术节奏的节拍时钟。
## 运行时合成一段 4/4 单小节循环(1-3 拍弱 hat,第 4 拍 kick 强音)循环播放;
## 所有节拍事件从音频时钟推算(get_playback_position + mix 时间 - 输出延迟),
## 绝不用 Timer/延时,保证拍点与听到的强音永不漂移。
## 难度 = BPM:Conductor.start(ProcedureData.tempo()),窗口恒为 WINDOW_BEATS 拍。

signal beat(global_beat: int)

const BEATS_PER_BAR := 4
const CALL_BEAT := 3  # 呼叫/强音拍(0 起):每小节第 4 拍,医生在此伸手喊器械
const WINDOW_BEATS := 4  # 应答窗口:呼叫后一小节,下一个强音即截止/重新呼叫
const SAMPLE_RATE := 32000
const VOLUME_DB := -9.0
const BGM_DUCK_DB := -16.0

var bpm: float = 96.0
var running := false

var _player: AudioStreamPlayer
var _last_fired := -1  # 已发出的最后一只拍(从 0 计,单曲内单调)
var _loop_seconds := 0.0
var _prev_raw := 0.0
var _wrap_offset := 0.0
var _fade: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	add_child(_player)
	GameState.phase_changed.connect(_on_phase_changed)


func start(p_bpm: float) -> void:
	bpm = clampf(p_bpm, 60.0, 200.0)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_player.stream = _make_loop()
	_player.volume_db = VOLUME_DB
	_player.play()
	_last_fired = -1
	_prev_raw = 0.0
	_wrap_offset = 0.0
	running = true
	Audio.duck_music(BGM_DUCK_DB, 1.0)


func stop() -> void:
	if not running:
		return
	running = false
	Audio.restore_music(1.5)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", -40.0, 0.8)
	_fade.tween_callback(_player.stop)


func sec_per_beat() -> float:
	return 60.0 / bpm


func global_beat() -> int:
	return _last_fired


func beats_until_call() -> int:
	## 距下一个强音拍还有几拍(1..4);正踩在强音拍上时返回 4。
	var n := (CALL_BEAT - maxi(_last_fired, 0) % BEATS_PER_BAR + BEATS_PER_BAR) \
			% BEATS_PER_BAR
	return n if n > 0 else BEATS_PER_BAR


func _process(_delta: float) -> void:
	if not running or not _player.playing:
		return
	var raw := _player.get_playback_position()
	if raw < _prev_raw - 0.05:  # 循环回绕:补一圈时长保持单曲时间单调
		_wrap_offset += _loop_seconds
	_prev_raw = raw
	var song_t := maxf(0.0, raw + _wrap_offset
			+ AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	var b := int(song_t / sec_per_beat())
	while _last_fired < b:
		_last_fired += 1
		beat.emit(_last_fired)


func _on_phase_changed(new_phase: int) -> void:
	## 离开术中外任何阶段(收尾/结算/回准备)都收拍,BGM 恢复。
	if new_phase != GameState.Phase.SURGERY:
		stop()


func _make_loop() -> AudioStreamWAV:
	## 合成一小节鼓点:1-3 拍弱 hat,第 4 拍 kick+亮 hat 强音,小节头一个低音点。
	var spb := sec_per_beat()
	var frames := int(round(float(SAMPLE_RATE) * spb * BEATS_PER_BAR))
	_loop_seconds = float(frames) / float(SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var kick_phase := 0.0
	for f in frames:
		var t := float(f) / float(SAMPLE_RATE)
		var beat_pos := t / spb
		var bi := int(beat_pos)
		var bt := (beat_pos - float(bi)) * spb  # 距本拍起点秒数
		var s := 0.0
		var hat_amp := 0.36 if bi == CALL_BEAT else 0.2
		s += (randf() * 2.0 - 1.0) * hat_amp * exp(-bt * 160.0)
		if bi == CALL_BEAT and bt < 0.3:
			kick_phase += TAU * lerpf(140.0, 46.0, bt / 0.3) / float(SAMPLE_RATE)
			s += sin(kick_phase) * exp(-bt * 14.0) * 0.9
		if bi == 0:
			s += sin(TAU * 110.0 * bt) * exp(-bt * 30.0) * 0.28
		data.encode_s16(f * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var ws := AudioStreamWAV.new()
	ws.format = AudioStreamWAV.FORMAT_16_BITS
	ws.mix_rate = SAMPLE_RATE
	ws.stereo = false
	ws.data = data
	ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ws.loop_begin = 0
	ws.loop_end = frames
	return ws
