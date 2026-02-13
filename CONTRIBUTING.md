# 贡献指南

感谢你对 AI Plugin Manager 的兴趣！我们欢迎任何形式的贡献，包括但不限于代码提交、问题反馈、功能建议、文档改进等。

## 行为准则

请阅读并遵守我们的 [行为准则](CODE_OF_CONDUCT.md)。我们期望所有参与者都能保持专业和友好。

## 如何贡献

### 报告 Bug

如果你发现了 Bug，请使用 [Bug 报告模板](.github/ISSUE_TEMPLATE/bug_report.md) 提交 Issue。请确保包含：
- 清晰的 Bug 描述
- 详细的复现步骤
- 环境信息（macOS 版本、Xcode 版本等）
- 相关的日志或截图

### 提出新功能

如果你有新功能的建议，请使用 [功能请求模板](.github/ISSUE_TEMPLATE/feature_request.md) 提交 Issue。请详细描述：
- 功能的用途和价值
- 你认为的解决方案
- 可能的替代方案

### 提交代码

1. **Fork** 本仓库
2. **克隆** 你的 Fork：
   ```bash
   git clone https://github.com/YOUR_USERNAME/AIPluginManager.git
   cd AIPluginManager
   ```
3. **创建** 特性分支：
   ```bash
   git checkout -b feature/amazing-feature
   # 或
   git checkout -b fix/annoying-bug
   ```
4. **进行** 你的修改
5. **提交** 你的更改：
   ```bash
   git add .
   git commit -m 'Add some amazing feature'
   ```
6. **推送** 到你的 Fork：
   ```bash
   git push origin feature/amazing-feature
   ```
7. **打开** Pull Request

## 开发环境

### 环境要求

- **macOS** 14.0 (Sonoma) 或更高版本
- **Xcode** 15.0 或更高版本
- **Homebrew**（用于安装工具）

### 快速开始

```bash
# 1. 安装 XcodeGen
brew install xcodegen

# 2. 克隆项目
git clone https://github.com/littleCareless/AIPluginManager.git
cd AIPluginManager

# 3. 生成 Xcode 项目
xcodegen generate

# 4. 在 Xcode 中打开
open AIPluginManager.xcodeproj

# 5. 运行 (Cmd + R)
```

### 构建命令

```bash
# Debug 构建
xcodebuild -project AIPluginManager.xcodeproj \
  -scheme AIPluginManager \
  -configuration Debug \
  build

# Release 构建
xcodebuild -project AIPluginManager.xcodeproj \
  -scheme AIPluginManager \
  -configuration Release \
  build

# 运行测试
xcodebuild -project AIPluginManager.xcodeproj \
  -scheme AIPluginManager \
  test
```

## 代码规范

### Swift 代码风格

- 遵循 [Swift 官方代码风格指南](https://swift.org/documentation/api-design-guidelines/)
- 使用 SwiftLint 进行代码检查（推荐）
- 变量命名使用驼峰命名法
- 类名使用大驼峰命名法
- 常量使用全大写加下划线

### 命名规范

```swift
// 类和结构体
class PluginManager { }
struct PluginInfo { }

// 变量和函数
var pluginList: [Plugin]
func scanPlugins() { }

// 枚举
enum EditorType {
    case cursor
    case vscode
}
```

### 注释规范

- 使用 `// MARK:` 对代码进行分组
- 公共 API 必须添加文档注释
- 复杂的业务逻辑添加解释性注释

```swift
// MARK: - Plugin Discovery

/// 发现指定编辑器目录下的所有插件
/// - Parameter editor: 编辑器实例
/// - Returns: 插件数组
func discoverPlugins(in editor: Editor) async throws -> [Plugin] {
    // ...
}
```

### 提交信息规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

类型说明：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具更新

示例：
```
feat(plugin): 添加插件版本检测功能

- 新增 version 属性到 Plugin 模型
- 添加 hasUpdate 计算属性
- 支持从 package.json 读取版本信息

Closes #123
```

## 项目结构

```
AIPluginManager/
├── Sources/
│   ├── App/              # 应用入口
│   ├── Models/           # 数据模型
│   ├── Services/         # 业务逻辑服务
│   └── Views/            # SwiftUI 视图
├── Resources/            # 资源文件
├── Tests/                # 单元测试
└── project.yml           # XcodeGen 配置
```

## 测试

- 所有新功能应包含对应的单元测试
- 确保修改不会破坏现有测试
- 运行 `xcodebuild test` 验证

```bash
# 运行所有测试
xcodebuild -project AIPluginManager.xcodeproj test

# 运行特定测试类
xcodebuild -project AIPluginManager.xcodeproj \
  -scheme AIPluginManager \
  -only-testing:AIPluginManagerTests/PluginTests
```

## 许可证

通过贡献代码，你同意你的贡献将在 [MIT 许可证](LICENSE) 下发布。

## 联系方式

- 问题咨询：GitHub Issues
- 交流讨论：欢迎提交 Issue 进行讨论

---

感谢你的贡献！🎉
