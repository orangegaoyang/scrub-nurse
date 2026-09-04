# Scrub Nurse — 技术规范 (spec.md)

## 引擎与语言
- **引擎**:Godot 4.7.x(已通过 Homebrew 安装,CLI:`godot`)
- **语言**:GDScript
- **渲染**:Forward+(桌面),MSAA 2x
- **分辨率**:1280×720,canvas_items 拉伸,expand 宽高比

## 输入映射(project.godot)
| 动作 | 默认键 |
|------|--------|
| move_forward | W |
| move_back | S |
| move_left | A |
| move_right | D |
| interact | 鼠标左键 |
| ui_cancel | Esc(释放指针锁定) |

## Autoload(全局单例)
1. **GameState**(`scripts/autoload/game_state.gd`):阶段状态机、分数、信号
2. **ProcedureData**(`scripts/autoload/procedure_data.gd`):器械定义、需求序列、槽位顺序

## 项目结构
```
organizer/
├── project.godot
├── icon.svg
├── design.md
├── spec.md
├── todo.md
├── scenes/
│   ├── surgery.tscn           # 手术阶段(递送循环 + 结算)
│   ├── prep.tscn              # 准备阶段(整理器械台 → 清单 → 进入手术)
│   ├── player.tscn            # 第一人称玩家(CharacterBody3D + Camera3D)
│   ├── instrument_table.tscn  # 器械台 + 6 槽位(Area3D)
│   ├── cart.tscn              # 推车(准备阶段器械来源)
│   ├── instrument.tscn        # 单件器械(RigidBody3D + 元数据)
│   ├── surgeon.tscn           # 医生手(需求触发 + 归还 + 拒绝)
│   └── ui/
│       ├── prep_card.tscn     # (未用,规范卡已合并进 instrument_list)
│       ├── instrument_list.tscn # 器械清单(左上方,打开手术包后显示,结算隐藏)
│       ├── held_info.tscn     # 持物信息卡(顶部中央,名称+用途,淡入淡出)
│       ├── start_button.tscn  # "摆放完成，开始手术"按钮(替代 3-2-1 倒计时)
│       ├── hud.tscn           # 正确/错误(右上)+ 递送/取回提示(底部)
│       ├── result.tscn        # 结算
│       └── countdown.tscn     # (已弃用,保留文件)
├── scripts/
│   ├── main.gd                # 流程:准备→倒计时→术中→结算
│   ├── player_controller.gd   # 第一人称移动 + 鼠标看 + 指针锁定 + 交互射线
│   ├── instrument.gd          # 元数据:名称/类别/用途/图标/原槽位
│   ├── table_slot.gd          # 槽位判定(准备对错 / 放回对错)
│   ├── pickup_system.gd       # 拾取 + 附着 + 触碰交付
│   ├── surgeon_demand.gd      # 6 步线性需求队列 + 归还时机
│   ├── return_system.gd       # 取回 + 放回原位判定
│   └── autoload/
│       ├── game_state.gd
│       └── procedure_data.gd
├── data/
│   ├── instruments.json       # 器械共享目录:id/name_cn/name_en/category/purpose(跨手术共用)
│   ├── procedure_1.json       # 门诊小手术:器械布局 + 需求序列
│   ├── procedure_2.json       # 膝关节置换
│   └── procedure_3.json       # 开颅手术
└── assets/
	├── models/
	├── textures/
	├── audio/
	└── fonts/
```

## 数据模型

### 器械目录(instruments.json)—— 共享静态元数据
```json
{ "id": "scalpel", "name_cn": "手术刀", "name_en": "Scalpel", "category": "cutting", "purpose": "切开组织" }
{ "id": "gauze",   "name_cn": "纱布",   "name_en": "Gauze",   "category": "dressing", "purpose": "清洁/擦拭", "discard": true }
```
类别:cutting(切开)/ clamping(钳夹)/ grasping(夹持)/ suturing(缝合)/ dressing(敷料)
器械的静态名称/类别/用途/是否術者丢弃(`discard`)只在这里定义一次,所有手术共用。

### 手术流程(procedure_N.json)—— 每台手术的布局 + 需求
```json
{
  "procedure_id": "appendectomy",
  "procedure_name": "门诊小手术",
  "procedure_name_en": "Minor Excision",
  "neutral_zone": false,
  "back_table": false,
  "surgery_free_mayo": false,
  "instruments": [
    { "id": "scalpel", "slot_index": 0 },
    { "id": "gauze", "slot_index": 3, "count": 2, "discard": true }
  ],
  "sequence": ["scalpel", "hemostat", "scissors", "gauze", "scissors", "gauze"]
}
```
- `instruments[]` 只写每台手术独有的维护:器械 `id` + `slot_index`(Mayo 槽位 0-5 / back table ≥6),以及可选的 `count`(佈設數量,如纱布多件)。`discard` 已并入器械目录,不再在此写。
- **`uses` 不手寫** —— 由 procedure_data 依 sequence 中该 id 出现的次数自动统计(`def.uses`)。
- `sequence`:术中需求序列(可重复出现同一 id,对应多次 `uses`);若省略,则各器械依 slot_index 顺序各出现一次(legacy 行为)。

## 阶段状态机(GameState)
```
PREP → COUNTDOWN → SURGERY → RESULT
```
- `PREP`:准备阶段,整理器械台
- `COUNTDOWN`:就绪态(全部摆放正确后进入);显示"摆放完成，开始手术"按钮,点击后进入术中。**已取消 3-2-1 倒计时**
- `SURGERY`:术中递送循环
- `RESULT`:结算

信号:`phase_changed(new_phase)`、`held_changed(instrument)`、`score_updated()`、`prep_completed()`

## 场景布局(surgery.tscn)
- 固定俯视相机,Mayo 台在原点;护士以光标拾取/放置(无第一人称走位)
- **Mayo 台**:原点,6 槽位 + 器械散放区(TrayCollision 层 8)
- **医生**:病人右手侧 `(1.1, 1.3, 0)` 附近;手平时收回,需求时伸到 Mayo 前
- **中立区 / 背台**:按术式显隐(has_neutral_zone / has_back_table);结算卡挂在 UI 层

## 术中需求节奏(Conductor + surgeon_line.gd)
- 节拍时钟 `scripts/autoload/conductor.gd`:运行时合成 4/4 单小节鼓点循环
  (1-3 拍弱 hat,第 4 拍 kick 强音),从音频时钟推算拍点发 `beat` 信号,不用 Timer。
- 每件器械 = 一个"呼叫-应答"乐句:第 4 拍强音医生伸手喊器械(呼叫前一拍手预抬),
  玩家有一小节(4 拍)递送;递上播"啪"(`snap.wav`,按器械类别定音高);
  超时则在下一个强音拍敲手催促并重新呼叫。
- 使用阶段时长量化成整拍(4→2 拍随进程缩短);收尾(TIDY)起 Conductor 收拍,BGM 恢复。
- 难度 = BPM(procedure json 的 `bpm`:S1 90 / S2 105 / S3 120),窗口恒为 4 拍。
- 术中 BGM 自动压低(duck -16dB)给节拍层让路;HUD 顶部有四拍指示点。

## 关键交互实现要点

### 第一人称(player_controller.gd)
- `CharacterBody3D` + 胶囊 `CollisionShape3D` + `Camera3D`(头部)
- 鼠标 motion → 相机旋转(俯仰限制 ±89°)
- `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED`;Esc 释放
- WASD 移动;玩家位置固定在器械台前(可小幅移动或锁定)

### 拾取与附着(pickup_system.gd)
- `Camera3D` 发射 `RayCast3D` 检测器械/槽位/医生手
- 点击器械 → 器械 `reparent` 到相机前方附着节点,切换为 kinematic
- 附着后器械随视角移动,可见"正拿着"

### 触碰交付
- 附着器械带 `Area3D`,与医生手 `Area3D` 重叠 → 自动触发交付判定
- 正确:医生接住(器械 `reparent` 到医生手 → 短暂使用 → 归还)
- 错误:医生手推开动画 → 器械回到玩家附着节点 → 玩家放回原槽位

### 放回原位(return_system.gd)
- 拿着器械时点击槽位 → 判定 `instrument.slot_index == slot.index`
- 正确:器械归位,变绿
- 错误:台面拒绝,器械弹回手中,提示重放

### 器械台槽位(table_slot.gd)
- 6 个 `Area3D` 槽位,按使用顺序排列
- 准备阶段:判定放入的器械 id 与位置/顺序
- 术中:判定放回的器械是否回到原槽位

## 计分
- 准备阶段:正确率(6 件归位正确数 / 6)
- 术中:递送正确数、错误数、总用时
- 结算:星级(正确率 + 用时综合)

## 验证节点
- 阶段 3 后:能玩通"准备 → 倒计时",判定正确
- 阶段 5 后:能玩通"准备 → 术中(递送/取回/放回)→ 结算"全流程

## 运行与验证命令
```bash
# 生成导入缓存并校验项目(无 GUI)
godot --headless --import

# 启动游戏(GUI)
godot

# 运行指定场景
godot res://scenes/surgery.tscn
```
