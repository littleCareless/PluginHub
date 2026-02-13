# AI Plugin Manager

一个用于管理多个基于 VSCode 的 AI 代码编辑器插件的工具。

## 功能

- 🔍 **插件发现**：自动扫描 Cursor、VSCode、Roo Code 等编辑器的插件目录
- 🔗 **集中存储**：类似 pnpm store，统一存储插件，所有编辑器共享
- 📊 **重复检测**：检测并报告重复安装的插件
- 🚀 **批量操作**：一键链接/取消链接插件到多个编辑器
- ⚙️ **智能链接**：使用符号链接，避免重复存储

## 支持的编辑器

- Cursor
- VSCode
- Roo Code

## 安装

### 从源码编译

```bash
# 克隆项目
git clone https://github.com/yourusername/AIPluginManager.git
cd AIPluginManager

# 生成 Xcode 项目
brew install xcodegen
xcodegen generate

# 编译
xcodebuild -project AIPluginManager.xcodeproj -scheme AIPluginManager -configuration Release build
```

## 使用

1. 打开 AI Plugin Manager
2. 点击"扫描编辑器"发现所有插件
3. 查看重复检测报告
4. 点击"优化"一键去重

## 技术栈

- SwiftUI
- Swift
- XcodeGen
- SQLite

## License

MIT
