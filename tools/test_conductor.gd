extends Node
## Headless check: Conductor beat clock accuracy + call-beat alignment.
## Run: godot --headless res://tools/test_conductor.tscn

var _t0 := 0.0
var _times: Array[float] = []


func _ready() -> void:
	Conductor.beat.connect(_on_beat)
	Conductor.start(120.0)
	_t0 = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(3.2).timeout
	var spb := Conductor.sec_per_beat()
	var ok := _times.size() >= 6
	var mean := 0.0
	for i in _times.size():
		print("beat %d: t=%.3f" % [i, _times[i]])
	for i in range(1, _times.size()):
		mean += _times[i] - _times[i - 1]
	if _times.size() >= 2:
		mean /= float(_times.size() - 1)
		# headless dummy 音驱精度有限,只验证量级;真实精度来自音频时钟公式
		if absf(mean - spb) > spb * 0.15:
			ok = false
	# 拍号对齐:global=5(≡1 mod 4)时距下一强音应为 2 拍
	if Conductor.global_beat() % 4 == 1 and Conductor.beats_until_call() != 2:
		ok = false
	print("intervals mean=%.3f spb=%.3f beats_until_call=%d global=%d" %
			[mean, spb, Conductor.beats_until_call(), Conductor.global_beat()])
	print("RESULT: ", "OK" if ok else "FAIL")
	Conductor.stop()
	get_tree().quit()


func _on_beat(global_beat: int) -> void:
	var t := Time.get_ticks_msec() / 1000.0 - _t0
	if global_beat < _times.size():
		return
	_times.append(t)
