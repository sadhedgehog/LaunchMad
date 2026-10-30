import AppKit
import AVFoundation
import Combine
import CoreGraphics
import ImageIO
import LaunchMadWallpaperCore
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class BackgroundImageController: ObservableObject {
    enum RefreshReason {
        case windowShown
        case contextChanged
        case contextChecked
        case settingsChanged
        case viewportChanged
    }

    struct Content {
        let image: CGImage
        let wallpaperIdentity: WallpaperIdentity?
        let labelSample: BackgroundLabelContrast?

        private init(image: CGImage, wallpaperIdentity: WallpaperIdentity?, labelSample: BackgroundLabelContrast?) {
            self.image = image
            self.wallpaperIdentity = wallpaperIdentity
            self.labelSample = labelSample
        }

        static func prepare(image: CGImage, wallpaperIdentity: WallpaperIdentity? = nil) async -> Content {
            // Publish the image and its contrast sample together. Cached Content
            // keeps both, so reopening never briefly falls back to appearance colors.
            let sample = await Task.detached(priority: .userInitiated) {
                BackgroundLabelContrast.make(image: image)
            }.value
            return Content(image: image, wallpaperIdentity: wallpaperIdentity, labelSample: sample)
        }
    }

    private enum CacheKey: Equatable {
        case custom(path: String, fileSize: Int, modificationTime: TimeInterval, targetMaxDimension: Int)
    }

    private enum RequestIdentity: Equatable {
        case desktop(displayID: CGDirectDisplayID)
        case preview(displayID: CGDirectDisplayID, isDark: Bool, isPortrait: Bool)
        case custom(path: String)
    }

    private struct ResolvedWallpaper: Sendable {
        let exactIdentity: WallpaperIdentity?
        let verifiedStaticURL: URL?
        let contextVersion: String?
        let contextComponents: [String: String]
        let captureIdentity: WallpaperIdentity?
        let appearanceOnly: Bool

        var supportsCaptureReuse: Bool {
            captureIdentity.map { WallpaperFrameStability.supportsReuse(for: $0, appearanceOnly: appearanceOnly) } ?? false
        }

        nonisolated init(resolution: WallpaperIdentityResolution, verifiedStaticURL: URL?, contextVersion: String? = nil,
                         contextComponents: [String: String] = [:], captureFallbackIdentity: WallpaperIdentity? = nil,
                         appearanceOnly: Bool = false, systemIsDark: Bool = false) {
            self.appearanceOnly = appearanceOnly
            // System appearance, not LaunchNext's independently selected theme.
            self.contextVersion = WallpaperFrameStability.reuseContextVersion(contextVersion,
                appearanceOnly: appearanceOnly, systemIsDark: systemIsDark)
            self.contextComponents = contextComponents
            guard let identity = resolution.exactIdentity else {
                exactIdentity = nil
                captureIdentity = captureFallbackIdentity
                self.verifiedStaticURL = nil
                return
            }
            // The image provider may itself contain multiple frames (e.g. HEIC).
            // Read metadata once, on the identity resolver's background task.
            if identity.kind == .staticImage, case let .image(url) = identity.source,
               WallpaperImageRenderer.hasMultipleImages(at: url) {
                exactIdentity = WallpaperIdentity(displayUUID: identity.displayUUID, provider: identity.provider,
                    configurationDigest: identity.configurationDigest, kind: .unknown, source: identity.source)
                self.verifiedStaticURL = nil
            } else {
                exactIdentity = identity
                self.verifiedStaticURL = verifiedStaticURL
            }
            captureIdentity = exactIdentity
        }
    }

    private struct StaticLayout: Sendable, Equatable {
        let scaling: WallpaperImageRenderer.Scaling
        let fillColor: CGColor
        let displaySize: CGSize
        let pixelSize: CGSize

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.scaling == rhs.scaling && lhs.fillColor == rhs.fillColor
                && lhs.displaySize == rhs.displaySize && lhs.pixelSize == rhs.pixelSize
        }

        init?(screen: NSScreen) {
            guard let options = NSWorkspace.shared.desktopImageOptions(for: screen) else { return nil }
            let rawScaling = (options[.imageScaling] as? NSNumber)?.uintValue
                ?? NSImageScaling.scaleProportionallyUpOrDown.rawValue
            guard let imageScaling = NSImageScaling(rawValue: rawScaling) else { return nil }
            switch imageScaling {
            case .scaleProportionallyUpOrDown:
                scaling = (options[.allowClipping] as? NSNumber)?.boolValue == true ? .fill : .fit
            case .scaleAxesIndependently: scaling = .stretch
            case .scaleNone: scaling = .center
            default: return nil
            }
            fillColor = ((options[.fillColor] as? NSColor) ?? .black).cgColor
            displaySize = screen.frame.size
            pixelSize = CGSize(width: displaySize.width * screen.backingScaleFactor,
                               height: displaySize.height * screen.backingScaleFactor)
        }

        nonisolated func render(url: URL, maximumPixels: Int = WallpaperImageRenderer.maximumPixelCount) -> CGImage? {
            WallpaperImageRenderer.render(url: url, displaySize: displaySize, pixelSize: pixelSize,
                                          scaling: scaling, fillColor: fillColor, maximumPixels: maximumPixels)
        }
    }

    // Material backgrounds use 0.5 MP; unfiltered backgrounds use a bounded
    // display-sized decode. Each display's warm frame records its own budget.
    private var maximumDecodedPixelCount = WallpaperImageRenderer.maximumPixelCount
    private var usesUnfilteredBackground = false
    private var requestedTargetSize: CGSize?
    @Published private(set) var content: Content?

    private var activeCacheKey: CacheKey?
    private var activeWallpaperIdentity: WallpaperIdentity?
    private var requestIdentity: RequestIdentity?
    private var loadTask: Task<Void, Never>?
    private var pendingContextRefresh: Task<Void, Never>?
    private var latestRequestedDisplayID: CGDirectDisplayID?
    private var lastStaticLayout: StaticLayout?
    private var lastDesktopContextVersion: String?
    private struct CaptureConfiguration: Equatable {
        let identity: WallpaperIdentity?
        let version: String?
    }
    private var captureQuietPeriods: [CGDirectDisplayID: WallpaperCaptureQuietPeriod<CaptureConfiguration>] = [:]
    private var captureNotBefore: TimeInterval = 0
    private var loadGeneration = 0
    private var isWindowVisible = false
    private var desktopContextIsDirty = true
    private var backgroundIsEnabled = true
    // Last frame published for each display. Unfiltered mode keeps the three most
    // recently used displays within a shared decoded-image byte budget.
    // Lets a display switch paint the
    // right wallpaper synchronously instead of showing the previous display's
    // image (or black) for the ~0.5s the capture pipeline needs on a busy
    // main thread. Material-mode frames are <=0.5MP each; cleared when the feature is
    // turned off or the view disappears.
    private var lastDesktopFrameByDisplay: [CGDirectDisplayID: Content] = [:]
    private var desktopFrameBudgets: [CGDirectDisplayID: Int] = [:]
    private var desktopFrameUseOrder: [CGDirectDisplayID] = []

    private struct CaptureContext: Equatable {
        let identity: WallpaperIdentity
        let version: String
        let windowID: CGWindowID
        let frame: CGRect
        let scale: CGFloat
        let maximumPixels: Int

        func hasSameWallpaperAndGeometry(as other: Self) -> Bool {
            identity == other.identity && frame == other.frame && scale == other.scale
                && maximumPixels == other.maximumPixels
        }
    }

    private struct CachedCapture {
        let context: CaptureContext
        let image: CGImage
        let sampledAt: ContinuousClock.Instant
        var settling: WallpaperSettlingState
    }

    private var cachedCaptures: [CGDirectDisplayID: CachedCapture] = [:]
    private var contextMonitor: WallpaperContextMonitor?

    private func desktopContextChanged(force: Bool) {
        // Monitor notifications also arrive while hidden. Release disconnected
        // displays before refresh takes its hidden-window early return.
        pruneDisconnectedDesktopFrames()
        let displayID: CGDirectDisplayID
        let source: AppStore.BackgroundImageSource
        switch requestIdentity {
        case .desktop(let id):
            displayID = id
            source = .desktopWallpaper
        case .preview(let id, _, _):
            displayID = id
            source = .desktopPreview
        default:
            return
        }
        // A screen-change check may still be waiting in the debounce window.
        // A later monitor event must not replace it with the old request's screen.
        let targetDisplayID = latestRequestedDisplayID ?? displayID
        let screen = NSScreen.screens.first { Self.displayID(for: $0) == targetDisplayID }
        refresh(for: screen, enabled: backgroundIsEnabled, source: source,
                customImagePath: "", unfiltered: usesUnfilteredBackground, targetSize: requestedTargetSize, reason: force ? .contextChanged : .contextChecked)
    }

    func refresh(
        for screen: NSScreen?,
        enabled: Bool,
        source: AppStore.BackgroundImageSource,
        customImagePath: String,
        unfiltered: Bool = false,
        targetSize: CGSize? = nil,
        reason: RefreshReason
    ) {
        if reason == .windowShown, isWindowVisible { return }
        latestRequestedDisplayID = screen.flatMap { Self.displayID(for: $0) }
        if reason == .contextChanged {
            desktopContextIsDirty = true
            cachedCaptures.removeAll()
            captureNotBefore = ProcessInfo.processInfo.systemUptime + 2
        }
        if reason == .contextChanged || reason == .contextChecked {
            // Stop work based on the old desktop before coalescing the burst.
            // Preserve candidates for metadata-only checks, including their
            // consecutive stability confirmations after a quick hide/show.
            loadTask?.cancel()
            loadTask = nil
            loadGeneration += 1
            pendingContextRefresh?.cancel()
            pendingContextRefresh = nil
            // Opening always resolves the context again. No hidden-window task
            // is needed, and a force invalidation remains dirty until then.
            guard isWindowVisible else { return }
            pendingContextRefresh = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                guard let self, !Task.isCancelled, self.isWindowVisible else { return }
                self.pendingContextRefresh = nil
                self.refreshNow(for: screen, enabled: enabled, source: source,
                    customImagePath: customImagePath, unfiltered: unfiltered,
                    targetSize: targetSize, reason: .contextChecked)
            }
            return
        }
        // An explicit open or settings change supersedes a delayed check.
        if reason != .viewportChanged {
            pendingContextRefresh?.cancel()
            pendingContextRefresh = nil
        }
        refreshNow(for: screen, enabled: enabled, source: source,
            customImagePath: customImagePath, unfiltered: unfiltered,
            targetSize: targetSize, reason: reason)
    }

    private func refreshNow(
        for screen: NSScreen?, enabled: Bool, source: AppStore.BackgroundImageSource,
        customImagePath: String, unfiltered: Bool, targetSize: CGSize?, reason: RefreshReason
    ) {
        switch reason {
        case .windowShown:
            guard !isWindowVisible else { return }
            isWindowVisible = true
        case .settingsChanged:
            cachedCaptures.removeAll()
        case .contextChanged, .contextChecked, .viewportChanged:
            break
        }

        if enabled, source != .customImage {
            if contextMonitor == nil {
                contextMonitor = WallpaperContextMonitor { [weak self] force in
                    self?.desktopContextChanged(force: force)
                }
            }
        } else {
            contextMonitor = nil
            cachedCaptures.removeAll()
        }

        guard enabled else {
            guard backgroundIsEnabled else { return }
            backgroundIsEnabled = false
            clearContentAndRequest()
            return
        }
        backgroundIsEnabled = true

        guard let screen, let displayID = Self.displayID(for: screen) else {
            clearContentAndRequest()
            return
        }

        pruneDisconnectedDesktopFrames()

        let displayPixels = CGSize(width: screen.frame.width * screen.backingScaleFactor,
                                   height: screen.frame.height * screen.backingScaleFactor)
        let target = targetSize ?? screen.frame.size
        // Preserve enough source pixels for aspect-fill in a compact window.
        let fillScale = min(1, max(target.width / screen.frame.width, target.height / screen.frame.height))
        let neededPixels = CGSize(width: displayPixels.width * fillScale, height: displayPixels.height * fillScale)
        let budget = WallpaperImageRenderer.pixelBudget(for: neededPixels, unfiltered: unfiltered)
        requestedTargetSize = targetSize
        let modeChanged = usesUnfilteredBackground != unfiltered
        let qualityChanged = budget != maximumDecodedPixelCount || modeChanged
        // Resize notifications also occur when showing an unchanged window.
        // They must not restart decoding or wallpaper capture confirmation.
        if reason == .viewportChanged, !qualityChanged { return }
        if qualityChanged {
            pendingContextRefresh?.cancel()
            pendingContextRefresh = nil
            loadTask?.cancel()
            loadTask = nil
            loadGeneration += 1
            activeCacheKey = nil
            activeWallpaperIdentity = nil
            desktopContextIsDirty = true
            content = nil
            if modeChanged {
                lastDesktopFrameByDisplay.removeAll()
                cachedCaptures.removeAll()
                desktopFrameBudgets.removeAll()
                desktopFrameUseOrder.removeAll()
            }
        }
        maximumDecodedPixelCount = budget
        usesUnfilteredBackground = unfiltered
        let staticLayout = StaticLayout(screen: screen)
        if lastStaticLayout != staticLayout {
            // Static-file renders also depend on scaling, fill color and display
            // geometry, even when their wallpaper identity has not changed.
            desktopContextIsDirty = true
            lastStaticLayout = staticLayout
        }
        if let previousBudget = desktopFrameBudgets[displayID], previousBudget != budget {
            lastDesktopFrameByDisplay.removeValue(forKey: displayID)
            cachedCaptures.removeValue(forKey: displayID)
            desktopFrameBudgets.removeValue(forKey: displayID)
            desktopFrameUseOrder.removeAll { $0 == displayID }
        }

        let targetMaxDimension = max(
            1,
            Int(max(
                screen.frame.width * screen.backingScaleFactor,
                screen.frame.height * screen.backingScaleFactor
            ).rounded(.up))
        )

        switch source {
        case .desktopPreview:
            // LaunchNext may force its own appearance; wallpaper follows the system.
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            let isPortrait = screen.frame.height > screen.frame.width
            let request = RequestIdentity.preview(displayID: displayID, isDark: isDark, isPortrait: isPortrait)
            let changed = requestIdentity != request
            prepare(for: request)
            if changed { content = nil }
            guard isWindowVisible, contextMonitor?.isSuspended != true else { return }
            refreshPreview(displayID: displayID, desktopImageURL: NSWorkspace.shared.desktopImageURL(for: screen),
                           layout: staticLayout, isDark: isDark, isPortrait: isPortrait,
                           reason: reason, targetMaxDimension: targetMaxDimension)
        case .desktopWallpaper:
            let identity = RequestIdentity.desktop(displayID: displayID)
            let identityChanged = requestIdentity != identity
            prepare(for: identity)
            if identityChanged, let warmFrame = lastDesktopFrameByDisplay[displayID] {
                // Instant first paint: this display's last known frame goes up
                // synchronously; the capture below replaces it when ready.
                content = warmFrame
            }
            guard isWindowVisible, contextMonitor?.isSuspended != true else { return }
            let desktopImageURL = NSWorkspace.shared.desktopImageURL(for: screen)
            refreshDesktop(
                displayID: displayID,
                desktopImageURL: desktopImageURL,
                staticLayout: staticLayout,
                reason: reason,
                targetMaxDimension: targetMaxDimension
            )
        case .customImage:
            let path = customImagePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                clearContent(for: .custom(path: ""))
                return
            }
            let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
            let identity = RequestIdentity.custom(path: normalizedPath)
            prepare(for: identity)
            guard isWindowVisible else { return }
            refreshCustom(
                path: normalizedPath,
                targetMaxDimension: targetMaxDimension
            )
        }
    }

    func windowDidHide() {
        guard isWindowVisible else { return }
        isWindowVisible = false
        pendingContextRefresh?.cancel()
        pendingContextRefresh = nil
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
    }

    func clear() {
        contextMonitor = nil
        pendingContextRefresh?.cancel()
        pendingContextRefresh = nil
        lastStaticLayout = nil
        lastDesktopContextVersion = nil
        captureQuietPeriods.removeAll()
        captureNotBefore = 0
        latestRequestedDisplayID = nil
        cachedCaptures.removeAll()
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        isWindowVisible = false
        desktopContextIsDirty = true
        requestIdentity = nil
        activeCacheKey = nil
        activeWallpaperIdentity = nil
        lastDesktopFrameByDisplay.removeAll()
        desktopFrameBudgets.removeAll()
        desktopFrameUseOrder.removeAll()
        content = nil
    }

    private func prepare(for identity: RequestIdentity) {
        guard requestIdentity != identity else { return }
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        if case .preview = requestIdentity { content = nil }
        requestIdentity = identity
        activeCacheKey = nil
        activeWallpaperIdentity = nil
        desktopContextIsDirty = true
        // content is deliberately kept: switching display or source used to blank
        // the background here, showing black until the new capture landed. The
        // stale image stays visible while loading. If all attempts fail, only
        // content matching the requested wallpaper may remain visible.
    }

    private func clearContent(for identity: RequestIdentity) {
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        requestIdentity = identity
        activeCacheKey = nil
        activeWallpaperIdentity = nil
        content = nil
    }

    private func clearContentAndRequest() {
        cachedCaptures.removeAll()
        captureQuietPeriods.removeAll()
        captureNotBefore = 0
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        requestIdentity = nil
        activeCacheKey = nil
        activeWallpaperIdentity = nil
        lastDesktopFrameByDisplay.removeAll()
        desktopFrameBudgets.removeAll()
        desktopFrameUseOrder.removeAll()
        desktopContextIsDirty = true
        content = nil
    }

    // Retry delays used when the wallpaper snapshot window is unavailable,
    // e.g. while a video/animated wallpaper is actively playing. The system
    // recreates the snapshot window shortly after the video pauses.
    nonisolated private static let desktopSnapshotRetryDelays: [Duration] = [
        .milliseconds(600), .milliseconds(1200), .milliseconds(2400), .milliseconds(4800)
    ]

    /// File-only preview. Never captures windows or reads/writes the live snapshot cache.
    private func refreshPreview(
        displayID: CGDirectDisplayID, desktopImageURL: URL?, layout: StaticLayout?,
        isDark: Bool, isPortrait: Bool, reason: RefreshReason, targetMaxDimension: Int
    ) {
        let maximumPixels = maximumDecodedPixelCount
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer { if generation == self.loadGeneration { self.loadTask = nil } }
            let identity = await Task.detached(priority: .userInitiated) {
                Self.resolveWallpaperIdentity(displayID: displayID, desktopImageURL: desktopImageURL,
                                              forPreview: true).exactIdentity
            }.value
            guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible else { return }
            guard let identity else {
                self.content = nil
                self.activeWallpaperIdentity = nil
                return
            }
            if case let .image(url) = identity.source { self.contextMonitor?.watchSource(url) }
            else { self.contextMonitor?.watchSource(nil) }
            if (reason == .windowShown || reason == .contextChecked), !self.desktopContextIsDirty,
               self.activeWallpaperIdentity == identity, self.content != nil { return }
            let image = await Task.detached(priority: .userInitiated) { () -> CGImage? in
                switch identity.source {
                case let .image(url):
                    guard let previewURL = WallpaperImageRenderer.previewImageURL(for: url) else { return nil }
                    if let layout, let rendered = layout.render(url: previewURL, maximumPixels: maximumPixels) { return rendered }
                    return Self.decodeCustomImage(at: previewURL, targetMaxDimension: targetMaxDimension, maximumPixels: maximumPixels)
                case let .aerial(assetID):
                    guard let url = WallpaperAerialPreview.localResource(
                        assetID: assetID, isDark: isDark, isPortrait: isPortrait) else { return nil }
                    if url.pathExtension.lowercased() != "mov" {
                        return Self.decodeCustomImage(at: url, targetMaxDimension: targetMaxDimension, maximumPixels: maximumPixels)
                    }
                    guard let frame = await Self.firstVideoFrame(at: url, targetMaxDimension: targetMaxDimension,
                                                                 maximumPixels: maximumPixels) else { return nil }
                    return Self.downsampleCapturedImageIfNeeded(frame, maximumPixels: maximumPixels)
                case .unavailable:
                    return nil
                }
            }.value
            guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible,
                  let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else { return }
            let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
            let current = await Task.detached(priority: .utility) {
                Self.resolveWallpaperIdentity(displayID: displayID, desktopImageURL: currentURL,
                                              forPreview: true).exactIdentity
            }.value
            guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible else { return }
            guard current == identity else {
                self.content = nil
                self.activeWallpaperIdentity = nil
                return
            }
            var prepared: Content?
            if let image { prepared = await Content.prepare(image: image, wallpaperIdentity: identity) }
            guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible else { return }
            self.content = prepared
            self.activeWallpaperIdentity = image == nil ? nil : identity
            self.desktopContextIsDirty = false
        }
    }

    private func refreshDesktop(
        displayID: CGDirectDisplayID,
        desktopImageURL: URL?,
        staticLayout: StaticLayout?,
        reason: RefreshReason,
        targetMaxDimension: Int
    ) {
        let maximumPixels = maximumDecodedPixelCount
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            defer {
                if let self, generation == self.loadGeneration {
                    self.loadTask = nil
                }
            }
            guard let self else { return }

            let resolution = await Task.detached(priority: .userInitiated) {
                Self.resolveWallpaperIdentity(
                    displayID: displayID,
                    desktopImageURL: desktopImageURL
                )
            }.value

            guard !Task.isCancelled,
                  generation == self.loadGeneration,
                  self.isWindowVisible else { return }

            let identity = resolution.exactIdentity
            var quietPeriod = self.captureQuietPeriods[displayID] ?? WallpaperCaptureQuietPeriod()
            quietPeriod.observe(CaptureConfiguration(identity: resolution.captureIdentity, version: resolution.contextVersion),
                                at: ProcessInfo.processInfo.systemUptime)
            self.captureQuietPeriods[displayID] = quietPeriod
            if self.lastDesktopContextVersion != resolution.contextVersion {
                self.desktopContextIsDirty = true
                self.lastDesktopContextVersion = resolution.contextVersion
            }
            if case let .image(url) = resolution.captureIdentity?.source { self.contextMonitor?.watchSource(url) }
            else { self.contextMonitor?.watchSource(nil) }
            let captureContext = self.captureContext(for: displayID, resolution: resolution)
            var cached = self.cachedCaptures[displayID]
            // WindowServer replaces wallpaper windows during full-screen/Space
            // transitions. A new window ID alone is not a new wallpaper/frame.
            // Keep the last sample and its confirmation progress when the
            // display-specific content, timestamps, geometry and quality are
            // unchanged. An unconfirmed sample still goes through comparison;
            // rebinding never promotes it to a settled frame. Hard lifecycle
            // invalidations clear the cache before reaching this point.
            if let current = captureContext, let previous = cached,
               previous.context.windowID != current.windowID,
               previous.context.version == current.version,
               previous.context.hasSameWallpaperAndGeometry(as: current) {
                cached = CachedCapture(context: current, image: previous.image,
                    sampledAt: previous.sampledAt, settling: previous.settling)
                self.cachedCaptures[displayID] = cached
            }
            let matchingCapture = captureContext != nil && cached?.context == captureContext
            // Keep the old candidate through the quiet period for one-shot
            // revalidation; it cannot count as a hit unless the full context
            // matches. Missing permission/identity still discards it immediately.
            if !matchingCapture, captureContext == nil { self.cachedCaptures.removeValue(forKey: displayID) }
            // Preflight does not capture or prompt. A revoked grant must not
            // leave a live-capture record eligible for indefinite reuse.
            let hasSettledCapture = matchingCapture && cached?.settling.isSettled == true
            let hasMatchingContent = identity != nil
                && self.activeWallpaperIdentity == identity
                && self.content != nil
                && (!matchingCapture || cached?.image === self.content?.image)
            let shouldForce = reason == .settingsChanged || reason == .contextChanged || self.desktopContextIsDirty
            let action = shouldForce
                ? WallpaperRefreshAction.capture
                : WallpaperRefreshPolicy.windowShown(
                    kind: identity?.kind,
                    hasMatchingContent: hasMatchingContent,
                    hasSettledCapture: hasSettledCapture
                )
            if action == .reuse {
                self.touchDesktopFrame(displayID)
                return
            }

            // The previous image stays on screen until a new one is ready: only
            // stop treating it as a match for the current wallpaper.
            if self.activeWallpaperIdentity != identity {
                self.activeWallpaperIdentity = nil
            }

            // Direct reading is only valid for a confirmed, single-image source.
            // The renderer reproduces the desktop's scaling and letterboxing.
            if let url = resolution.verifiedStaticURL, let staticLayout {
                let image = await Task.detached(priority: .userInitiated) {
                    staticLayout.render(url: url, maximumPixels: maximumPixels)
                }.value
                if let image, await self.publishDesktopImage(
                    image, identity: identity, displayID: displayID, generation: generation,
                    requiresStableIdentity: true
                ) {
                    return
                }
            }

            // Do not delay a settled cache hit. Only capture work waits for the
            // observed wallpaper configuration or lifecycle transition to settle.
            let now = ProcessInfo.processInfo.systemUptime
            let wait = max(quietPeriod.delay(at: now), self.captureNotBefore - now)
            if !hasSettledCapture, wait > 0 {
                do { try await Task.sleep(for: .seconds(wait)) } catch { return }
                guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible,
                      self.contextMonitor?.isSuspended != true,
                      let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else { return }
                // Re-resolve after waiting; never capture using the pre-wait URL
                // or context. A later display request cancels this task normally.
                self.refreshDesktop(displayID: displayID,
                    desktopImageURL: NSWorkspace.shared.desktopImageURL(for: screen),
                    staticLayout: StaticLayout(screen: screen), reason: .contextChecked,
                    targetMaxDimension: targetMaxDimension)
                return
            }
            self.captureQuietPeriods[displayID]?.captureStarted()
            if !matchingCapture { self.cachedCaptures.removeValue(forKey: displayID) }

            if matchingCapture, let cached {
                // Resume a cancelled confirmation after a quick hide/show;
                // keeping the candidate does not claim that it is settled.
                await self.settleDesktopCapture(cached, displayID: displayID, generation: generation)
                return
            }

            // Bounded retry loop: attempt the live snapshot; when it is not
            // available, publish a fallback frame once and keep retrying for a
            // few seconds so the true frozen frame replaces the fallback as
            // soon as the system exposes it again.
            for attempt in 0...Self.desktopSnapshotRetryDelays.count {
                guard !Task.isCancelled,
                      generation == self.loadGeneration,
                      self.isWindowVisible else { return }

                var permissionRequired = false
                let image: CGImage?
                do {
                    image = try await WallpaperScreenCapture.capture(displayID: displayID, maximumPixels: maximumPixels)
                } catch WallpaperCaptureError.permissionRequired {
                    permissionRequired = true
                    image = nil
                } catch {
                    image = nil
                }

                guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible else { return }
                if let image, let captureContext {
                    let sampledAt = ContinuousClock.now
                    var settling = WallpaperSettlingState()
                    // Space transitions can replace the wallpaper window or
                    // update LastUse without changing its pixels. Validate once
                    // against the settled frame before restarting confirmations.
                    // Hard invalidations already removed cachedCaptures, so they
                    // cannot use this shortcut (unlock, wake, settings changes).
                    if let cached, cached.settling.isSettled,
                       cached.context.hasSameWallpaperAndGeometry(as: captureContext) {
                        let previous = cached.image
                        let comparison = await Task.detached(priority: .utility) {
                            autoreleasepool { WallpaperFrameStability.compare(previous, image) }
                        }.value
                        guard !Task.isCancelled, generation == self.loadGeneration,
                              self.isWindowVisible else { return }
                        let matches = comparison.matches
                        settling = cached.settling.revalidated(matchesPrevious: matches)
                    }
                    let candidate = CachedCapture(context: captureContext, image: image,
                        sampledAt: sampledAt, settling: settling)
                    await self.settleDesktopCapture(candidate, displayID: displayID, generation: generation)
                    return
                }
                if let image, await self.publishDesktopImage(
                    image, identity: identity, displayID: displayID, generation: generation
                ) { return }


                guard !permissionRequired, attempt < Self.desktopSnapshotRetryDelays.count else {
                    self.retainMatchingDesktopContent(for: identity, displayID: displayID)
                    return
                }
                try? await Task.sleep(for: Self.desktopSnapshotRetryDelays[attempt])
            }
        }
    }

    private func retainMatchingDesktopContent(for identity: WallpaperIdentity?, displayID: CGDirectDisplayID) {
        // Unknown identity is not a match, even if the cached frame is also
        // unidentified. Evict it so a later display switch cannot restore it.
        if identity == nil || lastDesktopFrameByDisplay[displayID]?.wallpaperIdentity != identity {
            lastDesktopFrameByDisplay.removeValue(forKey: displayID)
            desktopFrameBudgets.removeValue(forKey: displayID)
            desktopFrameUseOrder.removeAll { $0 == displayID }
        }
        guard let identity, content?.wallpaperIdentity == identity else {
            content = lastDesktopFrameByDisplay[displayID]
            activeWallpaperIdentity = nil
            desktopContextIsDirty = true
            return
        }
    }

    private func publishDesktopImage(
        _ image: CGImage, identity: WallpaperIdentity?, displayID: CGDirectDisplayID,
        generation: Int, requiresStableIdentity: Bool = false,
        capture: CachedCapture? = nil
    ) async -> Bool {
        guard !Task.isCancelled, generation == loadGeneration, isWindowVisible,
              let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else { return false }
        let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
        let confirmedResolution = await Task.detached(priority: .utility) {
            Self.resolveWallpaperIdentity(displayID: displayID, desktopImageURL: currentURL)
        }.value
        guard !Task.isCancelled, generation == loadGeneration, isWindowVisible else { return false }
        let confirmed = capture == nil ? confirmedResolution.exactIdentity : confirmedResolution.captureIdentity
        let stableIdentity = confirmed == identity ? identity : nil
        guard !requiresStableIdentity || stableIdentity != nil else { return false }
        let published = await Content.prepare(image: image, wallpaperIdentity: stableIdentity)
        guard !Task.isCancelled, generation == loadGeneration, isWindowVisible else { return false }
        // A fallback key only identifies a settled screenshot. It must not
        // enable the static-file fast path before confirmations have completed.
        activeWallpaperIdentity = confirmedResolution.exactIdentity == stableIdentity ? stableIdentity : nil
        content = published
        // Publish both references together. The displayed frame and capture
        // candidate share one CGImage, including across quick hides. Captures
        // stay in memory and are never written to disk.
        rememberDesktopFrame(published, displayID: displayID, capture: capture)
        desktopContextIsDirty = false
        return true
    }

    private func captureContext(for displayID: CGDirectDisplayID, resolution: ResolvedWallpaper) -> CaptureContext? {
        func unavailable(_ cause: String) -> CaptureContext? {
            return nil
        }
        guard CGPreflightScreenCaptureAccess() else { return unavailable("permission") }
        guard let identity = resolution.captureIdentity else { return unavailable("unknownIdentity") }
        guard resolution.supportsCaptureReuse else { return unavailable("unsupportedProvider") }
        guard let version = resolution.contextVersion else { return unavailable("unknownVersion") }
        guard let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else {
            return unavailable("missingDisplay")
        }
        guard let windowID = Self.findDesktopWallpaperWindow(for: displayID) else { return unavailable("missingWallpaperWindow") }
        return CaptureContext(identity: identity, version: version, windowID: windowID,
                              frame: screen.frame, scale: screen.backingScaleFactor,
                              maximumPixels: maximumDecodedPixelCount)
    }

    private func captureContextStillMatches(_ context: CaptureContext, displayID: CGDirectDisplayID,
                                           generation: Int) async -> Bool {
        guard !Task.isCancelled, generation == loadGeneration, isWindowVisible,
              contextMonitor?.isSuspended != true,
              let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else { return false }
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        let resolution = await Task.detached(priority: .utility) {
            Self.resolveWallpaperIdentity(displayID: displayID, desktopImageURL: url)
        }.value
        return !Task.isCancelled && generation == loadGeneration && isWindowVisible
            && captureContext(for: displayID, resolution: resolution) == context
    }

    private func settleDesktopCapture(_ initial: CachedCapture, displayID: CGDirectDisplayID,
                                      generation: Int) async {
        let maximumPixels = maximumDecodedPixelCount
        var candidate = initial
        guard await captureContextStillMatches(candidate.context, displayID: displayID, generation: generation),
              await publishDesktopImage(candidate.image, identity: candidate.context.identity,
                displayID: displayID, generation: generation, requiresStableIdentity: true,
                capture: candidate) else { return }
        if candidate.settling.isSettled {
            return
        }
        for _ in 0..<WallpaperFrameStability.maximumConfirmations {
            let deadline = candidate.sampledAt.advanced(by: .seconds(WallpaperFrameStability.confirmationInterval))
            do { try await ContinuousClock().sleep(until: deadline) } catch { return }
            guard await captureContextStillMatches(candidate.context, displayID: displayID, generation: generation) else { return }
            let image: CGImage
            do { image = try await WallpaperScreenCapture.capture(displayID: displayID, maximumPixels: maximumPixels) }
            catch { return } // Keep the displayed frame unconfirmed; retry only on a later open/event.
            let sampledAt = ContinuousClock.now
            let previous = candidate.image
            let comparison = await Task.detached(priority: .utility) {
                autoreleasepool { WallpaperFrameStability.compare(previous, image) }
            }.value
            guard await captureContextStillMatches(candidate.context, displayID: displayID, generation: generation) else { return }
            let matches = comparison.matches
            var settling = candidate.settling
            settling.observe(matchesPrevious: matches)
            candidate = CachedCapture(context: candidate.context, image: image, sampledAt: sampledAt, settling: settling)
            guard await publishDesktopImage(image, identity: candidate.context.identity, displayID: displayID,
                generation: generation, requiresStableIdentity: true,
                capture: candidate) else { return }
            if settling.isSettled { return }
        }
    }

    private func pruneDisconnectedDesktopFrames() {
        let connected = Set(NSScreen.screens.compactMap { Self.displayID(for: $0) })
        let disconnected = Set(lastDesktopFrameByDisplay.keys)
            .union(cachedCaptures.keys).subtracting(connected)
        for displayID in disconnected {
        }
        lastDesktopFrameByDisplay = lastDesktopFrameByDisplay.filter { connected.contains($0.key) }
        cachedCaptures = cachedCaptures.filter { connected.contains($0.key) }
        desktopFrameBudgets = desktopFrameBudgets.filter { connected.contains($0.key) }
        desktopFrameUseOrder.removeAll { !connected.contains($0) }
        captureQuietPeriods = captureQuietPeriods.filter { connected.contains($0.key) }

        let contentDisplayID: CGDirectDisplayID
        switch requestIdentity {
        case .desktop(let id), .preview(let id, _, _): contentDisplayID = id
        default: return
        }
        guard !connected.contains(contentDisplayID) else { return }
        // The published image can keep the same bitmap alive after its cache
        // entries are gone. Release this final controller reference as well.
        content = nil
        activeWallpaperIdentity = nil
        desktopContextIsDirty = true
    }

    private func rememberDesktopFrame(_ frame: Content, displayID: CGDirectDisplayID, capture: CachedCapture? = nil) {
        lastDesktopFrameByDisplay[displayID] = frame
        desktopFrameBudgets[displayID] = maximumDecodedPixelCount
        cachedCaptures[displayID] = capture
        touchDesktopFrame(displayID)
    }

    private func touchDesktopFrame(_ displayID: CGDirectDisplayID) {
        desktopFrameUseOrder.removeAll { $0 == displayID }
        desktopFrameUseOrder.insert(displayID, at: 0)
        let costs = lastDesktopFrameByDisplay.mapValues { $0.image.bytesPerRow * $0.image.height }
        let retained = WallpaperCacheBudget.retainedDisplays(mostRecentFirst: desktopFrameUseOrder,
            bytesByDisplay: costs, currentDisplay: displayID, unfiltered: usesUnfilteredBackground)
        for evicted in desktopFrameUseOrder where !retained.contains(evicted) {
        }
        lastDesktopFrameByDisplay = lastDesktopFrameByDisplay.filter { retained.contains($0.key) }
        cachedCaptures = cachedCaptures.filter { retained.contains($0.key) }
        desktopFrameBudgets = desktopFrameBudgets.filter { retained.contains($0.key) }
        desktopFrameUseOrder.removeAll { !retained.contains($0) }
    }

    static func canReadStaticWallpaper(for screen: NSScreen) async -> Bool {
        guard let displayID = displayID(for: screen), let layout = StaticLayout(screen: screen) else { return false }
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        return await Task.detached(priority: .utility) {
            guard let source = Self.resolveWallpaperIdentity(displayID: displayID, desktopImageURL: url).verifiedStaticURL else { return false }
            return layout.render(url: source) != nil
        }.value
    }

    private func refreshCustom(path: String, targetMaxDimension: Int) {
        let maximumPixels = maximumDecodedPixelCount
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        loadTask = Task { [weak self] in
            defer {
                if let self, generation == self.loadGeneration {
                    self.loadTask = nil
                }
            }

            let cacheKey = await Task.detached(priority: .userInitiated) {
                let url = URL(fileURLWithPath: path)
                guard FileManager.default.isReadableFile(atPath: path) else { return CacheKey?.none }
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                return CacheKey.custom(
                    path: path,
                    fileSize: values?.fileSize ?? 0,
                    modificationTime: values?.contentModificationDate?.timeIntervalSince1970 ?? 0,
                    targetMaxDimension: targetMaxDimension
                )
            }.value

            guard let self, !Task.isCancelled, generation == self.loadGeneration else { return }
            guard let cacheKey else {
                self.activeCacheKey = nil
                self.content = nil
                return
            }
            if self.activeCacheKey == cacheKey, self.content != nil {
                return
            }

            let image = await Task.detached(priority: .userInitiated) {
                autoreleasepool {
                    Self.decodeCustomImage(
                        at: URL(fileURLWithPath: path),
                        targetMaxDimension: targetMaxDimension, maximumPixels: maximumPixels
                    )
                }
            }.value

            guard !Task.isCancelled, generation == self.loadGeneration else { return }
            guard let image else {
                self.activeCacheKey = nil
                self.content = nil
                return
            }

            let prepared = await Content.prepare(image: image)
            guard !Task.isCancelled, generation == self.loadGeneration, self.isWindowVisible else { return }
            self.activeCacheKey = cacheKey
            self.content = prepared
        }
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    // Metadata only, used to invalidate a cached frame when its window changes.
    // ScreenCaptureKit independently verifies the window before capturing pixels.
    nonisolated private static func findDesktopWallpaperWindow(for displayID: CGDirectDisplayID) -> CGWindowID? {
        let displayBounds = CGDisplayBounds(displayID)
        guard displayBounds.width > 0, displayBounds.height > 0 else { return nil }

        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
            as? [[String: Any]] ?? []

        let candidates = windows.compactMap { info -> CGWindowID? in
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = info[kCGWindowName as String] as? String ?? ""
            let normalizedName = name.lowercased()
            let isWallpaperWindow = (owner == "WindowManager" && normalizedName == "wallpaper")
                || (owner == "Dock" && normalizedName.hasPrefix("wallpaper"))
            guard isWallpaperWindow,
                  let windowIDNumber = info[kCGWindowNumber as String] as? NSNumber,
                  let bounds = windowBounds(from: info[kCGWindowBounds as String]) else {
                return nil
            }

            let intersection = bounds.intersection(displayBounds)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return nil }
            let displayArea = displayBounds.width * displayBounds.height
            let score = (intersection.width * intersection.height) / displayArea
            guard score >= 0.95, bounds.width > 0, bounds.height > 0,
                  intersection.width * intersection.height / (bounds.width * bounds.height) >= 0.95 else { return nil }

            return CGWindowID(windowIDNumber.uint32Value)
        }
        return candidates.count == 1 ? candidates.first : nil
    }

    nonisolated private static func windowBounds(from value: Any?) -> CGRect? {
        guard let dictionary = value as? [String: Any],
              let x = (dictionary["X"] as? NSNumber)?.doubleValue,
              let y = (dictionary["Y"] as? NSNumber)?.doubleValue,
              let width = (dictionary["Width"] as? NSNumber)?.doubleValue,
              let height = (dictionary["Height"] as? NSNumber)?.doubleValue else {
            return nil
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    nonisolated private static func downsampleCapturedImageIfNeeded(_ image: CGImage, maximumPixels: Int) -> CGImage? {
        let pixelCount = image.width * image.height
        guard pixelCount > maximumPixels else { return image }

        let scale = sqrt(Double(maximumPixels) / Double(pixelCount))
        let width = max(1, Int((Double(image.width) * scale).rounded(.down)))
        let height = max(1, Int((Double(image.height) * scale).rounded(.down)))
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    nonisolated private static func decodeCustomImage(
        at url: URL,
        targetMaxDimension: Int,
        maximumPixels: Int
    ) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0,
              height > 0 else {
            return nil
        }

        let sourceMaxDimension = max(width, height)
        let dimensionScale = min(1, Double(targetMaxDimension) / sourceMaxDimension)
        let pixelScale = min(1, sqrt(Double(maximumPixels) / (width * height)))
        let thumbnailMaxDimension = max(
            1,
            Int((sourceMaxDimension * min(dimensionScale, pixelScale)).rounded(.down))
        )
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    }

    // MARK: - Identity-bound wallpaper fallbacks

    nonisolated private static func resolveWallpaperIdentity(
        displayID: CGDirectDisplayID,
        desktopImageURL: URL?,
        forPreview: Bool = false
    ) -> ResolvedWallpaper {
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return ResolvedWallpaper(resolution: .unavailable, verifiedStaticURL: nil)
        }
        let displayUUID = CFUUIDCreateString(nil, uuidRef) as String
        let storeURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support/com.apple.wallpaper/Store/Index.plist"
        )
        let store: [String: Any]
        if let data = try? Data(contentsOf: storeURL),
           let root = try? PropertyListSerialization.propertyList(
               from: data,
               options: [],
               format: nil
           ) as? [String: Any] {
            store = root
        } else {
            store = [:]
        }
        if forPreview {
            let preview = WallpaperIdentityResolver.resolvePreview(
                displayUUID: displayUUID, store: store, currentDesktopImageURL: desktopImageURL)
            return ResolvedWallpaper(resolution: preview.map { .exact($0) } ?? .unavailable,
                                     verifiedStaticURL: nil)
        }
        let verified = WallpaperIdentityResolver.resolve(
            displayUUID: displayUUID,
            store: store,
            currentDesktopImageURL: desktopImageURL,
            allowUnverifiedDesktopImageURL: false
        )
        let contextVersion = WallpaperIdentityResolver.desktopContextVersion(displayUUID: displayUUID, store: store)
        let staticURL: URL?
        if let identity = verified.exactIdentity, identity.kind == .staticImage,
           case let .image(url) = identity.source, url == desktopImageURL?.standardizedFileURL {
            staticURL = url
        } else { staticURL = nil }
        let appearanceOnly: Bool
        if let identity = verified.exactIdentity, identity.provider == "com.apple.wallpaper.choice.dynamic",
           case let .image(url) = identity.source {
            appearanceOnly = WallpaperImageRenderer.isAppearanceOnlyDesktop(configuredURL: url, reportedURL: desktopImageURL)
        } else { appearanceOnly = false }
        return ResolvedWallpaper(resolution: verified, verifiedStaticURL: staticURL, contextVersion: contextVersion,
            captureFallbackIdentity: verified.exactIdentity == nil
                ? WallpaperIdentityResolver.captureFallbackIdentity(displayUUID: displayUUID, store: store,
                    currentDesktopImageURL: desktopImageURL) : nil,
            appearanceOnly: appearanceOnly,
            systemIsDark: UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark")
    }

    nonisolated private static func firstVideoFrame(
        at url: URL,
        targetMaxDimension: Int,
        maximumPixels: Int
    ) async -> CGImage? {
        guard FileManager.default.isReadableFile(atPath: url.path) else { return nil }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // Bound the generated frame itself, not just the later cached copy.
        var maximumDimension = min(targetMaxDimension, Int(sqrt(Double(maximumPixels))))
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let naturalSize = try? await track.load(.naturalSize) {
            let size = WallpaperImageRenderer.outputSize(for: naturalSize, maximumPixels: maximumPixels)
            if size.width > 0, size.height > 0 {
                maximumDimension = min(targetMaxDimension, Int(max(size.width, size.height)))
            }
        }
        generator.maximumSize = CGSize(width: maximumDimension, height: maximumDimension)
        return try? await generator.image(at: .zero).image
    }
}

final class BackgroundImageLayerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.magnificationFilter = .linear
        layer?.minificationFilter = .trilinear
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        layer?.contents = nil
    }
}

struct LaunchpadBackgroundImageView: NSViewRepresentable {
    let image: CGImage?

    func makeNSView(context: Context) -> BackgroundImageLayerView {
        BackgroundImageLayerView(frame: .zero)
    }

    func updateNSView(_ nsView: BackgroundImageLayerView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        nsView.layer?.contents = image
        CATransaction.commit()
    }

    static func dismantleNSView(_ nsView: BackgroundImageLayerView, coordinator: Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        nsView.layer?.contents = nil
        CATransaction.commit()
    }
}
