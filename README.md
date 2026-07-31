# 中关村实验室打卡

一款面向 macOS 的原生打卡记录组件。按照“上月 25 日至本月 24 日”的周期统计工作时长，默认目标为每周期 160 小时。


## 主要功能

- 固定打卡周期：上月 25 日 00:00 至本月 24 日 23:59
- 默认上班时间 10:00、下班时间 22:00
- 默认时间只是建议值；未保存记录时，当日时长始终为 0
- 上下班时间任意一项缺失时，当日有效时长为 0
- 支持跨午夜记录、历史补录、编辑和删除
- 概览和历史页提供周期日历，点击任意日期即可补录或修改
- 可将今天或任意日期“一键摆烂”；摆烂日不计时，也不计入剩余可打卡日
- 显示周期累计、剩余时长、完成率与追赶计划
- 自动计算未打卡的剩余日期每天需要打多久，才能达到周期目标
- 菜单栏快捷“现在上班”和“现在下班”
- 小、中、大三种 macOS 桌面 Widget；大号组件概览每日打卡数据
- Widget 支持快捷上班、下班、今日摆烂和点击日期直达编辑；操作由主应用安全落库
- 保存、修改、删除和摆烂后提供即时反馈，关键操作支持撤销
- JSON 完整备份与恢复；恢复前自动备份现有数据
- CSV 导出，可直接用 Excel 或 Numbers 打开
- 可选的本地上下班提醒
- 原始数据库保存在本机 App Group 容器中；Widget 只读取主应用生成的最小数据快照

## 系统要求

- macOS 14 Sonoma 或更高版本
- Xcode 16 或更高版本
- 当前项目已使用 macOS Tahoe 26.5.2 与 Xcode 26.6 验证
- Apple Account 已登录 Xcode

## 第一次运行

1. 双击打开 `Daka.xcodeproj`。
2. 在项目导航器中选择蓝色的 `Daka` 项目。
3. 依次选择 `Daka`、`DakaWidget` 和 `DakaTests` Target。
4. 在 **Signing & Capabilities** 中为三个 Target 选择同一个 Team。
5. `Daka` Target 使用以下 App Group 保存原始数据库：

   ```text
   group.com.duanice.daka
   ```

   `DakaWidget` 不直接打开数据库，而是读取主应用生成的数据快照，因此使用 Personal Team 时也能正常显示。

6. 在顶部 Scheme 选择 `Daka`，运行目标选择 **My Mac**。
7. 按 `⌘R` 构建并运行。第一次打开主应用会自动生成 Widget 快照。

如果需要更换 App Group 标识符，请同步修改：

- `Shared/AppConstants.swift`
- `App/Daka.entitlements`

首次运行后，若要添加桌面组件：

1. 在 macOS 桌面空白处右键。
2. 选择“编辑小组件”。
3. 搜索“中关村实验室打卡”。
4. 按需要添加小号、中号或大号组件。大号组件可查看完整周期的每日概况。

## 数据规则

- 2026 年 8 月周期为 2026-07-25 至 2026-08-24。
- 每条记录归属其上班日期。
- 完整记录的时长为下班时间减去上班时间，精确到分钟。
- 未设置完整上下班时间时，时长为 0。
- 默认不自动扣除午休。
- 跨午夜必须在编辑界面显式开启。
- 摆烂日时长固定为 0，也不会作为追赶计划中的可打卡日期。
- “每天需要打卡时长”按今天至本周期结束、尚未完成且未设为摆烂的日期计算，并向上取整到分钟。
- 内部统计以整数分钟保存和计算，避免浮点累计误差。

## 数据与隐私

应用不包含服务器、账号系统、广告或统计 SDK。数据默认保存在：

```text
group.com.duanice.daka
```

对应的 macOS App Group 安全容器中。桌面组件所需的只读快照位于：

```text
~/Library/Application Support/com.duanice.daka/widget-snapshot-v1.json
```

快照仅包含计算 Widget 所需的日期、上下班时间、摆烂状态和周期目标，文件权限为当前用户可读写。个人数据库、快照、导出文件、备份文件和签名证书都已排除在 Git 版本控制之外。

建议每月至少导出一次 JSON 完整备份。CSV 适合查看和统计，不用于完整恢复。

## 开发

工程使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 维护。`Daka.xcodeproj` 已提交到仓库，可直接打开；修改 `project.yml` 后可重新生成：

```bash
xcodegen generate --spec project.yml
```

构建：

```bash
xcodebuild \
  -project Daka.xcodeproj \
  -scheme Daka \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

运行领域层冒烟测试：

```bash
mkdir -p /tmp/daka-module-cache
xcrun swiftc \
  -disable-sandbox \
  -module-cache-path /tmp/daka-module-cache \
  Shared/AppConstants.swift \
  Shared/AttendancePeriod.swift \
  Shared/AttendanceCalculator.swift \
  Tools/DomainSmokeTests.swift \
  -o /tmp/daka-domain-tests
/tmp/daka-domain-tests
```

完整 XCTest 测试：

```bash
xcodebuild \
  -project Daka.xcodeproj \
  -scheme Daka \
  -destination 'platform=macOS' \
  test
```

## 工程结构

```text
App/        主应用、菜单栏、历史、设置、备份与提醒
Shared/     数据模型、周期算法、时长算法和共享持久化
Intents/    Widget 与系统快捷操作的主应用跳转
Widget/     macOS 桌面 Widget
Resources/  图标和颜色资源
Tests/      XCTest 自动化测试
Tools/      可复现的图标生成和领域层冒烟测试工具
```

## 版本

当前版本：`1.1.2`
