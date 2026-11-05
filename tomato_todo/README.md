# 🍅 Tomato Todo - 番茄钟 + 待办事项 全能助手

复刻经典「番茄Todo」的 **Flutter** 跨平台移动端应用。完全免费,全部功能畅用,**无会员、无付费墙、无 OTA**。

## ✨ 核心功能(全部可用,无付费项)

| 模块               | 功能                                                                   |
| ------------------ | ---------------------------------------------------------------------- |
| 🍅 **番茄钟**       | 25/5/15min 工作法、三阶段自动切换、进度圆盘、倒计时、声音提醒          |
| ✅ **任务管理**     | 新建/完成/删除/优先级、预估番茄数、关联当前番茄、统计完成番茄          |
| 📊 **数据统计看板** | 今日/本周/本月番茄数、每日柱状图、时间分配饼图、近12周热力图日历        |
| 🎨 **主题自由定制** | **8 种内置主题**(番茄经典/薄荷清新/深海蓝调/晨曦橙光/薰衣草紫/暗夜模式/赛博朋克/水墨国风)、**12 种预设渐变背景**、自定义相册选图、遮罩透明度可调 |

## 🚀 快速开始

### 1. 前置条件

- [Flutter SDK 3.0+](https://docs.flutter.dev/get-started/install)
- Android Studio(含 Android SDK)/Xcode
- 一台 Android 手机(开启 USB 调试)或 iOS 设备

### 2. 拉依赖

```sh
cd tomato_todo
flutter pub get
```

### 3. 运行到手机

```sh
# 查看已连接设备
flutter devices

# 直接运行
flutter run

# 指定设备
flutter run -d <device_id>
```

### 4. 打包安装包

```sh
# Android APK(含所有 ABI,约 8MB)
flutter build apk --release

# Android App Bundle (推荐上架 Google Play)
flutter build appbundle --release

# iOS(需要 Mac + Apple 账号)
flutter build ios --release
```

打包产物位置:
- APK → `build/app/outputs/flutter-apk/app-release.apk`
- AAB → `build/app/outputs/bundle/release/app-release.aab`

**安装**:把 APK 传到手机上直接点开安装即可,无需任何开发者账号。

## 📁 项目结构

```
tomato_todo/
├── pubspec.yaml
├── lib/
│   ├── main.dart                   # 入口 + MaterialApp + 背景 + 底部导航
│   ├── models/                     # 数据模型
│   │   ├── task.dart              # 任务(优先级/番茄预估/完成状态)
│   │   ├── pomodoro_record.dart   # 番茄钟记录(工作/短休/长休)
│   │   └── app_settings.dart      # 设置(时长/主题/声音/提醒)
│   ├── services/                  # 底层服务
│   │   ├── storage_service.dart   # SharedPreferences 持久化
│   │   └── timer_service.dart    # 番茄钟计时核心逻辑
│   ├── providers/                  # Provider 状态管理
│   │   ├── pomodoro_provider.dart
│   │   ├── task_provider.dart
│   │   └── settings_provider.dart
│   ├── screens/                    # 页面
│   │   ├── home_screen.dart      # 主界面(番茄钟 + 任务)
│   │   ├── stats_screen.dart     # 统计看板(图表 + 热力图)
│   │   └── settings_screen.dart  # 设置 & 主题
│   ├── widgets/                    # 可复用组件
│   │   ├── pomodoro_timer.dart   # 圆盘计时器 + 控制按钮
│   │   ├── task_item.dart        # 任务卡片
│   │   ├── task_input.dart       # 新增任务输入
│   │   └── heatmap_calendar.dart # 12 周热力图
│   └── theme/
│       └── backgrounds.dart       # 内置 8 主题 + 12 渐变背景
└── assets/
    ├── images/
    └── sounds/
```

## 🔧 技术栈

| 层           | 选型               |
| ------------ | ------------------ |
| 框架         | Flutter 3.x        |
| 语言         | Dart 3.x           |
| 状态管理     | Provider           |
| 本地存储     | SharedPreferences  |
| 图表         | fl_chart           |
| 图片选择     | image_picker       |
| UUID         | uuid               |
| 日期格式化   | intl               |

## 💡 自定义提示

- **改主题**:设置 → 主题,全部 8 个主题一键切换,**无任何付费门槛**
- **改背景**:设置 → 背景图,12 种预设渐变或从相册选自己的图,遮罩透明度可调
- **改时长**:设置 → 计时时长,5-90 分钟任调
- **本地数据**:所有任务、番茄记录、设置都存在手机本地 SharedPreferences,不上传到任何服务器

## 📱 跨平台

Flutter 一次编写,支持:

- ✅ Android 5.0+ (Lollipop)
- ✅ iOS 12.0+
- ✅ HarmonyOS NEXT
- ✅ 鸿蒙、MIUI、EMUI、OneUI 等主流定制 ROM

## 📜 关于

- 全部代码为自研实现,不含任何付费 API
- 数据 100% 本地,不收集、不上传
- 无服务器、无 OTA,直接装 APK 即用
