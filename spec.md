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
│   ├── main.tscn              # 入口,流程控制 + 环境
│   ├── player.tscn            # 第一人称玩家(CharacterBody3D + Camera3D)
│   ├── instrument_table.tscn  # 器械台 + 6 槽位(Area3D)
│   ├── cart.tscn              # 推车(准备阶段器械来源)
│   ├── instrument.tscn        # 单件器械(RigidBody3D + 元数据)
│   ├── surgeon.tscn           # 医生手(需求触发 + 归还 + 拒绝)
│   └── ui/
│       ├── prep_card.tscn     # 摆放规范卡
│       ├── hud.tscn           # 计分/计时
│       ├── result.tscn        # 结算
│       └── countdown.tscn     # 3-2-1 倒计时
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
│   └── procedure.json         # 6 件器械定义 + 6 步需求序列(供 ProcedureData 读取)
└── assets/
    ├── models/
    ├── textures/
    ├── audio/
    └── fonts/
```

## 数据模型

### Instrument(器械)
```gdscript
{
  "id": "scalpel",
  "name_cn": "手术刀",
  "name_en": "Scalpel",
  "category": "cutting",        # 切开类
  "purpose": "切皮",
  "color": Color(0.9, 0.2, 0.2),# 盒体代用颜色
  "slot_index": 0               # 原槽位(0-5),按使用顺序
}
```
类别:cutting(切开)/ clamping(钳夹)/ grasping(夹持)/ suturing(缝合)/ dressing(敷料)

### 需求序列
按槽位顺序 = 使用顺序:`[scalpel, hemostat, forceps, scissors, needle_holder, gauze]`

## 阶段状态机(GameState)
```
PREP → COUNTDOWN → SURGERY → RESULT
```
- `PREP`:准备阶段,整理器械台
- `COUNTDOWN`:3-2-1 自动倒计时(准备全部正确后触发)
- `SURGERY`:术中递送循环
- `RESULT`:结算

信号:`phase_changed(new_phase)`

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
godot res://scenes/main.tscn
```
