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

final class PluginStoreCASTests: XCTestCase {
    private var tempRoot: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AIPluginManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        defaultsSuiteName = "AIPluginManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults.set(true, forKey: "enableSymlinks")
    }

    override func tearDownWithError() throws {
        if let defaults, let defaultsSuiteName {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        if let tempRoot, FileManager.default.fileExists(atPath: tempRoot.path) {
            try FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testAddPluginUsesContentAddressedPathForSameContent() async throws {
        let sourceA = tempRoot.appendingPathComponent("source-a", isDirectory: true)
        let sourceB = tempRoot.appendingPathComponent("source-b", isDirectory: true)
        try createPluginFixture(at: sourceA, content: "same-content")
        try createPluginFixture(at: sourceB, content: "same-content")

        let service = PluginStoreService(
            storePath: tempRoot.appendingPathComponent("store").path,
            userDefaults: defaults
        )

        let pluginA = Plugin(
            publisherId: "a",
            extensionId: "pluginA",
            displayName: "A",
            description: "A",
            installedPath: sourceA.path
        )
        let pluginB = Plugin(
            publisherId: "b",
            extensionId: "pluginB",
            displayName: "B",
            description: "B",
            installedPath: sourceB.path
        )

        let storedA = try await service.addPlugin(pluginA, from: sourceA.path)
        let storedB = try await service.addPlugin(pluginB, from: sourceB.path)

        XCTAssertEqual(storedA.storePath, storedB.storePath)
        XCTAssertNotNil(storedA.storePath)
        XCTAssertTrue(storedA.storePath!.contains("/objects/sha256/"))
    }

    func testLinkPluginAutoStoresWhenStorePathMissing() async throws {
        let source = tempRoot.appendingPathComponent("source-plugin", isDirectory: true)
        let editorPath = tempRoot.appendingPathComponent("editor/extensions", isDirectory: true)
        try createPluginFixture(at: source, content: "link-me")
        try FileManager.default.createDirectory(at: editorPath, withIntermediateDirectories: true)

        let service = PluginStoreService(
            storePath: tempRoot.appendingPathComponent("store").path,
            userDefaults: defaults
        )

        let plugin = Plugin(
            publisherId: "ms",
            extensionId: "sample",
            displayName: "Sample",
            description: "Sample",
            installedPath: source.path
        )
        let editor = Editor(type: .vscode, extensionsPath: editorPath.path)

        let linkPath = try await service.linkPlugin(plugin, to: editor)
        let destination = try FileManager.default.destinationOfSymbolicLink(atPath: linkPath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: linkPath))
        XCTAssertTrue(destination.contains("/objects/sha256/"))
    }

    func testIsPluginLinkedDetectsHardLinkedTreeWhenSymlinkDisabled() async throws {
        defaults.set(false, forKey: "enableSymlinks")

        let source = tempRoot.appendingPathComponent("source-hardlink", isDirectory: true)
        let editorPath = tempRoot.appendingPathComponent("editor-hardlink/extensions", isDirectory: true)
        try createPluginFixture(at: source, content: "hardlink-me")
        try FileManager.default.createDirectory(at: editorPath, withIntermediateDirectories: true)

        let service = PluginStoreService(
            storePath: tempRoot.appendingPathComponent("store").path,
            userDefaults: defaults
        )

        let plugin = Plugin(
            publisherId: "ms",
            extensionId: "hardlink",
            displayName: "Hardlink",
            description: "Hardlink",
            installedPath: source.path
        )
        let storedPlugin = try await service.addPlugin(plugin, from: source.path)
        let editor = Editor(type: .vscode, extensionsPath: editorPath.path)

        _ = try await service.linkPlugin(storedPlugin, to: editor)

        XCTAssertTrue(service.isPluginLinked(storedPlugin, to: editor))
    }

    func testGarbageCollectStoreRemovesUnreferencedObject() async throws {
        let source = tempRoot.appendingPathComponent("source-gc-remove", isDirectory: true)
        try createPluginFixture(at: source, content: "gc-remove")

        let service = PluginStoreService(
            storePath: tempRoot.appendingPathComponent("store").path,
            userDefaults: defaults
        )

        let casPath = try await service.ensureStoredCopy(from: source.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: casPath))

        let removed = try service.garbageCollectStore()

        XCTAssertEqual(removed, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: casPath))
    }

    func testGarbageCollectStoreKeepsReferencedObject() async throws {
        let source = tempRoot.appendingPathComponent("source-gc-keep", isDirectory: true)
        try createPluginFixture(at: source, content: "gc-keep")

        let service = PluginStoreService(
            storePath: tempRoot.appendingPathComponent("store").path,
            userDefaults: defaults
        )

        let plugin = Plugin(
            publisherId: "ms",
            extensionId: "keep",
            displayName: "Keep",
            description: "Keep",
            installedPath: source.path
        )
        let storedPlugin = try await service.addPlugin(plugin, from: source.path)
        let storePath = try XCTUnwrap(storedPlugin.storePath)

        let removed = try service.garbageCollectStore()

        XCTAssertEqual(removed, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storePath))
    }

    func testRemovePluginDoesNotDeleteSharedCASObject() async throws {
        let sourceA = tempRoot.appendingPathComponent("source-remove-a", isDirectory: true)
        let sourceB = tempRoot.appendingPathComponent("source-remove-b", isDirectory: true)
        try createPluginFixture(at: sourceA, content: "shared-object")
        try createPluginFixture(at: sourceB, content: "shared-object")

        let service = PluginStoreService(
            storePath: tempRoot.appendingPathComponent("store").path,
            userDefaults: defaults
        )

        let pluginA = Plugin(
            publisherId: "ms",
            extensionId: "remove-a",
            displayName: "A",
            description: "A",
            installedPath: sourceA.path
        )
        let pluginB = Plugin(
            publisherId: "ms",
            extensionId: "remove-b",
            displayName: "B",
            description: "B",
            installedPath: sourceB.path
        )

        let storedA = try await service.addPlugin(pluginA, from: sourceA.path)
        let storedB = try await service.addPlugin(pluginB, from: sourceB.path)
        let sharedPath = try XCTUnwrap(storedA.storePath)
        XCTAssertEqual(sharedPath, storedB.storePath)

        try service.removePlugin(storedA)

        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedPath))
    }

    private func createPluginFixture(at root: URL, content: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try "manifest".write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let nested = root.appendingPathComponent("dist", isDirectory: true)
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        try content.write(to: nested.appendingPathComponent("index.js"), atomically: true, encoding: .utf8)
    }
}
