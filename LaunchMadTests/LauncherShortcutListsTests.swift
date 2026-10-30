import Foundation
import XCTest

final class LauncherShortcutListsTests: XCTestCase {
    private let safari = "/Applications/Safari.app"
    private let notes = "/System/Applications/Notes.app"
    private let mail = "/System/Applications/Mail.app"

    // MARK: - Pinned

    func testPinAppendsInUserOrderAndIgnoresDuplicates() {
        var list = PinnedAppList()
        XCTAssertTrue(list.pin(safari))
        XCTAssertTrue(list.pin(notes))
        XCTAssertFalse(list.pin(safari))
        XCTAssertFalse(list.pin("  "))
        XCTAssertEqual(list.paths, [safari, notes])
    }

    func testUnpinRemovesOnlyThatApp() {
        var list = PinnedAppList(paths: [safari, notes, mail])
        XCTAssertTrue(list.unpin(notes))
        XCTAssertFalse(list.unpin(notes))
        XCTAssertEqual(list.paths, [safari, mail])
    }

    func testMoveReordersAndClamps() {
        var list = PinnedAppList(paths: [safari, notes, mail])
        XCTAssertTrue(list.move(mail, by: -1))
        XCTAssertEqual(list.paths, [safari, mail, notes])
        XCTAssertTrue(list.move(notes, to: -5))
        XCTAssertEqual(list.paths, [notes, safari, mail])
        XCTAssertFalse(list.move(notes, by: -1))
        XCTAssertFalse(list.canMove(notes, by: -1))
        XCTAssertTrue(list.canMove(notes, by: 1))
        XCTAssertFalse(list.canMove(mail, by: 1))
    }

    func testPinnedInitSanitizesAndCaps() {
        let many = (0..<(PinnedAppList.maximumCount + 5)).map { "/Applications/App\($0).app" }
        let list = PinnedAppList(paths: [safari, "", safari] + many)
        XCTAssertEqual(list.paths.first, safari)
        XCTAssertEqual(list.paths.count, PinnedAppList.maximumCount)
        XCTAssertEqual(Set(list.paths).count, list.paths.count)

        var full = list
        XCTAssertFalse(full.pin("/Applications/Extra.app"))
    }

    // MARK: - Last used

    func testRecentIsNewestFirstAndDeduplicated() {
        var list = RecentAppList()
        list.recordSuccessfulLaunch(safari)
        list.recordSuccessfulLaunch(notes)
        list.recordSuccessfulLaunch(safari)
        XCTAssertEqual(list.paths, [safari, notes])
    }

    func testRecentIsBounded() {
        var list = RecentAppList(limit: 3)
        for index in 0..<10 {
            list.recordSuccessfulLaunch("/Applications/App\(index).app")
        }
        XCTAssertEqual(list.paths, ["/Applications/App9.app", "/Applications/App8.app", "/Applications/App7.app"])
    }

    func testRecentClearAndRemove() {
        var list = RecentAppList(paths: [safari, notes, mail])
        XCTAssertTrue(list.remove(notes))
        XCTAssertEqual(list.paths, [safari, mail])
        list.clear()
        XCTAssertTrue(list.isEmpty)
    }

    func testRecentPrunesMissingApps() {
        var list = RecentAppList(paths: [safari, notes, mail])
        XCTAssertTrue(list.removeAll { $0 == notes })
        XCTAssertEqual(list.paths, [safari, mail])
        XCTAssertFalse(list.removeAll { _ in false })
    }

    func testRecentIgnoresEmptyPaths() {
        var list = RecentAppList()
        list.recordSuccessfulLaunch("")
        XCTAssertTrue(list.isEmpty)
    }

    // MARK: - Resolution

    func testResolveSkipsMissingAppsAndKeepsOrder() {
        let installed: [String: String] = [safari: "Safari", mail: "Mail"]
        let resolved = LauncherShortcutPaths.resolve([mail, notes, safari]) { installed[$0] }
        XCTAssertEqual(resolved, ["Mail", "Safari"])
    }

    // MARK: - Drag payload

    func testPinnedDragPayloadRoundTripsAndRejectsForeignText() {
        XCTAssertEqual(PinnedAppDragPayload.decode(PinnedAppDragPayload.encode(safari)), safari)
        XCTAssertNil(PinnedAppDragPayload.decode(safari))
        XCTAssertNil(PinnedAppDragPayload.decode("hello"))
        XCTAssertNil(PinnedAppDragPayload.decode(PinnedAppDragPayload.prefix))
    }

    // MARK: - Persistence

    func testStoreRoundTripsOnlyPaths() throws {
        let suiteName = "LauncherShortcutListsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LauncherShortcutStore(defaults: defaults, recentLimit: 4)
        var pinned = store.loadPinned()
        pinned.pin(notes)
        pinned.pin(safari)
        store.savePinned(pinned)

        var recent = store.loadRecent()
        recent.recordSuccessfulLaunch(mail)
        store.saveRecent(recent)

        XCTAssertEqual(store.loadPinned().paths, [notes, safari])
        XCTAssertEqual(store.loadRecent().paths, [mail])
        XCTAssertEqual(defaults.stringArray(forKey: LauncherShortcutStore.recentKey), [mail])

        store.saveRecent(RecentAppList())
        XCTAssertNil(defaults.object(forKey: LauncherShortcutStore.recentKey))
        store.savePinned(PinnedAppList())
        XCTAssertNil(defaults.object(forKey: LauncherShortcutStore.pinnedKey))
    }

    func testStoreToleratesCorruptValues() throws {
        let suiteName = "LauncherShortcutListsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(42, forKey: LauncherShortcutStore.pinnedKey)
        defaults.set([safari, safari, ""], forKey: LauncherShortcutStore.recentKey)

        let store = LauncherShortcutStore(defaults: defaults)
        XCTAssertTrue(store.loadPinned().isEmpty)
        XCTAssertEqual(store.loadRecent().paths, [safari])
    }
}
