# PluginHub

<p align="center">
  <img src="https://img.shields.io/github/release/littleCareless/PluginHub" />
  <img src="https://img.shields.io/github/license/littleCareless/PluginHub" />
  <img src="https://img.shields.io/github/stars/littleCareless/PluginHub" />
  <img src="https://img.shields.io/github/forks/littleCareless/PluginHub" />
</p>

> 统一管理你的 VS Code 系编辑器插件，告别重复安装与存储浪费

## 为什么需要这个工具？

在现代开发中，越来越多的开发者同时使用多个 VS Code 系编辑器：
- **Cursor** - AI 原生代码编辑器
- **VS Code** - 微软官方代码编辑器
- **Windsurf**、**Trae** 等新兴工具...

每个编辑器都维护自己的插件目录，导致：

| 问题 | 影响 |
|------|------|
| 🔄 重复安装 | 同一个插件在不同编辑器中各存一份 |
| 💾 磁盘浪费 | Copilot、Cline 等大型插件动辄数百 MB，重复存储占用大量空间 |
| 📦 版本混乱 | 不同编辑器可能安装了不同版本，难以统一管理 |
| 🛠️ 同步困难 | 新装一个编辑器，需要重新安装所有插件 |

**PluginHub 就是来解决这个问题的**——类似 Node.js 的 pnpm，通过符号链接实现插件共享，一处安装，处处可用。

## 特性

### 🔍 智能发现
- 自动扫描系统中已安装的 VS Code 系编辑器及其插件
- 无需手动配置，即装即用
- 支持自定义编辑器路径

### 📊 重复检测
- 分析所有编辑器的插件，识别重复安装
- 计算浪费的磁盘空间
- 识别版本冲突

### 🔗 符号链接管理
- 创建符号链接替代实际文件复制
- 多个编辑器共享同一份插件
- 支持批量链接/取消链接

### 🛡️ 安全可靠
- 自动验证链接有效性
- 修复损坏的链接
- 保留原始文件备份

### ⚡ 一键优化
- 自动生成优化方案
- 保留最新/最大的版本作为主副本
- 批量执行去重操作

### 🌐 国际化
- 支持 English
- 支持 简体中文

## 使用场景

| 场景 | 传统方式 | PluginHub |
|------|----------|-------------------|
| 新装 Cursor，想用已有的 Copilot | 重新下载安装 | 一键链接，秒级完成 |
| 5 个编辑器都装了 Cline | 占用 5 × 200MB = 1GB | 只需 200MB |
| 统一插件版本 | 手动逐个更新 | 集中管理，一处更新 |
| 检查插件重复 | 无法直观看到 | 自动检测并报告 |

## 支持的编辑器

- ✅ Cursor
- ✅ VS Code (Insiders)
- ✅ Windsurf
- ✅ Trae
- 🔧 可扩展支持更多基于 VS Code 的编辑器

### 计划支持

- ⏳ JetBrains IDEs (IntelliJ, WebStorm, etc.)
- ⏳ 更多 VS Code 衍生编辑器

## 系统要求

- **macOS** 14.0 (Sonoma) 或更高版本
- **Xcode** 15.0 或更高版本（用于编译）

## 安装

### 方法一：从 Homebrew 安装（推荐）

```bash
# 暂未发布，先从源码安装
```

### 方法二：从源码编译

```bash
# 1. 克隆项目
git clone https://github.com/littleCareless/PluginHub.git
cd PluginHub

# 2. 安装 XcodeGen（如果没有）
brew install xcodegen

# 3. 生成 Xcode 项目
xcodegen generate

# 4. 编译（Debug 版本）
xcodebuild -project PluginHub.xcodeproj -scheme PluginHub -configuration Debug build

# 5. 编译（Release 版本）
xcodebuild -project PluginHub.xcodeproj -scheme PluginHub -configuration Release build

# 6. 运行应用
open build/DerivedData/Build/Products/Debug/PluginHub.app
# 或
open build/DerivedData/Build/Products/Release/PluginHub.app
```

### 方法三：使用 xcodegen 直接运行

```bash
# 安装依赖并生成项目后，可以用 open 直接打开
xcodegen generate
open PluginHub.xcodeproj
# 在 Xcode 中按 Cmd+R 运行
```

## 快速开始

1. **启动应用** - 打开 PluginHub
2. **扫描编辑器** - 点击侧边栏的"扫描"按钮，自动发现已安装的 AI 编辑器
3. **查看插件** - 在"插件"页面查看所有已安装的插件
4. **检测重复** - 点击"重复检测"分析插件重复情况
5. **执行优化** - 选择优化方案，一键创建符号链接

## 项目结构

```
PluginHub/
├── Sources/
│   ├── App/
│   │   ├── PluginHubApp.swift          # 应用入口
│   │   └── Localization.swift          # 本地化支持
│   ├── Models/
│   │   ├── Plugin.swift                # 插件模型
│   │   ├── Editor.swift                # 编辑器模型
│   │   └── DuplicateReport.swift       # 重复检测报告模型
│   ├── Services/
│   │   ├── PluginDiscovery/             # 插件发现服务
│   │   ├── PluginStore/                # 插件存储服务
│   │   ├── LinkManager/                # 符号链接管理
│   │   └── Deduplicator/               # 去重服务
│   └── Views/
│       ├── ContentView.swift           # 主视图
│       ├── PluginListView.swift        # 插件列表
│       ├── EditorViews.swift           # 编辑器管理
│       ├── DuplicateViews.swift        # 重复检测
│       └── SettingsViews.swift         # 设置页面
├── Resources/
│   ├── Assets.xcassets/                # 资源文件
│   ├── en.lproj/                       # 英文本地化
│   └── zh-Hans.lproj/                  # 简体中文本地化
├── Tests/
│   └── PluginHubTests.swift           # 单元测试
└── project.yml                          # XcodeGen 配置
```

## 工作原理

```
传统方式 (每个编辑器独立存储插件):
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Cursor  │    │ VS Code │    │Windsurf │
│ plugins │    │ plugins │    │ plugins │
│  (200MB)│    │  (200MB)│    │  (200MB)│
└────┬────┘    └────┬────┘    └────┬────┘
     │              │              │
     └──────────────┴──────────────┘
              总计: 600MB

AI Plugin Manager (通过符号链接共享插件):
                    ┌─────────────┐
                    │ Plugin Store│
                    │   (200MB)   │
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
     ┌─────────┐    ┌─────────┐    ┌─────────┐
     │ Cursor  │    │ VS Code │    │Windsurf │
     │  link → │    │  link → │    │  link → │
     └─────────┘    └─────────┘    └─────────┘
              总计: 200MB (节省 67%)
```

## 技术栈

| 技术 | 用途 |
|------|------|
| SwiftUI | UI 框架 |
| Swift | 编程语言 |
| XcodeGen | 项目生成 |
| SQLite | 数据存储 |
| UserDefaults | 轻量配置 |

## 常见问题

### Q: 这个工具安全吗？
A: 是的。AI Plugin Manager 只创建符号链接，不删除任何原始文件。所有操作都是可逆的。

### Q: 符号链接会影响编辑器性能吗？
A: 不会。符号链接在文件系统中是透明的，编辑器无法区分符号链接和实际文件。

### Q: 如何卸载？
A: 只需删除应用即可，不会影响任何编辑器的插件。如果需要恢复之前的独立存储，手动复制一份插件即可。

### Q: 支持 Windows 或 Linux 吗？
A: 目前仅支持 macOS。Windows/Linux 版本暂无计划，欢迎贡献代码。

### Q: 为什么某些插件没有被识别？
A: 目前主要支持标准的 VS Code 插件目录结构。如果你的编辑器使用非标准路径，可以手动添加编辑器配置。

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. **Fork** 本仓库
2. **创建** 你的特性分支 (`git checkout -b feature/amazing-feature`)
3. **提交** 你的更改 (`git commit -m 'Add some amazing feature'`)
4. **推送** 分支 (`git push origin feature/amazing-feature`)
5. **打开** Pull Request

### 开发环境设置

```bash
# 1. 克隆你的 fork
git clone https://github.com/YOUR_USERNAME/PluginHub.git
cd PluginHub

# 2. 安装 XcodeGen
brew install xcodegen

# 3. 生成项目
xcodegen generate

# 4. 在 Xcode 中打开
open PluginHub.xcodeproj
```

### 代码规范

- 遵循 Swift 代码规范
- 使用 SwiftLint 进行代码检查
- 确保新功能有对应的单元测试

## 更新日志

查看 [Releases](https://github.com/littleCareless/PluginHub/releases) 了解版本历史。

## 许可证

本项目基于 MIT 许可证开源 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 致谢

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - 项目生成工具
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - 强大的 UI 框架

## 联系方式

- GitHub Issues: https://github.com/littleCareless/PluginHub/issues
- 作者: littleCareless

---

如果这个项目对你有帮助，请 ⭐️ Star 支持！