# 中关村实验室打卡

一款面向 macOS 的原生打卡记录组件。按照“上月 25 日至本月 24 日”的周期统计工作时长，默认目标为每周期 160 小时。


## 主要功能

- 固定打卡周期：上月 25 日 00:00 至本月 24 日 23:59
- 默认上班时间 10:00、下班时间 22:00
- 默认时间只是建议值；未保存记录时，当日时长始终为 0
- 上下班时间任意一项缺失时，当日有效时长为 0
- 支持跨午夜记录、历史补录、编辑和删除
- 显示周期累计、剩余时长、完成率与剩余天数
- 菜单栏快捷“现在上班”和“现在下班”
- macOS 桌面 Widget 展示周期进度并支持交互式打卡
- JSON 完整备份与恢复；恢复前自动备份现有数据
- CSV 导出，可直接用 Excel 或 Numbers 打开
- 可选的本地上下班提醒
- 数据只保存在本机 App Group 容器中

## 系统要求

- macOS 14 Sonoma 或更高版本
- Xcode 16 或更高版本
- 当前项目已使用 macOS Tahoe 26.5.2 与 Xcode 26.6 验证
- Apple Account 已登录 Xcode

## 第一次运行

1. 双击打开 `Daka.xcodeproj`。
2. 在项目导航器中选择蓝色的 `Daka` 项目。
3. 依次选择 `Daka` 和 `DakaWidget` Target。
4. 在 **Signing & Capabilities** 中为两个 Target 选择同一个 Team。
5. 确认两个 Target 都包含 App Groups，并共同使用：

   ```text
   group.com.duanice.daka
   ```

6. 在顶部 Scheme 选择 `Daka`，运行目标选择 **My Mac**。
7. 按 `⌘R` 构建并运行。

如果 `group.com.duanice.daka` 在你的开发者团队中不可用，请将以下位置的标识符一起改成新的唯一值：

- `Shared/AppConstants.swift`
- `App/Daka.entitlements`
- `Widget/DakaWidget.entitlements`

首次运行后，若要添加桌面组件：

1. 在 macOS 桌面空白处右键。
2. 选择“编辑小组件”。
3. 搜索“中关村实验室打卡”。
4. 添加小号或中号组件。

## 数据规则

- 2026 年 8 月周期为 2026-07-25 至 2026-08-24。
- 每条记录归属其上班日期。
- 完整记录的时长为下班时间减去上班时间，精确到分钟。
- 未设置完整上下班时间时，时长为 0。
- 默认不自动扣除午休。
- 跨午夜必须在编辑界面显式开启。
- 内部统计以整数分钟保存和计算，避免浮点累计误差。

## 数据与隐私

应用不包含服务器、账号系统、广告或统计 SDK。数据默认保存在：

```text
group.com.duanice.daka
```

对应的 macOS App Group 安全容器中。个人数据库、导出文件、备份文件和签名证书都已排除在 Git 版本控制之外。

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
Intents/    Widget 交互式快捷打卡
Widget/     macOS 桌面 Widget
Resources/  图标和颜色资源
Tests/      XCTest 自动化测试
Tools/      可复现的图标生成和领域层冒烟测试工具
```

## 版本

当前版本：`1.0.0`
