# Scrub Nurse — 任务清单 (todo.md)

> 进度标记:`[ ]` 未开始 / `[~]` 进行中 / `[x]` 完成

## 阶段 0:环境与项目骨架
- [x] 安装 Godot 4.7.x(Homebrew)
- [x] 创建 project.godot(输入映射、autoload、显示配置)
- [x] 创建 icon.svg
- [x] 创建 design.md / spec.md / todo.md
- [x] 创建 autoload 脚本(game_state.gd, procedure_data.gd)
- [x] 创建 data/procedure.json
- [x] 创建 main.tscn 空场景(相机 + 灯 + 地板)+ player.tscn + 脚本
- [x] `godot --headless --import` 校验项目无错误
- [x] headless 运行无运行时错误,autoload 加载 procedure.json 成功

## 阶段 1:第一人称相机
- [ ] player.tscn:CharacterBody3D + CollisionShape3D(胶囊)+ Camera3D
- [ ] player_controller.gd:鼠标看(俯仰限制)+ 指针锁定 + Esc 释放
- [ ] player_controller.gd:WASD 移动
- [ ] player_controller.gd:交互 RayCast3D(从相机发射)
- [ ] 在 main.tscn 接入玩家,能在房间里看/走

## 阶段 2:器械台与器械
- [ ] instrument_table.tscn:台面 + 6 个槽位(Area3D + 碰撞)
- [ ] table_slot.gd:槽位元数据(index)+ 高亮
- [ ] instrument.tscn:盒体 Mesh + RigidBody3D + Area3D + 元数据
- [ ] instrument.gd:id/name/category/purpose/color/slot_index
- [ ] cart.tscn:推车(准备阶段器械来源区)
- [ ] pickup_system.gd:点击拾取 → reparent 到相机附着节点
- [ ] 在 main.tscn 摆好器械台,6 件器械放推车,能拾取附着

## 阶段 3:准备阶段逻辑
- [ ] GameState 阶段机:PREP 状态
- [ ] 准备阶段:点击器械 → 点击槽位放入
- [ ] table_slot.gd 判定:位置/顺序对错(绿/红反馈)
- [ ] ui/prep_card.tscn:摆放规范卡(6 槽位 + 顺序)
- [ ] 全部正确 → 自动进入 COUNTDOWN
- [ ] ui/countdown.tscn:3-2-1 倒计时 → 进入 SURGERY
- [ ] 验证:能玩通"准备 → 倒计时"

## 阶段 4:知识注入
- [ ] ProcedureData 从 data/procedure.json 加载器械百科
- [ ] 拾起器械时 UI 显示名称 + 用途
- [ ] 验证:拾起每件器械显示正确信息

## 阶段 5:术中递送(MVP 完成)
- [ ] surgeon.tscn:医生手(伸/收/拒绝动画)
- [ ] surgeon_demand.gd:6 步线性需求队列 + 图标/文字/语音提示
- [ ] 触碰交付:附着器械 Area3D 与医生手 Area3D 重叠 → 交付
- [ ] 正确:医生接住 → 使用 → 归还
- [ ] 错误:医生手拒绝/推开 → 器械回到玩家手中
- [ ] return_system.gd:触碰取回 → 放回原槽位判定
- [ ] 超时扣分
- [ ] ui/hud.tscn:计分/计时
- [ ] ui/result.tscn:6 步完成 → 星级 + 用时 + 正确率
- [ ] 验证:能玩通"准备 → 术中 → 结算"全流程

## 阶段 6:打磨
- [ ] 器械归位/递送/拒绝动画
- [ ] 音效(拾取、递送、对错、倒计时)
- [ ] 环境音/手术室氛围
- [ ] 星级动画
- [ ] 真实风格器械模型替换盒体

## 后续扩展(不在 MVP)
- [ ] 擦拭交互
- [ ] 数字快捷键递送
- [ ] 预判机制(提前备器械加分)
- [ ] 结尾清点(器械/纱布计数)
- [ ] 多术式 / 医生偏好
- [ ] 术前限时(准备阶段倒计时)
- [ ] 器械堆叠掉落物理
