# 奶蛋桌宠 · Naidan Desktop Pet

一个使用 Swift、AppKit 和 SwiftUI 编写的 macOS 桌面陪伴小工具。透明桌宠、专注计时和本地待办，无第三方依赖。

公开版自带由代码绘制的原创几何小蛋示例：奶黄色身体、绿色小芽和八组简单动作。示例动作仅演示动画槽位，不复刻第三方视频表演；仓库不包含第三方视频、抠像帧或原版角色素材。

## 功能

- 拖动移动、单击切换动作、双击打开陪伴面板、右键打开菜单。
- 滚轮调整大小；支持置顶、隐藏、动作暂停和循环播放。
- 5 / 15 / 25 / 45 / 60 分钟专注计时；暂停、重置和完成轮次。
- 添加、完成和删除待办；通过 macOS UserDefaults 保存在本机。
- 独立应用标识，可与个人版本并存。

## 环境与构建

需要 macOS 14 或更新版本，以及 Xcode Command Line Tools（`xcode-select --install`）。脚本构建当前 Mac 架构，不生成通用二进制。

```bash
git clone https://github.com/mosheng2621983766-tech/naidan-desktop-pet.git
cd naidan-desktop-pet
bash build.sh
open "build/Naidan Demo.app"
```

也可从 GitHub 下载源码 ZIP，解压后在项目目录运行 `bash build.sh`。无需下载动画即可运行。默认产物位于 `build/`，编译缓存位于系统临时目录；可通过 `BUILD_DIR` 和 `CACHE_DIR` 指定位置。编译会更新指定输出目录中的示例应用。

应用仅做本地临时签名，未进行 Apple 公证；源码构建与已公证的商店安装包不同。尚未提供预编译发行包。

## 使用自己的动画

仅使用自己制作或明确获得相应授权的透明 PNG 帧。文件结构为：

```text
Frames/
  clip-01/000.png ... 095.png
  clip-02/000.png ... 095.png
  ...
  clip-08/000.png ... 095.png
```

建议每帧 480 × 480，每组 96 帧，以 24 fps 循环播放（4 秒）。八个槽位名称见 `Sources/main.swift` 的 `actionNames`。缺失或无法读取的帧自动使用内置示例画面。

```bash
FRAMES_DIR="/absolute/path/to/Frames" BUILD_DIR="build-custom" bash build.sh
```

每套素材使用新的输出目录，避免旧帧混入。默认忽略项目根目录的 `Frames/`；请勿把未经授权的素材提交到仓库。自定义素材的许可由其权利人决定，不因使用本项目而自动变成 MIT。

## 数据与边界

程序不请求网络服务，不使用云同步或分析 SDK。待办、位置、大小和完成轮次保存在独立的 `io.github.mosheng2621983766-tech.naidan-demo` 偏好设置中。关闭陪伴面板后计时继续；退出应用后当前倒计时不会恢复。专注完成会显示陪伴面板和气泡，不依赖系统通知权限。

## 已验证范围

在 Apple Silicon Mac 上完成编译和启动；验证了动作切换、专注开始／暂停／重置、待办添加／完成／删除。八组共 768 帧均检查为 480 × 480，中心实体与透明角落正常。Intel Mac 和跨系统版本尚未实机验证。

## 许可证

本仓库代码及内置程序绘制示例采用 [MIT License](LICENSE)。欢迎提交问题和改进建议。

## English

A small native macOS desktop companion with a transparent draggable pet, focus timer and local to-do list. Built with Swift/AppKit/SwiftUI, without external dependencies. Requires macOS 14+ and Xcode Command Line Tools. Run `bash build.sh`, then open `build/Naidan Demo.app`. The built-in geometric egg is drawn in code; no third-party character artwork or extracted video frames are included. Code and procedural demo are MIT licensed.
