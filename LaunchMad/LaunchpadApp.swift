import SwiftUI
import AppKit
import SwiftData
import Combine
import QuartzCore
import Carbon
import Carbon.HIToolbox

extension Notification.Name {
    static let launchpadWindowShown = Notification.Name("LaunchpadWindowShown")
    static let launchpadWindowHidden = Notification.Name("LaunchpadWindowHidden")
}

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@main
struct LaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings {} }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSGestureRecognizerDelegate {
    static var shared: AppDelegate?

    private var window: NSWindow?
    // Settings sheets can become key; background geometry belongs to this window.
    var launchpadWindow: NSWindow? { window }
    private let minimumContentSize = NSSize(width: 800, height: 600)
    private var lastShowAt: Date?
    private var cancellables = Set<AnyCancellable>()
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?
    private let launchpadHotKeySignature = fourCharCode("LNXK")
    
    let appStore: AppStore
    var modelContainer: ModelContainer?
    private var didConfigureModelContext = false
    private var isTerminating = false
    private var windowIsVisible = false
    private var isAnimatingWindow = false
    private var pendingShow = false
    private var pendingHide = false
    private var isPerformingExternalSystemDrag = false
    private var activeModalDialogCount = 0
    private var hotCornerMonitor: HotCornerMonitor?
    // Experimental low-level gesture monitor.
    // Remove this property if gesture support is dropped together with
    // bindGesturePreference()/updateGestureMonitor()/handleGestureTrigger().
    private var gestureMonitor: GestureMonitor?
    // Wake recovery work items for the experimental gesture monitor.
    // If gesture support is removed later, delete this together with
    // bindGestureWakeRecovery()/scheduleGestureWakeRecovery().
    private var gestureWakeRecoveryWorkItems: [DispatchWorkItem] = []

    override init() {
        // Preferences from older installations (LaunchNext) are left untouched;
        // LaunchMad starts with its own defaults domain and data folder.
        appStore = AppStore()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isTerminating else { return }

        Self.shared = self

        appStore.syncGlobalHotKeyRegistration()

        SoundManager.shared.bind(appStore: appStore)
        VoiceManager.shared.bind(appStore: appStore)

        let launchedAtLogin = wasLaunchedAsLoginItem()
        let shouldSilentlyLaunch = launchedAtLogin && appStore.isStartOnLogin

        setupWindow(showImmediately: !shouldSilentlyLaunch)
        appStore.performInitialScanIfNeeded()
        appStore.startAutoRescan()

        bindAppearancePreference()
        bindControllerPreference()
        bindControllerMenuToggle()
        bindSystemUIVisibility()
        bindHotCornerPreference()
        // Experimental gesture wiring entry point.
        // Remove this call if the gesture feature is removed later.
        bindGesturePreference()
        // Experimental wake recovery for low-level gesture input.
        // Remove this call if gesture support is removed later.
        bindGestureWakeRecovery()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyAppearancePreference(self.appStore.appearancePreference)
            self.updateSystemUIVisibility()
        }

        if appStore.isFullscreenMode { updateWindowMode(isFullscreen: true) }
    }

    private func configureModelLayerIfNeeded() {
        if modelContainer == nil {
            modelContainer = makePreferredModelContainer() ?? makeFallbackModelContainer()
        }

        guard !didConfigureModelContext, let container = modelContainer else { return }
        appStore.configure(modelContext: container.mainContext)
        didConfigureModelContext = true
    }

    private func makePreferredModelContainer() -> ModelContainer? {
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let storeDir = appSupport.appendingPathComponent(AppStore.supportFolderName, isDirectory: true)
            try BackupFiles.makePrivateDirectory(storeDir)
            let storeURL = storeDir.appendingPathComponent(BackupFiles.storeFileName)
            let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            return try ModelContainer(for: TopItemData.self, PageEntryData.self, configurations: configuration)
        } catch {
            return nil
        }
    }

    private func makeFallbackModelContainer() -> ModelContainer? {
        // Keep the layout in memory for this session rather than writing to an
        // unexpected location when the support folder cannot be used.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try? ModelContainer(for: TopItemData.self, PageEntryData.self, configurations: configuration)
    }

    private func bindHotCornerPreference() {
        Publishers.CombineLatest4(
            appStore.$hotCornerEnabled.removeDuplicates(),
            appStore.$hotCornerPosition.removeDuplicates(),
            appStore.$hotCornerTriggerDelay.removeDuplicates(),
            appStore.$hotCornerHitboxSize.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] enabled, position, delay, hitboxSize in
            self?.updateHotCornerMonitor(
                enabled: enabled,
                position: position,
                triggerDelay: delay,
                hitboxSize: hitboxSize
            )
        }
        .store(in: &cancellables)
    }

    private func bindGesturePreference() {
        // Experimental gesture settings are funneled through one Combine pipeline
        // so the monitor can be rebuilt from a single source of truth.
        // If gesture support is removed later, delete this binder together with
        // updateGestureMonitor()/handleGestureTrigger() and the Gesture folder.
        Publishers.CombineLatest(
            Publishers.CombineLatest4(
                appStore.$gestureEnabled.removeDuplicates(),
                appStore.$gestureCloseOnPinchOut.removeDuplicates(),
                appStore.$gestureTapAction.removeDuplicates(),
                appStore.$gestureFingerCount.removeDuplicates()
            ),
            Publishers.CombineLatest(
                appStore.$gestureDeviceSelectionMode.removeDuplicates(),
                appStore.$gestureSelectedDeviceIDs.removeDuplicates()
            )
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] combined, deviceSelection in
            let (enabled, closeOnPinchOut, tapAction, fingerCount) = combined
            let (deviceSelectionMode, selectedDeviceIDs) = deviceSelection
            self?.updateGestureMonitor(
                enabled: enabled,
                closeOnPinchOut: closeOnPinchOut,
                tapAction: tapAction,
                fingerCount: fingerCount,
                deviceSelectionMode: deviceSelectionMode,
                selectedDeviceIDs: selectedDeviceIDs
            )
        }
        .store(in: &cancellables)
    }

    // Rebuilds the experimental gesture listener after sleep/wake.
    // The low-level multitouch listener can become stale after wake even when
    // its local "isListening" flag still looks healthy. If gesture support is
    // removed later, delete this binder together with schedule/cancel helpers.
    private func bindGestureWakeRecovery() {
        let center = NSWorkspace.shared.notificationCenter

        center.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.cancelGestureWakeRecovery()
            }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleGestureWakeRecovery()
            }
            .store(in: &cancellables)
    }

    private func scheduleGestureWakeRecovery() {
        guard appStore.gestureEnabled || appStore.gestureTapAction != .off else { return }
        guard !isTerminating else { return }

        cancelGestureWakeRecovery()

        // Rebuild twice: once after the initial wake settles, then again as a
        // fallback for longer sleep/wake paths where the trackpad comes back
        // later than NSWorkspaceDidWakeNotification.
        for delay in [0.8, 2.0] {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard !self.isTerminating else { return }
                guard self.appStore.gestureEnabled || self.appStore.gestureTapAction != .off else { return }
                self.appStore.refreshGestureDeviceInventory()
                self.gestureMonitor?.restart()
            }
            gestureWakeRecoveryWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    private func cancelGestureWakeRecovery() {
        gestureWakeRecoveryWorkItems.forEach { $0.cancel() }
        gestureWakeRecoveryWorkItems.removeAll()
    }

    private func updateHotCornerMonitor(enabled: Bool,
                                        position: AppStore.HotCornerPosition,
                                        triggerDelay: Double,
                                        hitboxSize: Double) {
        let configuration = HotCornerMonitor.Configuration(
            isEnabled: enabled,
            position: position,
            triggerDelay: triggerDelay,
            hitboxSize: CGFloat(hitboxSize)
        )

        if hotCornerMonitor == nil {
            hotCornerMonitor = HotCornerMonitor(configuration: configuration) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleHotCornerTrigger()
                }
            }
        }

        hotCornerMonitor?.update(configuration: configuration)
    }

    private func handleHotCornerTrigger() {
        guard !isTerminating else { return }
        guard !appStore.isSetting else { return }
        guard !isPerformingExternalSystemDrag else { return }
        guard !isAnimatingWindow else { return }

        if windowIsVisible {
            guard appStore.hotCornerToggleWhenOpen else { return }
            hideWindow()
            return
        }

        showWindow()
    }

    // Bridges Settings state into the experimental gesture monitor.
    // If gesture support needs to be removed later, this is one of the main seams:
    // delete LaunchNext/Gesture/, remove the Gesture settings/AppStore fields,
    // then remove this method together with bindGesturePreference().
    private func updateGestureMonitor(enabled: Bool,
                                      closeOnPinchOut: Bool,
                                      tapAction: AppStore.GestureTapAction,
                                      fingerCount: AppStore.GestureFingerCount,
                                      deviceSelectionMode: GestureDeviceSelectionMode,
                                      selectedDeviceIDs: [String]) {
        let configuration = GestureMonitor.Configuration(
            isEnabled: enabled || tapAction != .off,
            closeOnPinchOutEnabled: closeOnPinchOut,
            tapEnabled: tapAction != .off,
            tapTogglesWindow: tapAction == .toggle,
            deviceSelectionMode: deviceSelectionMode,
            selectedDeviceIDs: selectedDeviceIDs,
            requiredFingerCount: fingerCount.rawValue,
            minimumOpenParticipatingFingerCount: fingerCount.minimumOpenParticipatingFingerCount
        )

        if gestureMonitor == nil {
            gestureMonitor = GestureMonitor(configuration: configuration) { [weak self] action in
                DispatchQueue.main.async {
                    self?.handleGestureTrigger(action: action)
                }
            }
        }

        gestureMonitor?.update(configuration: configuration)
    }

    // Maps recognized gesture actions onto the existing window flow.
    // Keeping the behavior translation here avoids spreading experimental gesture
    // branches into showWindow()/hideWindow() and makes later rollback simple:
    // remove this handler and the gesture monitor callback wiring.
    private func handleGestureTrigger(action: GestureTriggerAction) {
        guard !isTerminating else { return }
        guard !isPerformingExternalSystemDrag else { return }
        guard !isAnimatingWindow else { return }

        switch action {
        case .open:
            guard !windowIsVisible else { return }
            showWindow()
        case .close:
            guard windowIsVisible else { return }
            hideWindow()
        case .toggle:
            if windowIsVisible {
                hideWindow()
            } else {
                showWindow()
            }
        }
    }

    // MARK: - Global Hotkey

    func updateGlobalHotKey(configuration: AppStore.HotKeyConfiguration?) {
        unregisterGlobalHotKey()
        guard let configuration else { return }
        registerGlobalHotKey(configuration)
    }


    private func registerGlobalHotKey(_ configuration: AppStore.HotKeyConfiguration) {
        ensureHotKeyEventHandler()
        let hotKeyID = EventHotKeyID(signature: launchpadHotKeySignature, id: 1)
        let status = RegisterEventHotKey(configuration.keyCodeUInt32,
                                         configuration.carbonModifierFlags,
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &hotKeyRef)
        if status != noErr {
            hotKeyRef = nil
        }
    }


    private func unregisterGlobalHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        cleanUpHotKeyEventHandlerIfNeeded()
    }


    private func cleanUpHotKeyEventHandlerIfNeeded() {
        if hotKeyRef == nil, let handler = hotKeyEventHandler {
            RemoveEventHandler(handler)
            hotKeyEventHandler = nil
        }
    }

    private func ensureHotKeyEventHandler() {
        guard hotKeyEventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        _ = InstallEventHandler(GetEventDispatcherTarget(), hotKeyEventCallback, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &hotKeyEventHandler)
    }

    fileprivate func handleHotKeyEvent(signature: OSType, id: UInt32) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch (signature, id) {
            case (self.launchpadHotKeySignature, 1):
                self.toggleWindow()
            default:
                break
            }
        }
    }

    private func setupWindow(showImmediately: Bool = true) {
        guard let screen = NSScreen.main else { return }
        let rect = calculateContentRect(for: screen)
        
        window = BorderlessWindow(contentRect: rect, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        window?.delegate = self
        window?.isMovable = false
        window?.level = .floating
        window?.collectionBehavior = [.transient, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.contentAspectRatio = NSSize(width: 4, height: 3)
        if let window { updateMinimumWindowSize(window, for: screen) }
        
        configureModelLayerIfNeeded()
        if let container = modelContainer {
            window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore).modelContainer(container))
        } else {
            window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore))
        }
        
        applyCornerRadius()
        window?.alphaValue = 0
        window?.contentView?.alphaValue = 0
        windowIsVisible = false

        // 初始化完成后执行首个淡入
        if showImmediately {
            showWindow()
        }

        // 背景点击关闭逻辑改为 SwiftUI 内部实现，避免与输入控件冲突
    }

    private func bindAppearancePreference() {
        appStore.$appearancePreference
            .receive(on: RunLoop.main)
            .sink { [weak self] preference in
                DispatchQueue.main.async {
                    self?.applyAppearancePreference(preference)
                }
            }
            .store(in: &cancellables)
    }

    

    private func bindControllerPreference() {
        appStore.$gameControllerEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { enabled in
                if enabled {
                    ControllerInputManager.shared.start()
                } else {
                    ControllerInputManager.shared.stop()
                }
            }
            .store(in: &cancellables)
    }

    private func bindControllerMenuToggle() {
        ControllerInputManager.shared.commands
            .receive(on: RunLoop.main)
            .sink { [weak self] command in
                guard let self else { return }
                guard case .menu = command else { return }
                guard self.appStore.gameControllerEnabled else { return }

                if self.appStore.gameControllerMenuTogglesLaunchpad {
                    self.toggleWindow()
                } else if self.windowIsVisible {
                    self.hideWindow()
                }
            }
            .store(in: &cancellables)
    }

    private func bindSystemUIVisibility() {
        Publishers.CombineLatest3(
            appStore.$hideDock.removeDuplicates(),
            appStore.$hideMenuBar.removeDuplicates(),
            appStore.$isFullscreenMode.removeDuplicates()
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateSystemUIVisibility()
            }
            .store(in: &cancellables)
    }

    func updateSystemUIVisibility() {
        let shouldHideDock = appStore.hideDock && windowIsVisible
        let shouldHideMenuBar = appStore.hideMenuBar && appStore.isFullscreenMode && windowIsVisible
        var options: NSApplication.PresentationOptions = []
        if shouldHideMenuBar {
            options.insert(.hideDock)
            options.insert(.hideMenuBar)
        } else if shouldHideDock {
            options.insert(.autoHideDock)
        }
        if options != NSApp.presentationOptions {
            NSApp.presentationOptions = options
        }
        updateWindowLevelForSystemUI()
    }

    private func updateWindowLevelForSystemUI() {
        guard let window else { return }
        let shouldCoverMenuBar = appStore.hideMenuBar && appStore.isFullscreenMode && windowIsVisible
            && activeModalDialogCount == 0
        let targetLevel: NSWindow.Level = shouldCoverMenuBar
            ? NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            : .floating
        if window.level != targetLevel {
            window.level = targetLevel
        }
    }

    /// AppKit resets standalone modal panels to its modal level. Keep the
    /// launcher and its settings sheet below them without changing system UI
    /// visibility, then restore the level required by the current preferences.
    @discardableResult
    static func withModalDialog<Result>(_ present: () -> Result) -> Result {
        guard let delegate = shared else { return present() }
        delegate.activeModalDialogCount += 1
        delegate.updateWindowLevelForSystemUI()
        defer {
            delegate.activeModalDialogCount -= 1
            delegate.updateWindowLevelForSystemUI()
        }
        return present()
    }

    private func wasLaunchedAsLoginItem() -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        guard event.eventID == kAEOpenApplication else { return false }
        guard let descriptor = event.paramDescriptor(forKeyword: keyAEPropData) else { return false }
        return descriptor.enumCodeValue == keyAELaunchedAsLogInItem
    }

    private func applyAppearancePreference(_ preference: AppearancePreference) {
        let appearance = preference.nsAppearance.flatMap { NSAppearance(named: $0) }
        window?.appearance = appearance
        NSApp.appearance = appearance
    }

    func presentLaunchError(_ error: Error, for url: URL) { }
    
    func showWindow() {
        pendingShow = true
        pendingHide = false
        startPendingWindowTransition()
    }
    
    func hideWindow() {
        pendingHide = true
        pendingShow = false
        startPendingWindowTransition()
    }

    func beginExternalSystemDragSession() {
        isPerformingExternalSystemDrag = true
    }

    func endExternalSystemDragSession() {
        guard isPerformingExternalSystemDrag else { return }
        isPerformingExternalSystemDrag = false
        guard windowIsVisible, !appStore.isSetting, let window else { return }
        guard !window.isKeyWindow && !window.isMainWindow else { return }
        hideWindow()
    }

    func toggleWindow() {
        if windowIsVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    // MARK: - Quit with fade
    func quitWithFade() {
        guard !isTerminating else { NSApp.terminate(nil); return }
        isTerminating = true
        if let window = window {
            pendingShow = false
            pendingHide = false
            animateWindow(to: 0, resumePending: false) {
                window.orderOut(nil)
                window.alphaValue = 1
                window.contentView?.alphaValue = 1
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateNow }
        quitWithFade()
        return .terminateLater
    }

    deinit {
        unregisterGlobalHotKey()
    }
    
    func updateWindowMode(isFullscreen: Bool) {
        guard let window = window else { return }
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        updateMinimumWindowSize(window, for: screen)
        window.contentAspectRatio = isFullscreen ? NSSize(width: 0, height: 0) : NSSize(width: 4, height: 3)
        window.setFrame(isFullscreen ? screen.frame : calculateContentRect(for: screen), display: true)
        applyCornerRadius()
    }
    
    func updateWindowShadow() {
        guard let window else { return }
        let enabled = !appStore.isFullscreenMode && appStore.windowShadowEnabled
        if window.hasShadow != enabled { window.hasShadow = enabled }
    }

    private func applyCornerRadius() {
        updateWindowShadow()
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = appStore.isFullscreenMode ? 0 : 30
        contentView.layer?.masksToBounds = true
    }
    
    private func calculateContentRect(for screen: NSScreen) -> NSRect {
        CompactWindowLayout.frame(in: screen.visibleFrame, minimum: minimumContentSize,
                                  maximumWidth: appStore.compactWindowMaxWidth,
                                  maximumHeight: appStore.compactWindowMaxHeight)
    }

    private func updateMinimumWindowSize(_ window: NSWindow, for screen: NSScreen) {
        let size = CompactWindowLayout.minimumSize(in: screen.visibleFrame, preferred: minimumContentSize)
        window.contentMinSize = size
        window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
    }
    
    private func getCurrentActiveScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }

    // MARK: - Window animation helpers

    private func startPendingWindowTransition() {
        guard !isAnimatingWindow else { return }
        if pendingShow {
            performShowWindow()
        } else if pendingHide {
            performHideWindow()
        }
    }

    private func performShowWindow() {
        pendingShow = false
        guard let window = window else { return }

        if windowIsVisible && !isAnimatingWindow && window.alphaValue >= 0.99 {
            return
        }

        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        let rect = appStore.isFullscreenMode ? screen.frame : calculateContentRect(for: screen)
        updateMinimumWindowSize(window, for: screen)
        window.setFrame(rect, display: true)
        applyCornerRadius()

        if window.alphaValue <= 0.01 || !windowIsVisible {
            window.alphaValue = 0
            window.contentView?.alphaValue = 0
        }

        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [.transient, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        window.orderFrontRegardless()
        
        // Force window to become key and main window for proper focus
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        window.makeMain()

        lastShowAt = Date()
        windowIsVisible = true
        updateSystemUIVisibility()
        appStore.reconcileApplicationsOnWindowShow()
        SoundManager.shared.play(.launchpadOpen)
        NotificationCenter.default.post(name: .launchpadWindowShown, object: nil)

        let finalizeShow: () -> Void = {
            self.windowIsVisible = true
            self.updateSystemUIVisibility()
            // Ensure focus after animation completes
            DispatchQueue.main.async {
                self.window?.makeKey()
                self.window?.makeMain()
            }
        }

        if appStore.enableWindowOpenAnimation {
            animateWindow(to: 1) {
                finalizeShow()
            }
        } else {
            window.alphaValue = 1
            window.contentView?.alphaValue = 1
            finalizeShow()
        }
    }

    private func performHideWindow() {
        pendingHide = false
        guard let window = window else { return }

        let shouldPlaySound = windowIsVisible && !isTerminating

        let finalize: () -> Void = {
            self.windowIsVisible = false
            self.updateSystemUIVisibility()
            window.orderOut(nil)
            window.alphaValue = 1
            window.contentView?.alphaValue = 1
            self.appStore.isSetting = false
            if self.appStore.rememberLastPage {
                self.appStore.persistCurrentPageIfNeeded()
            } else {
                self.appStore.currentPage = 0
            }
            self.appStore.searchText = ""
            self.appStore.openFolder = nil
            self.appStore.saveAllOrder()
            NotificationCenter.default.post(name: .launchpadWindowHidden, object: nil)
        }

        if (!windowIsVisible && window.alphaValue <= 0.01) || isTerminating {
            if shouldPlaySound {
                SoundManager.shared.play(.launchpadClose)
            }
            finalize()
            return
        }

        if shouldPlaySound {
            SoundManager.shared.play(.launchpadClose)
        }

        if appStore.enableWindowOpenAnimation {
            animateWindow(to: 0) {
                finalize()
            }
        } else {
            finalize()
        }
    }

    private func animateWindow(to targetAlpha: CGFloat, resumePending: Bool = true, completion: (() -> Void)? = nil) {
        guard let window = window else {
            completion?()
            return
        }

        isAnimatingWindow = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = appStore.windowAnimationDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = targetAlpha
            window.contentView?.animator().alphaValue = targetAlpha
        }, completionHandler: {
            window.alphaValue = targetAlpha
            window.contentView?.alphaValue = targetAlpha
            self.isAnimatingWindow = false
            completion?()
            if resumePending {
                self.startPendingWindowTransition()
            }
        })
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minSize = sender.contentMinSize
        let contentSize = sender.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
        let clamped = NSSize(width: max(contentSize.width, minSize.width), height: max(contentSize.height, minSize.height))
        return sender.frameRect(forContentRect: NSRect(origin: .zero, size: clamped)).size
    }
    
    func windowDidResignKey(_ notification: Notification) { autoHideIfNeeded() }
    func windowDidResignMain(_ notification: Notification) { autoHideIfNeeded() }
    private func autoHideIfNeeded() {
        guard !isPerformingExternalSystemDrag else { return }
        guard !appStore.isSetting else { return }
        hideWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if isAnimatingWindow {
            // Dock activation can overlap auto-hide. isVisible remains true
            // until orderOut, so treating this as a toggle would queue another
            // hide. Queue a show instead; during fade-in it simply coalesces
            // with the current show and cancels any pending hide.
            showWindow()
        } else if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        ControllerInputManager.shared.stop()
    }
    
    private func isInteractiveView(_ view: NSView?) -> Bool {
        var v = view
        while let cur = v {
            if cur is NSControl || cur is NSTextView || cur is NSScrollView || cur is NSVisualEffectView { return true }
            v = cur.superview
        }
        return false
    }

    @objc private func handleBackgroundClick(_ sender: NSClickGestureRecognizer) {
        guard appStore.openFolder == nil && !appStore.isFolderNameEditing else { return }
        guard let view = sender.view else { return }
        let p = sender.location(in: view)
        if let hit = view.hitTest(p), isInteractiveView(hit) { return }
        hideWindow()
    }

    // MARK: - NSGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        guard let contentView = window?.contentView else { return true }
        let point = contentView.convert(event.locationInWindow, from: nil)
        if let hit = contentView.hitTest(point), isInteractiveView(hit) {
            return false
        }
        return true
    }
}

private func hotKeyEventCallback(eventHandlerCallRef: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData, let event else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &hotKeyID)
    if status != noErr {
        return status
    }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    delegate.handleHotKeyEvent(signature: hotKeyID.signature, id: hotKeyID.id)
    return noErr
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var result: UInt32 = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) | (scalar.value & 0xFF)
    }
    return result
}
