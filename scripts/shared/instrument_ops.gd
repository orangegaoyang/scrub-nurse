class_name InstrumentOps
## 器械携带/放置的共用原语。prep 的 pickup_system 与术中的 nurse_actions 共用,
## 只做机械操作(状态/reparent/碰撞/姿态),不碰计分、音效与流程——那些留在
## 各自的调用方,两边规则不同。

const SLOT_REST_Y := 0.01  # 入槽后贴槽面的高度
const HOLD_TILT_PREP := Vector3(15.0, 90.0, 0.0)  # prep 俯视:长轴顺手
const HOLD_TILT_SURGERY := Vector3(15.0, 0.0, 0.0)  # 术中:平托


static func attach_to_hand(inst: Instrument, held_parent: Node3D, tilt: Vector3) -> void:
	## 拿起:挂到手持锚点,关碰撞、冻结、给一个持握倾角。
	inst.set_state(Instrument.State.HELD)
	inst.reparent(held_parent)
	inst.collision_layer = 0
	inst.freeze = true
	inst.rotation_degrees = tilt


static func seat_in_slot(inst: Instrument, slot: TableSlot) -> void:
	## 入 Mayo 槽:贴槽面、竖直(长轴沿 X)、登记占用。
	inst.set_state(Instrument.State.IN_SLOT)
	inst.reparent(slot)
	inst.transform = Transform3D.IDENTITY
	inst.position = Vector3(0, SLOT_REST_Y, 0)
	inst.rotation_degrees = Vector3(0, 90, 0)
	inst.collision_layer = 1
	inst.freeze = true
	slot.occupied = true
	slot.current_instrument = inst


static func seat_in_back_zone(inst: Instrument, bzone: BackZone) -> void:
	## 入背台分类分区(分区自己找锚点摆位)。
	bzone.place_instrument(inst)
	inst.collision_layer = 1


static func rest_on_mayo(inst: Instrument, mayo: Node3D, local: Vector3) -> void:
	## 平放 Mayo 台面(局部坐标,调用方负责 clamp)。
	inst.set_state(Instrument.State.ON_MAYO)
	inst.reparent(mayo)
	inst.position = local
	inst.rotation_degrees = Vector3.ZERO
	inst.collision_layer = 1
	inst.freeze = true


static func put_back(inst: Instrument, parent: Node, state: int) -> void:
	## 取消拾取:放回出处、恢复碰撞与冻结。位姿由调用方恢复
	## (prep 恢复全局位姿;术中 Mayo 分支恢复局部位姿)。
	inst.set_state(state)
	inst.reparent(parent)
	inst.collision_layer = 1
	inst.freeze = true
