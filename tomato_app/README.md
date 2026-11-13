# 时光秘书 · Shiguang Secretary

一款专注「个人时间管理」的本地优先 Flutter 应用：日程、待办、番茄钟、目标、记录五位一体，所有数据仅保存在本机。

当前版本：**v3.1.0**（versionCode 6）
包名：`com.tomato.tomato_app`

## 核心功能

### 1. 待办（单次 / 重复 / 固定）
- **单次**：手动选择优先级（默认高）与预期时间（默认当天 0 点）。
- **重复**：只需设置天数周期（任意 N 天）。完成后从完成时刻起算，满周期自动回到待办；周期内优先级随进度自动递进（低 → 中 → 高）。
- **固定**：每天 / 每周某天 / 每月某日。到期当天 0 点自动回归待办，单条记录原地复用，不产生重复条目。
- **排序规则**：手动置顶 → 优先级（高/中/低）→ 预期时间（早 → 晚）→ 创建时间。
- 子任务支持在待办列表内下拉展开、逐项独立勾选；上拉收起只显示主待办。
- 徽章顺序：优先级 → 番茄钟 → 周期/固定日期 → 子任务；自动优先级用颜色 + 小箭头表达。
- 「周期 / 固定待办」管理页可随时取消周期，或让休眠中的待办立即回归。

### 2. 专注（番茄钟）
- 卡片仅保留开始 / 暂停、重置与「常亮」开关，取消阶段切换按钮。
- 工作结束弹出「继续工作 / 休息」；选择继续则下一轮结束后不再询问，直接进入休息。
- 休息长短由算法自动判断：最近 3 小时累计专注 ≥ 150 分钟进入长休息，否则短休息。
- 屏幕常亮生效条件：已开启常亮 + 番茄运行中 + 停留在专注页。
- 离开专注页或切到后台时，通知栏常驻「专注进行中」；回到专注页自动收起。
- 专注结束通过高优先级通知提醒，点击回到 App 直接弹出「继续工作 / 休息」选择。

### 3. 日程
- 独立的日程页（日视图）：日期切换、时间块、完成勾选、周视图入口。
- 「从待办加入日程」：选择一条当前待办，自动生成关联时间块；日程勾选完成会同步完成待办。
- 今日复盘入口移至日程页；开启每日复盘提醒后，到点发送通知，点击直达复盘编辑。

### 4. 记录（时间轴）
- 月历 + 当天完成记录，按时间顺序展示「今天先做了什么、后做了什么」。
- 月历区域已压缩高度，记录区占比更舒适。
- 右上角入口直达数据统计。
- 取消完成会同步撤销时间轴对应记录；时间轴仅作展示，不提供单独删除。

### 5. 目标
- 目标进度、里程碑与平均进度统计；统计页保留目标平均进度，单目标明细在目标页查看。

### 6. 数据统计
- 周期：**周 / 月 / 季 / 年**，折线图展示专注趋势。
- 横坐标随周期细化：周 → 周一…周日；月 → 该年第 N 周；季 → 月份；年 → 春 / 夏 / 秋 / 冬。
- 洞察：最佳专注时段、估时准确度、连续专注天数、逾期数量；另有时间投入与活动热力图。

### 7. 数据与隐私
- 全部数据保存在本机 SharedPreferences，不上传服务器。
- 自动清理 366 天前的过期记录，避免无限占用空间。
- 已移除导出文件 / 剪贴板导入等冗余入口；换机与版本升级由系统备份与同名签名安装保障。

## 技术栈
- Flutter 3.27 / Dart 3.6，Material 3
- Provider 状态管理
- fl_chart 图表、flutter_local_notifications 通知、wakelock_plus 屏幕常亮
- 完整中文本地化（flutter_localizations）

## 本地开发环境搭建

以下为从零开始搭建「时光秘书」开发环境的完整步骤，适用于 Linux / macOS / Windows。

### 1. 基础要求

| 组件 | 版本 | 说明 |
|------|------|------|
| Flutter SDK | **3.27.4** (Dart 3.6.2) | 必须严格匹配，其他版本可能有兼容性问题 |
| Java (JDK) | **17 (LTS)** | Gradle 8.3 官方支持；JDK 21+ 会导致 Gradle 解析失败 |
| Android SDK | API Level 35 (Android 15) | platforms;android-35 + build-tools;35.0.0 + platform-tools |
| Gradle | 8.3 | 由 `gradle-wrapper.properties` 指定，首次构建自动下载 |
| 操作系统 | macOS / Linux / Windows | 推荐 macOS 或 Linux |

### 2. 安装 Flutter SDK

下载指定版本并解压（不要用 `flutter upgrade`，会升级到不兼容版本）：

```bash
# Linux
curl -L -o flutter.tar.xz \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.4-stable.tar.xz"
tar -xf flutter.tar.xz -C /opt   # 或任意你有权限的目录
rm flutter.tar.xz

# macOS
curl -L -o flutter.zip \
  "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.27.4-stable.zip"
unzip flutter.zip -d ~/development
rm flutter.zip
```

把 Flutter 加入 PATH 并验证：

```bash
export PATH="/opt/flutter/bin:$PATH"   # Linux
export PATH="$HOME/development/flutter/bin:$PATH"   # macOS

flutter --version
# 预期输出: Flutter 3.27.4 • Dart 3.6.2
```

> ⚠️ 不要使用高于 3.27.4 的 Flutter 版本。本项目依赖的部分插件与新版 Flutter 的 Kotlin / Gradle 要求不兼容。

### 3. 安装 Java 17 (JDK)

项目使用 Gradle 8.3，**只兼容 JDK 17**。JDK 21/25 会报 `Unsupported class file major version` 或 plugin 解析失败。

**Linux (Ubuntu/Debian)：**
```bash
sudo apt update
sudo apt install openjdk-17-jdk -y
java -version   # 应显示 17.x
```

**macOS (Homebrew)：**
```bash
brew install openjdk@17
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
java -version
```

设置 `JAVA_HOME`（加入 `~/.bashrc` 或 `~/.zshrc`）：

```bash
# Linux
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
# macOS Apple Silicon
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
```

### 4. 安装 Android SDK

**方式一：Android Studio（推荐新手）**

下载 [Android Studio](https://developer.android.com/studio)，安装后打开：
- `Settings → Languages & Frameworks → Android SDK`
- 勾选 **Android 15 (API 35)** 平台
- 在 `SDK Tools` 页勾选 **Android SDK Build-Tools 35.0.0**、**Android SDK Platform-Tools**
- 记录顶部显示的 SDK 路径

**方式二：命令行（适合 CI / 无 GUI 环境）**

```bash
# 下载 Android cmdline-tools
mkdir -p $HOME/android-sdk/cmdline-tools
curl -L -o cmdline-tools.zip \
  "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
unzip -q -o cmdline-tools.zip -d $HOME/android-sdk/cmdline-tools
mv $HOME/android-sdk/cmdline-tools/cmdline-tools $HOME/android-sdk/cmdline-tools/latest
rm cmdline-tools.zip

# 接受许可并安装所需组件
yes | $HOME/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses
$HOME/android-sdk/cmdline-tools/latest/bin/sdkmanager \
  "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

设置环境变量（加入 `~/.bashrc` 或 `~/.zshrc`）：

```bash
export ANDROID_HOME=$HOME/android-sdk
export PATH=$ANDROID_HOME/platform-tools:$PATH
```

### 5. 配置项目

克隆项目并安装依赖：

```bash
git clone <your-repo-url> tomato_app
cd tomato_app

# 让 Flutter 知道 Android SDK 位置
flutter config --android-sdk $ANDROID_HOME

# 安装 Dart 依赖
flutter pub get
```

验证环境：

```bash
flutter doctor -v
# 确保 Flutter、Android toolchain、Connected device 三项均为 ✓
```

### 6. 运行调试版

连接 Android 设备（开启 USB 调试）或启动模拟器，然后：

```bash
flutter run
```

### 7. 构建 Release APK

#### 7.1 配置签名

首次构建 release 版需要生成签名密钥（**只需生成一次，妥善保管**）：

```bash
cd android
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -storepass shiguang_release_2026 \
  -alias shiguang_app \
  -keypass shiguang_release_2026 \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "C=CN, ST=Beijing, L=Beijing, O=Shiguang, OU=Mobile, CN=Shiguang Secretary"
```

创建 `android/key.properties`：

```properties
storePassword=shiguang_release_2026
keyPassword=shiguang_release_2026
keyAlias=shiguang_app
storeFile=upload-keystore.jks
```

> ⚠️ `upload-keystore.jks` 和 `key.properties` 已被 `.gitignore` 忽略，不会提交到仓库。**务必把 keystore 文件备份到安全位置**，丢失后无法对已发布版本做覆盖升级。

#### 7.2 构建

```bash
cd tomato_app
flutter build apk --release
```

产物路径：`build/app/outputs/flutter-apk/app-release.apk`（约 24-25 MB）

验证签名：

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
# Owner 应为 CN=Shiguang Secretary
```

### 8. 常见问题

**Q: `flutter pub get` 失败 / 依赖下载慢**
A: 设置国内镜像：
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

**Q: 构建报 `Unsupported class file major version 65/69`**
A: JDK 版本太高。切换到 JDK 17（见步骤 3）。

**Q: 构建报 `Could not resolve plugin dev.flutter.flutter-plugin-loader`**
A: Gradle 版本与 JDK 不匹配。确认用的是 JDK 17，Gradle wrapper 指向 8.3。

**Q: `flutter run` 找不到设备**
A: 执行 `adb devices` 确认设备已连接并授权；模拟器需 Android 15 (API 35) 镜像。

**Q: 安装 APK 时提示「签名不一致无法覆盖安装」**
A: 卸载手机上的旧版本后再安装。签名密钥变更后无法覆盖旧版。

## 目录结构

```
lib/
  core/        # 工具函数与全局导航
  models/      # 待办、日程、目标、复盘、番茄等数据模型
  providers/   # 状态管理
  screens/     # 日程 / 待办 / 专注 / 目标 / 记录 / 设置等页面
  services/    # 存储、通知、计时
  theme/       # 主题与背景
  widgets/     # 通用组件与编辑器
```
