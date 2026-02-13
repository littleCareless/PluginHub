import XCTest
@testable import AIPluginManager

final class PluginModelTests: XCTestCase {
    func testPluginUniqueId() {
        let plugin = Plugin(
            publisherId: "ms-python",
            extensionId: "python",
            displayName: "Python",
            description: "Python 语言支持"
        )

        XCTAssertEqual(plugin.uniqueId, "ms-python.python")
    }

    func testPluginHasUpdate() {
        let plugin = Plugin(
            publisherId: "test",
            extensionId: "test-plugin",
            displayName: "Test Plugin",
            description: "Test",
            version: "1.0.0",
            latestVersion: "1.1.0"
        )

        XCTAssertTrue(plugin.hasUpdate)
    }

    func testPluginNoUpdate() {
        let plugin = Plugin(
            publisherId: "test",
            extensionId: "test-plugin",
            displayName: "Test Plugin",
            description: "Test",
            version: "1.1.0",
            latestVersion: "1.1.0"
        )

        XCTAssertFalse(plugin.hasUpdate)
    }
}

final class EditorModelTests: XCTestCase {
    func testDefaultExtensionsPath() {
        let cursor = Editor(type: .cursor)
        XCTAssertTrue(cursor.extensionsPath.contains("Cursor"))
        XCTAssertTrue(cursor.extensionsPath.contains("extensions"))

        let vscode = Editor(type: .vscode)
        XCTAssertTrue(vscode.extensionsPath.contains(".vscode"))
        XCTAssertTrue(vscode.extensionsPath.contains("extensions"))
    }
}

final class DuplicateReportTests: XCTestCase {
    func testDuplicateCount() {
        let instances = [
            DuplicateInstance(
                editorName: "Cursor",
                editorId: UUID(),
                path: "/path/to/plugin1",
                version: "1.0.0",
                size: 1024
            ),
            DuplicateInstance(
                editorName: "VSCode",
                editorId: UUID(),
                path: "/path/to/plugin2",
                version: "1.0.0",
                size: 1024
            )
        ]

        let group = DuplicatePluginGroup(
            pluginUniqueId: "test.plugin",
            displayName: "Test Plugin",
            instances: instances
        )

        XCTAssertEqual(group.duplicateCount, 2)
        XCTAssertFalse(group.isVersionConflict)
    }

    func testVersionConflict() {
        let instances = [
            DuplicateInstance(
                editorName: "Cursor",
                editorId: UUID(),
                path: "/path/to/plugin1",
                version: "1.0.0",
                size: 1024
            ),
            DuplicateInstance(
                editorName: "VSCode",
                editorId: UUID(),
                path: "/path/to/plugin2",
                version: "1.1.0",
                size: 1024
            )
        ]

        let group = DuplicatePluginGroup(
            pluginUniqueId: "test.plugin",
            displayName: "Test Plugin",
            instances: instances
        )

        XCTAssertTrue(group.isVersionConflict)
        XCTAssertEqual(group.allVersions, ["1.0.0", "1.1.0"])
    }
}
