import Foundation

// LaunchMad ships a single English interface. Every key maps to exactly one
// string through an exhaustive switch, so a missing string is a build error.

enum LocalizationKey: String, CaseIterable {
    case noAppsFound
    case searchPlaceholder
    case appTitle
    case classicMode
    case iconSize
    case iconsPerRow
    case rowsPerPage
    case iconHorizontalSpacing
    case iconVerticalSpacing
    case labelFontSize
    case iconLabelFontWeight
    case folderDropZoneSizeHint
    case folderDropZoneSizeWithDefault
    case pageIndicatorHint
    case rememberPageTitle
    case pageIndicatorTopPaddingLabel
    case layoutModeScopeFullscreen
    case layoutModeScopeCompact
    case indicatorOfflineDisplay
    case indicatorOfflineBadge
    case indicatorScreenIDFormat
    case defaultOption
    case customOption
    case perDisplayIndicatorPositionTitle
    case perDisplayIndicatorPositionDescription
    case applyDefaultsToCurrentDisplay
    case globalShortcutTitle
    case globalShortcutDescription
    case shortcutSetButton
    case shortcutSaveButton
    case shortcutClearButton
    case shortcutNotSet
    case shortcutListening
    case shortcutCapturePrompt
    case shortcutNoModifierWarning
    case dockDragSectionTitle
    case dockDragSectionDescription
    case dockDragEnabledTitle
    case dockDragSideTitle
    case dockDragTriggerDistanceTitle
    case dockDragDisabled
    case dockDragSideBottom
    case dockDragSideLeft
    case dockDragSideRight
    case hotCornerSectionTitle
    case hotCornerSectionDescription
    case hotCornerEnabledTitle
    case hotCornerPositionTitle
    case hotCornerTriggerDelayTitle
    case hotCornerHitboxSizeTitle
    case hotCornerToggleWhenOpenTitle
    case gestureSectionTitle
    case gestureSectionDescription
    case gestureEnabledTitle
    case gestureCloseOnPinchOutTitle
    case gestureTapActionTitle
    case gestureFingerCountTitle
    case gestureFingerCountFour
    case gestureFingerCountFive
    case gestureTapActionOff
    case gestureTapActionOpen
    case gestureTapActionToggle
    case gestureInputDeviceTitle
    case gestureInputDeviceModeAuto
    case gestureInputDeviceModeSelected
    case gestureInputDeviceAutoDescription
    case gestureInputDeviceManualEmpty
    case gestureInputDeviceBuiltInBadge
    case gestureInputDeviceExternalBadge
    case gestureInputDeviceShowAllTitle
    case gestureInputDeviceRecommendedBadge
    case gestureInputDeviceUnverifiedBadge
    case gestureInputDeviceNoRecommendedDescription
    case gestureInputDeviceUnverifiedWarning
    case gestureInputDeviceFamilyIDFormat
    case gestureInputDeviceUnavailableDescription
    case gestureSystemHintTitle
    case gestureSystemHintBody
    case hotCornerPositionTopLeft
    case hotCornerPositionTopRight
    case hotCornerPositionBottomLeft
    case hotCornerPositionBottomRight
    case smaller
    case larger
    case predictDrop
    case showLabels
    case useLocalizedThirdPartyTitles
    case enableAnimations
    case backgroundImageTitle
    case backgroundImageSourceTitle
    case backgroundImageSourceTitleCompact
    case backgroundImageSourceCustomImageCompact
    case backgroundImageSourceDesktopPreview
    case wallpaperPreviewHint
    case backgroundImageSourceDesktopWallpaper
    case backgroundImageSourceCustomImage
    case wallpaperCaptureStatic
    case wallpaperCaptureGranted
    case wallpaperCaptureRequired
    case wallpaperCaptureHint
    case chooseBackgroundImage
    case changeBackgroundImage
    case backgroundImageUnavailable
    case windowOpenAnimationTitle
    case windowMaxWidthTitle
    case windowMaxHeightTitle
    case windowSizeAutomatic
    case windowSizeLimitHint
    case windowShadowTitle
    case windowShadowHint
    case windowAnimationDurationLabel
    case followScrollPagingTitle
    case reverseWheelPagingTitle
    case reverseWheelVerticalTitle
    case reverseWheelDirectionCardTitle
    case reverseWheelDirectionCardDescription
    case trackpadVerticalDirectionTitle
    case trackpadVerticalDirectionNatural
    case trackpadVerticalDirectionReversed
    case hideDockOption
    case hideMenuBarOption
    case hideMenuBarInfoBody
    case hoverMagnification
    case hoverMagnificationScale
    case activePressEffect
    case activePressScale
    case backgroundMaskTitle
    case backgroundMaskLightLabel
    case backgroundMaskDarkLabel
    case folderPreviewHighResTitle
    case folderPreviewHighResHint
    case folderLiquidGlassTitle
    case folderLiquidGlassHint
    case folderQuickLaunchTitle
    case folderQuickLaunchHint
    case folderLayoutTitle
    case folderLayoutDescription
    case folderLayoutPaged
    case folderLayoutVertical
    case animationDurationLabel
    case gridSizeChangeWarning
    case scrollSensitivity
    case low
    case high
    case importSystem
    case importLegacy
    case importTip
    case onboardingFlowWelcomeTitle
    case onboardingFlowWelcomeSubtitle
    case onboardingFlowProgressFormat
    case onboardingFlowPoweredBy
    case onboardingFlowSkip
    case onboardingFlowBack
    case onboardingFlowStart
    case onboardingFlowNext
    case onboardingFlowDone
    case onboardingFlowIntroTitle
    case onboardingFlowIntroSubtitle
    case onboardingFlowIntroImportItem
    case onboardingFlowIntroPresetItem
    case onboardingFlowIntroShortcutItem
    case onboardingFlowLayoutStepTitle
    case onboardingFlowLayoutStepSubtitle
    case onboardingFlowLayoutChooseMethod
    case onboardingFlowLayoutOptionATitle
    case onboardingFlowLayoutOptionASubtitle
    case onboardingFlowLayoutOptionADetail
    case onboardingFlowLayoutOptionAUnavailableDetail
    case onboardingFlowLayoutOptionAButton
    case onboardingFlowLayoutOptionAUnavailableButton
    case onboardingFlowLayoutOptionBTitle
    case onboardingFlowLayoutOptionBSubtitle
    case onboardingFlowLayoutOptionBDetail
    case onboardingFlowLayoutOptionBButton
    case onboardingFlowLayoutSkipButton
    case onboardingFlowShortcutStepTitle
    case onboardingFlowShortcutStepSubtitle
    case onboardingFlowShortcutStepButton
    case onboardingFlowCompletionHeadline
    case onboardingFlowCompletionDescription
    case onboardingFlowSidebarStart
    case onboardingFlowSidebarLayout
    case onboardingFlowSidebarShortcut
    case onboardingFlowSidebarDone
    case exportData
    case importData
    case dataManagementTitle
    case layoutPresetApplyButton
    case layoutPresetAppliedTitle
    case layoutPresetAppliedMessage
    case layoutPresetApplyFailedMessage
    case layoutPresetOtherFolderTitle
    case refresh
    case showQuickRefreshButton
    case launchAtLoginTitle
    case lockLayoutTitle
    case lockLayoutDescription
    case scanSourcesIntroTitle
    case scanSourcesIntroDescription
    case scanSourcesDefaultListTitle
    case scanSourcesCustomListTitle
    case scanSourcesAddButton
    case scanSourcesResetButton
    case scanSourcesEmptyHint
    case scanSourcesMissingBadge
    case scanSourcesFuzzySearchTitle
    case scanSourcesFuzzySearchDescription
    case scanSourcesSearchDelayTitle
    case scanSourcesSearchDelayDescription
    case resetLayout
    case resetAppearanceSettings
    case resetAlertTitle
    case resetAlertMessage
    case resetAppearanceAlertTitle
    case resetAppearanceAlertMessage
    case resetConfirm
    case cancel
    case quit
    case appearanceModeTitle
    case appearanceModeFollowSystem
    case appearanceModeLight
    case appearanceModeDark
    case versionPrefix
    case versionLabelFormat
    case versionFallback
    case aboutInfoSystemTitle
    case aboutInfoMacOSLabel
    case aboutInfoMacOSValueFormat
    case aboutInfoProcessorTitle
    case aboutInfoChipLabel
    case aboutInfoDisplayTitle
    case aboutInfoUnknownChip
    case aboutInfoUnknownDisplay
    case aboutInfoDisplayGeneric
    case sidebarIconSizeTitle
    case sidebarIconSizeLarge
    case sidebarIconSizeMedium
    case settingsSectionPerformance
    case settingsSectionTitles
    case settingsSectionBackup
    case settingsSectionAbout
    case settingsSectionGeneral
    case settingsSectionAppSources
    case settingsSectionAppearance
    case settingsSectionHiddenApps
    case settingsSectionUninstall
    case settingsSectionGameController
    case settingsSectionSound
    case backgroundStyleTitle
    case backgroundStyleOptionBlur
    case backgroundStyleOptionGlass
    case backgroundStyleOptionUnfiltered
    case backgroundStyleUnfilteredMemoryHint
    case backgroundStyleUnfilteredRequiresImage
    case backupPlaceholderTitle
    case backupChooseFolderButton
    case backupCreateButton
    case backupDeleteSelectedButton
    case backupNoFolderSelected
    case backupNoBackupsFound
    case backupImportButton
    case backupDeleteButton
    case backupEstimatedSizeHint
    case backupDeleteMultipleTitle
    case backupDeleteMultipleMessageFormat
    case backupDeleteSingleTitle
    case backupDeleteSingleMessage
    case gameControllerPlaceholderTitle
    case gameControllerPlaceholderSubtitle
    case gameControllerToggleTitle
    case gameControllerStatusDisabled
    case gameControllerStatusNoController
    case gameControllerStatusConnectedFormat
    case gameControllerQuickGuideTitle
    case gameControllerQuickGuideDirection
    case gameControllerQuickGuideSelect
    case gameControllerQuickGuideCancel
    case gameControllerQuickGuideMenuToggle
    case gameControllerMenuToggleTitle
    case gameControllerMenuToggleSubtitle
    case soundToggleTitle
    case soundToggleDescription
    case soundEventLaunchpadOpen
    case soundEventLaunchpadClose
    case soundEventNavigation
    case soundPreviewButton
    case soundOptionNone
    case voiceToggleTitle
    case voiceToggleDescription
    case voiceNoteMutualExclusive
    case voiceAnnouncementAppFormat
    case voiceAnnouncementFolderFormat
    case hiddenAppsAddButton
    case hiddenAppsEmptyTitle
    case hiddenAppsHint
    case hiddenAppsRemoveButton
    case hiddenAppsSearchPlaceholder
    case notHiddenAppsTitle
    case notHiddenAppsHint
    case notHiddenAppsSearchPlaceholder
    case contextMenuShowInLayout
    case contextMenuShowInFinder
    case contextMenuCopyAppPath
    case contextMenuPinToFolderQuickLaunchTop
    case contextMenuUnpinFromFolderQuickLaunchTop
    case contextMenuRenameFolder
    case contextMenuDissolveFolder
    case contextMenuUninstallWithConfiguredTool
    case contextMenuBatchSelectApps
    case contextMenuFinishBatchSelection
    case uninstallSectionDescription
    case uninstallToolPathLabel
    case uninstallToolNotConfigured
    case uninstallToolMissing
    case uninstallToolChooseButton
    case uninstallToolClearButton
    case uninstallToolOpenButton
    case uninstallToolPanelTitle
    case performanceModeTitle
    case performanceModeFull
    case performanceModeLean
    case performanceModeDescriptionFull
    case performanceModeDescriptionLean
    case performanceRendererRecommendation
    case performanceModeRestartHint
    case performanceModeRestartTitle
    case performanceModeRestartMessage
    case performanceRendererTitle
    case performanceRendererBadge
    case performanceRendererSubtitle
    case performanceRendererWarning
    case performanceCacheTitle
    case performanceCacheStatusValid
    case performanceCacheStatusInvalid
    case performanceCacheLastUpdateLabel
    case performanceCacheNever
    case performanceCacheClearButton
    case performanceCacheIconLabel
    case performanceCacheAppInfoLabel
    case performanceCacheGridLabel
    case performanceCacheCountsHint
    case performanceCacheIconsDisabled
    case performanceCacheLeanHint
    case renameSearchPlaceholder
    case customTitlePlaceholder
    case customTitleHint
    case customTitleDefaultFormat
    case customTitleReset
    case customTitleAddButton
    case customTitleAddFromFolder
    case loadMore
    case customTitleNoResults
    case customTitlePickerMessage
    case customTitleEdit
    case customTitleSave
    case customTitleCancel
    case customTitleOnly
    case loadingApplications
    case customIconTitle
    case customIconChoose
    case customIconReset
    case customIconHint
    case customIconError
    case pageIndicatorOffsetLabel
    case folderWindowWidth
    case folderWindowHeight
    case folderWindowSizeHint
    case folderNamePlaceholder
    case chooseButton
    case exportPanelMessage
    case importPrompt
    case importPanelMessage
    case legacyArchivePanelMessage
    case importSuccessfulTitle
    case importFailedTitle
    case okButton
    case aboutAttribution
    case aboutLicense
    case aboutOfflineNotice
    case importLegacyDatabaseHint
    case launcherRowPinnedTitle
    case launcherRowPinnedEmpty
    case launcherRowRecentTitle
    case launcherRowRecentEmpty
    case launcherRowClearRecents
    case launcherRowClearRecentsHelp
    case contextMenuPinToLauncher
    case contextMenuUnpinFromLauncher
    case contextMenuRemoveFromRecents
}

extension LocalizationKey {
    var english: String {
        switch self {
        case .noAppsFound: return "No apps found"
        case .searchPlaceholder: return "Search"
        case .appTitle: return "LaunchMad"
        case .classicMode: return "Classic Launchpad (Fullscreen)"
        case .iconSize: return "Icon size"
        case .iconsPerRow: return "Icons per row"
        case .rowsPerPage: return "Rows per page"
        case .iconHorizontalSpacing: return "Horizontal spacing"
        case .iconVerticalSpacing: return "Vertical spacing"
        case .labelFontSize: return "Label font size"
        case .iconLabelFontWeight: return "Icon label weight"
        case .folderDropZoneSizeHint: return "Smaller values reduce accidental folder creation when dragging icons in windowed mode."
        case .folderDropZoneSizeWithDefault: return "Folder drop zone size (Default: %.1fx)"
        case .pageIndicatorHint: return "If vertical spacing feels subtle, adjust the page indicator offset below."
        case .rememberPageTitle: return "Remember last opened page"
        case .pageIndicatorTopPaddingLabel: return "Page indicator top padding"
        case .layoutModeScopeFullscreen: return "Fullscreen"
        case .layoutModeScopeCompact: return "Compact"
        case .indicatorOfflineDisplay: return "Offline Display"
        case .indicatorOfflineBadge: return "Offline"
        case .indicatorScreenIDFormat: return "ID %@"
        case .defaultOption: return "Default"
        case .customOption: return "Custom"
        case .perDisplayIndicatorPositionTitle: return "Per-display indicator position"
        case .perDisplayIndicatorPositionDescription: return "Use different values for each display."
        case .applyDefaultsToCurrentDisplay: return "Apply defaults to current display"
        case .globalShortcutTitle: return "Shortcut & gesture"
        case .globalShortcutDescription: return "Use a global shortcut to open or close LaunchMad quickly."
        case .shortcutSetButton: return "Set shortcut"
        case .shortcutSaveButton: return "Save"
        case .shortcutClearButton: return "Clear"
        case .shortcutNotSet: return "Not set"
        case .shortcutListening: return "Listening…"
        case .shortcutCapturePrompt: return "Press the desired key combination. Press Esc to cancel."
        case .shortcutNoModifierWarning: return "Using no modifier may clash with other apps."
        case .dockDragSectionTitle: return "Drag apps to Dock"
        case .dockDragSectionDescription: return "Choose where Dock drag should trigger and how far you need to drag before LaunchMad hands off to macOS."
        case .dockDragEnabledTitle: return "Enable Dock drag"
        case .dockDragSideTitle: return "Dock side"
        case .dockDragTriggerDistanceTitle: return "Trigger distance"
        case .dockDragDisabled: return "Off"
        case .dockDragSideBottom: return "Bottom"
        case .dockDragSideLeft: return "Left"
        case .dockDragSideRight: return "Right"
        case .hotCornerSectionTitle: return "Hot Corner"
        case .hotCornerSectionDescription: return "Open LaunchMad when the pointer reaches the selected screen corner."
        case .hotCornerEnabledTitle: return "Enable Hot Corner"
        case .hotCornerPositionTitle: return "Corner"
        case .hotCornerTriggerDelayTitle: return "Trigger delay"
        case .hotCornerHitboxSizeTitle: return "Trigger zone"
        case .hotCornerToggleWhenOpenTitle: return "Close when already open"
        case .gestureSectionTitle: return "Gesture"
        case .gestureSectionDescription: return "Experimental trackpad pinch and tap gestures for LaunchMad."
        case .gestureEnabledTitle: return "Enable pinch gesture"
        case .gestureCloseOnPinchOutTitle: return "Close with spread gesture"
        case .gestureTapActionTitle: return "Tap gesture"
        case .gestureFingerCountTitle: return "Gesture fingers"
        case .gestureFingerCountFour: return "4 fingers"
        case .gestureFingerCountFive: return "5 fingers"
        case .gestureTapActionOff: return "Off"
        case .gestureTapActionOpen: return "Open"
        case .gestureTapActionToggle: return "Toggle"
        case .gestureInputDeviceTitle: return "Gesture input device"
        case .gestureInputDeviceModeAuto: return "Auto"
        case .gestureInputDeviceModeSelected: return "Selected devices"
        case .gestureInputDeviceAutoDescription: return "Listen to all available trackpads and use the first one that triggers a valid gesture."
        case .gestureInputDeviceManualEmpty: return "Select at least one trackpad."
        case .gestureInputDeviceBuiltInBadge: return "Built-in"
        case .gestureInputDeviceExternalBadge: return "External"
        case .gestureInputDeviceShowAllTitle: return "Show all input devices"
        case .gestureInputDeviceRecommendedBadge: return "Recommended"
        case .gestureInputDeviceUnverifiedBadge: return "Unverified"
        case .gestureInputDeviceNoRecommendedDescription: return "No recommended trackpads found. Turn on Show all input devices to test another multitouch device."
        case .gestureInputDeviceUnverifiedWarning: return "This device may not be a trackpad. Select it only for testing."
        case .gestureInputDeviceFamilyIDFormat: return "FamilyID %d"
        case .gestureInputDeviceUnavailableDescription: return "Some selected devices are unavailable right now. Reconnect them or choose another trackpad."
        case .gestureSystemHintTitle: return "Trackpad setup"
        case .gestureSystemHintBody: return "Turn off Show Desktop in System Settings > Trackpad > More Gestures before using this gesture."
        case .hotCornerPositionTopLeft: return "Top left"
        case .hotCornerPositionTopRight: return "Top right"
        case .hotCornerPositionBottomLeft: return "Bottom left"
        case .hotCornerPositionBottomRight: return "Bottom right"
        case .smaller: return "Smaller"
        case .larger: return "Larger"
        case .predictDrop: return "Predict drop position"
        case .showLabels: return "Show labels under icons"
        case .useLocalizedThirdPartyTitles: return "Use localized app names"
        case .enableAnimations: return "Enable slide animation"
        case .backgroundImageTitle: return "Use image background"
        case .backgroundImageSourceTitle: return "Background source"
        case .backgroundImageSourceTitleCompact: return "Source"
        case .backgroundImageSourceCustomImageCompact: return "Custom image"
        case .backgroundImageSourceDesktopPreview: return "Static preview"
        case .wallpaperPreviewHint: return "No screen recording access needed. Animated wallpapers use a still preview that may differ from the desktop. Some wallpapers may not have a readable preview."
        case .backgroundImageSourceDesktopWallpaper: return "Desktop wallpaper"
        case .backgroundImageSourceCustomImage: return "Custom image"
        case .wallpaperCaptureStatic: return "This wallpaper image can be read without screen recording access."
        case .wallpaperCaptureGranted: return "Screen recording access is enabled for desktop wallpaper."
        case .wallpaperCaptureRequired: return "Capturing this wallpaper requires screen recording access."
        case .wallpaperCaptureHint: return "Captures one wallpaper snapshot when LaunchMad opens. macOS grants screen recording access; LaunchMad uses it only for wallpaper. Select this option again to allow access or open System Settings."
        case .chooseBackgroundImage: return "Choose Image…"
        case .changeBackgroundImage: return "Change…"
        case .backgroundImageUnavailable: return "Image unavailable"
        case .windowOpenAnimationTitle: return "Window open/close animation"
        case .windowMaxWidthTitle: return "Maximum window width"
        case .windowMaxHeightTitle: return "Maximum window height"
        case .windowSizeAutomatic: return "Automatic"
        case .windowSizeLimitHint: return "Size limits in points (pt). Leave blank or enter 0 for automatic sizing. Custom limits start at 800 wide and 600 high. The window keeps a 4:3 ratio; limits only reduce the automatic size."
        case .windowShadowTitle: return "Window shadow"
        case .windowShadowHint: return "Turn off to help reduce Liquid Glass black-edge artifacts on some systems."
        case .windowAnimationDurationLabel: return "Window animation duration"
        case .followScrollPagingTitle: return "Follow-scroll paging"
        case .reverseWheelPagingTitle: return "Reverse wheel page direction"
        case .reverseWheelVerticalTitle: return "Reverse wheel vertical scroll"
        case .reverseWheelDirectionCardTitle: return "Scroll & paging direction"
        case .reverseWheelDirectionCardDescription: return "Mouse wheel reversals only affect wheel input. Trackpad and Magic Mouse vertical gestures use their own setting below."
        case .trackpadVerticalDirectionTitle: return "Trackpad & Magic Mouse vertical direction"
        case .trackpadVerticalDirectionNatural: return "Finger moves up -> Next page / Show lower items"
        case .trackpadVerticalDirectionReversed: return "Finger moves up -> Previous page / Show upper items"
        case .hideDockOption: return "Hide Dock"
        case .hideMenuBarOption: return "Hide menu bar in fullscreen"
        case .hideMenuBarInfoBody: return "Dock will also be hidden while this option is active. macOS requires hiding the Dock when hiding the menu bar."
        case .hoverMagnification: return "Hover magnification"
        case .hoverMagnificationScale: return "Hover scale"
        case .activePressEffect: return "Press feedback"
        case .activePressScale: return "Press scale"
        case .backgroundMaskTitle: return "Background mask"
        case .backgroundMaskLightLabel: return "Light appearance mask"
        case .backgroundMaskDarkLabel: return "Dark appearance mask"
        case .folderPreviewHighResTitle: return "High-resolution folder previews"
        case .folderPreviewHighResHint: return "Render folder icons at Retina scale for sharper previews (uses more memory)."
        case .folderLiquidGlassTitle: return "Liquid Glass folder icons"
        case .folderLiquidGlassHint: return "Use clear Liquid Glass for folder icons with Core Animation rendering. Turn off to restore the original style."
        case .folderQuickLaunchTitle: return "Folder Quick Launch"
        case .folderQuickLaunchHint: return "Right-click a folder to open its apps directly. Inside a folder, right-click an app to pin it to the top. Pins are layout settings; launch counts and usage history are not recorded."
        case .folderLayoutTitle: return "Folder Layout"
        case .folderLayoutDescription: return "Choose how apps are displayed inside folders."
        case .folderLayoutPaged: return "Paged"
        case .folderLayoutVertical: return "Vertical Scroll"
        case .animationDurationLabel: return "Slide animation duration"
        case .gridSizeChangeWarning: return "Changing the grid size may reposition some icons."
        case .scrollSensitivity: return "Scrolling sensitivity"
        case .low: return "Low"
        case .high: return "High"
        case .importSystem: return "Import System Launchpad"
        case .importLegacy: return "Import Launchpad Database (.db)"
        case .importTip: return "Tip: Click ‘Import System Launchpad’ to import directly from the system Launchpad."
        case .onboardingFlowWelcomeTitle: return "Welcome to LaunchMad"
        case .onboardingFlowWelcomeSubtitle: return "Make LaunchMad yours."
        case .onboardingFlowProgressFormat: return "Step %d/%d"
        case .onboardingFlowPoweredBy: return "RoversX / CloseX.org"
        case .onboardingFlowSkip: return "Skip onboarding"
        case .onboardingFlowBack: return "Back"
        case .onboardingFlowStart: return "Start"
        case .onboardingFlowNext: return "Next"
        case .onboardingFlowDone: return "Done"
        case .onboardingFlowIntroTitle: return "Ready to begin"
        case .onboardingFlowIntroSubtitle: return "For first launch, complete these setup actions. You can skip now and continue later in Settings."
        case .onboardingFlowIntroImportItem: return "Import system layout"
        case .onboardingFlowIntroPresetItem: return "Apply classic preset"
        case .onboardingFlowIntroShortcutItem: return "Set global shortcut"
        case .onboardingFlowLayoutStepTitle: return "Step 1: Initialize layout"
        case .onboardingFlowLayoutStepSubtitle: return "Choose either system import or classic preset, or continue directly to the next step."
        case .onboardingFlowLayoutChooseMethod: return "Choose an initialization method"
        case .onboardingFlowLayoutOptionATitle: return "Option A"
        case .onboardingFlowLayoutOptionASubtitle: return "Import System Launchpad"
        case .onboardingFlowLayoutOptionADetail: return "Closest to your current macOS layout."
        case .onboardingFlowLayoutOptionAUnavailableDetail: return "No importable system database was found."
        case .onboardingFlowLayoutOptionAButton: return "Use system layout"
        case .onboardingFlowLayoutOptionAUnavailableButton: return "Unavailable"
        case .onboardingFlowLayoutOptionBTitle: return "Option B"
        case .onboardingFlowLayoutOptionBSubtitle: return "Apply Classic Layout Preset"
        case .onboardingFlowLayoutOptionBDetail: return "Great for a fresh Mac; you can fine-tune later."
        case .onboardingFlowLayoutOptionBButton: return "Use classic preset"
        case .onboardingFlowLayoutSkipButton: return "Skip for now and continue"
        case .onboardingFlowShortcutStepTitle: return "Step 2: Set global shortcut"
        case .onboardingFlowShortcutStepSubtitle: return "Configure a shortcut to open LaunchMad anytime without returning to the app window."
        case .onboardingFlowShortcutStepButton: return "Open shortcut settings"
        case .onboardingFlowCompletionHeadline: return "Open-source, lightweight, customizable"
        case .onboardingFlowCompletionDescription: return "Your app layout, your way."
        case .onboardingFlowSidebarStart: return "Start"
        case .onboardingFlowSidebarLayout: return "Layout"
        case .onboardingFlowSidebarShortcut: return "Shortcut"
        case .onboardingFlowSidebarDone: return "Done"
        case .exportData: return "Export Data"
        case .importData: return "Import Data"
        case .dataManagementTitle: return "Data Management"
        case .layoutPresetApplyButton: return "Apply Classic Layout Preset"
        case .layoutPresetAppliedTitle: return "Preset applied"
        case .layoutPresetAppliedMessage: return "The preset layout has been applied to your current apps."
        case .layoutPresetApplyFailedMessage: return "Unable to apply the preset because no available apps were found."
        case .layoutPresetOtherFolderTitle: return "Other"
        case .refresh: return "Refresh"
        case .showQuickRefreshButton: return "Show quick refresh button"
        case .launchAtLoginTitle: return "Silent launch at login"
        case .lockLayoutTitle: return "Lock layout"
        case .lockLayoutDescription: return "Prevent rearranging apps and folders until you turn this off."
        case .scanSourcesIntroTitle: return "Manage additional app libraries"
        case .scanSourcesIntroDescription: return "Add external drives or custom folders so LaunchMad can gather apps beyond the default locations."
        case .scanSourcesDefaultListTitle: return "System directories"
        case .scanSourcesCustomListTitle: return "Custom directories"
        case .scanSourcesAddButton: return "Add folders…"
        case .scanSourcesResetButton: return "Restore defaults"
        case .scanSourcesEmptyHint: return "No custom directories yet. Add one to keep extra apps in sync."
        case .scanSourcesMissingBadge: return "Offline"
        case .scanSourcesFuzzySearchTitle: return "Fuzzy search"
        case .scanSourcesFuzzySearchDescription: return "Use fuzzy matching in launcher search results."
        case .scanSourcesSearchDelayTitle: return "Search delay"
        case .scanSourcesSearchDelayDescription: return "Set how long launcher search waits before updating results."
        case .resetLayout: return "Reset Layout"
        case .resetAppearanceSettings: return "Reset Appearance Tab Settings"
        case .resetAlertTitle: return "Confirm to reset layout?"
        case .resetAlertMessage: return "This will completely reset the layout: remove all folders, clear saved order, and rescan all applications. All customizations will be lost."
        case .resetAppearanceAlertTitle: return "Reset Appearance Tab settings?"
        case .resetAppearanceAlertMessage: return "This will restore the settings in the Appearance tab to their default values without changing your layout or folders."
        case .resetConfirm: return "Reset"
        case .cancel: return "Cancel"
        case .quit: return "Quit"
        case .appearanceModeTitle: return "Appearance"
        case .appearanceModeFollowSystem: return "Auto"
        case .appearanceModeLight: return "Light"
        case .appearanceModeDark: return "Dark"
        case .versionPrefix: return "v"
        case .versionLabelFormat: return "Version %@"
        case .versionFallback: return "Unknown"
        case .aboutInfoSystemTitle: return "Operating System"
        case .aboutInfoMacOSLabel: return "macOS Version"
        case .aboutInfoMacOSValueFormat: return "macOS %d.%d.%d"
        case .aboutInfoProcessorTitle: return "Processor Information"
        case .aboutInfoChipLabel: return "Chip"
        case .aboutInfoDisplayTitle: return "Displays"
        case .aboutInfoUnknownChip: return "Unknown Chip"
        case .aboutInfoUnknownDisplay: return "Unknown"
        case .aboutInfoDisplayGeneric: return "Display"
        case .sidebarIconSizeTitle: return "Sidebar icon size"
        case .sidebarIconSizeLarge: return "Large"
        case .sidebarIconSizeMedium: return "Medium"
        case .settingsSectionPerformance: return "Performance"
        case .settingsSectionTitles: return "App titles"
        case .settingsSectionBackup: return "Backup"
        case .settingsSectionAbout: return "About"
        case .settingsSectionGeneral: return "General"
        case .settingsSectionAppSources: return "Source & Search"
        case .settingsSectionAppearance: return "Appearance"
        case .settingsSectionHiddenApps: return "Hidden apps"
        case .settingsSectionUninstall: return "Uninstaller"
        case .settingsSectionGameController: return "Game controller"
        case .settingsSectionSound: return "Sound"
        case .backgroundStyleTitle: return "Background style"
        case .backgroundStyleOptionBlur: return "Blur"
        case .backgroundStyleOptionGlass: return "Liquid glass"
        case .backgroundStyleOptionUnfiltered: return "No effect"
        case .backgroundStyleUnfilteredMemoryHint: return "Sharper backgrounds may use more memory."
        case .backgroundStyleUnfilteredRequiresImage: return "Enable image backgrounds to select No effect."
        case .backupPlaceholderTitle: return "Backup"
        case .backupChooseFolderButton: return "Choose Backup Folder"
        case .backupCreateButton: return "Create Backup"
        case .backupDeleteSelectedButton: return "Delete Selected"
        case .backupNoFolderSelected: return "No backup folder selected."
        case .backupNoBackupsFound: return "No backups found."
        case .backupImportButton: return "Import"
        case .backupDeleteButton: return "Delete"
        case .backupEstimatedSizeHint: return "Estimated size based on Data.store."
        case .backupDeleteMultipleTitle: return "Delete Backups"
        case .backupDeleteMultipleMessageFormat: return "This will permanently remove %d selected backups."
        case .backupDeleteSingleTitle: return "Delete Backup"
        case .backupDeleteSingleMessage: return "This will permanently remove the selected backup."
        case .gameControllerPlaceholderTitle: return "Controller support"
        case .gameControllerPlaceholderSubtitle: return "Connect a controller and use the D-pad to move between apps. More options are coming soon."
        case .gameControllerToggleTitle: return "Enable controller navigation"
        case .gameControllerStatusDisabled: return "Controller navigation is turned off."
        case .gameControllerStatusNoController: return "No controllers detected yet."
        case .gameControllerStatusConnectedFormat: return "Connected controllers: %@"
        case .gameControllerQuickGuideTitle: return "Quick guide"
        case .gameControllerQuickGuideDirection: return "Use the D-pad or left stick to move between icons."
        case .gameControllerQuickGuideSelect: return "Button A confirms the selection."
        case .gameControllerQuickGuideCancel: return "Button B closes Launchpad."
        case .gameControllerQuickGuideMenuToggle: return "Menu button toggles Launchpad."
        case .gameControllerMenuToggleTitle: return "Use Menu button to toggle Launchpad"
        case .gameControllerMenuToggleSubtitle: return "Works like the global shortcut (open/close)."
        case .soundToggleTitle: return "Enable sound effects"
        case .soundToggleDescription: return "Use macOS system sounds for LaunchMad actions."
        case .soundEventLaunchpadOpen: return "Launchpad opens"
        case .soundEventLaunchpadClose: return "Launchpad closes"
        case .soundEventNavigation: return "Move focus"
        case .soundPreviewButton: return "Preview"
        case .soundOptionNone: return "None"
        case .voiceToggleTitle: return "Enable Voice Over"
        case .voiceToggleDescription: return "Announce the focused app name when using keyboard or controller navigation."
        case .voiceNoteMutualExclusive: return "Voice Over replaces the navigation sound effect."
        case .voiceAnnouncementAppFormat: return "%@"
        case .voiceAnnouncementFolderFormat: return "Folder: %@"
        case .hiddenAppsAddButton: return "Hide application"
        case .hiddenAppsEmptyTitle: return "No hidden apps yet"
        case .hiddenAppsHint: return "Hidden apps disappear from the grid. Remove them here to restore."
        case .hiddenAppsRemoveButton: return "Unhide"
        case .hiddenAppsSearchPlaceholder: return "Filter hidden apps"
        case .notHiddenAppsTitle: return "Not hidden apps"
        case .notHiddenAppsHint: return "Select an application to hide it from LaunchMad."
        case .notHiddenAppsSearchPlaceholder: return "Filter not hidden apps"
        case .contextMenuShowInLayout: return "Show in Layout"
        case .contextMenuShowInFinder: return "Show in Finder"
        case .contextMenuCopyAppPath: return "Copy App Path"
        case .contextMenuPinToFolderQuickLaunchTop: return "Pin to Quick Launch Top"
        case .contextMenuUnpinFromFolderQuickLaunchTop: return "Unpin from Quick Launch Top"
        case .contextMenuRenameFolder: return "Rename Folder"
        case .contextMenuDissolveFolder: return "Dissolve folder"
        case .contextMenuUninstallWithConfiguredTool: return "Uninstall with configured tool"
        case .contextMenuBatchSelectApps: return "Batch Select Apps"
        case .contextMenuFinishBatchSelection: return "Finish Batch Selection"
        case .uninstallSectionDescription: return "Choose a third-party uninstaller app (for example AppCleaner). LaunchMad can open it when needed."
        case .uninstallToolPathLabel: return "Selected uninstaller"
        case .uninstallToolNotConfigured: return "No uninstaller selected."
        case .uninstallToolMissing: return "The selected uninstaller cannot be found. Please choose it again."
        case .uninstallToolChooseButton: return "Choose app…"
        case .uninstallToolClearButton: return "Clear"
        case .uninstallToolOpenButton: return "Open uninstaller"
        case .uninstallToolPanelTitle: return "Select uninstaller app"
        case .performanceModeTitle: return "Performance mode"
        case .performanceModeFull: return "Legacy Engine"
        case .performanceModeLean: return "Next Engine"
        case .performanceModeDescriptionFull: return "Legacy Engine keeps legacy caching for maximum stability."
        case .performanceModeDescriptionLean: return "Next Engine uses less memory for smoother performance."
        case .performanceRendererRecommendation: return "Strongly recommended."
        case .performanceModeRestartHint: return "Switching modes requires a restart to take effect."
        case .performanceModeRestartTitle: return "Restart Required"
        case .performanceModeRestartMessage: return "Please restart LaunchMad to apply the new performance mode."
        case .performanceRendererTitle: return "Next Engine With Core Animation"
        case .performanceRendererBadge: return "Experimental"
        case .performanceRendererSubtitle: return "Requires Next Engine."
        case .performanceRendererWarning: return "Enabled. If you notice issues, turn this off."
        case .performanceCacheTitle: return "Cache status"
        case .performanceCacheStatusValid: return "Cache ready"
        case .performanceCacheStatusInvalid: return "Cache rebuilding"
        case .performanceCacheLastUpdateLabel: return "Last update"
        case .performanceCacheNever: return "Never"
        case .performanceCacheClearButton: return "Clear caches"
        case .performanceCacheIconLabel: return "Icon cache"
        case .performanceCacheAppInfoLabel: return "App info cache"
        case .performanceCacheGridLabel: return "Grid cache"
        case .performanceCacheCountsHint: return "These numbers show item counts, not memory size."
        case .performanceCacheIconsDisabled: return "Disabled in Next Engine"
        case .performanceCacheLeanHint: return "Next Engine skips icon caching to reduce memory use and stutter."
        case .renameSearchPlaceholder: return "Search apps"
        case .customTitlePlaceholder: return "Enter a custom name"
        case .customTitleHint: return "Rename apps here. Custom titles persist across imports and localization changes."
        case .customTitleDefaultFormat: return "Default: %@"
        case .customTitleReset: return "Restore default"
        case .customTitleAddButton: return "Add application"
        case .customTitleAddFromFolder: return "Add application"
        case .loadMore: return "Load more"
        case .customTitleNoResults: return "No matches"
        case .customTitlePickerMessage: return "Select an application to manage its title."
        case .customTitleEdit: return "Edit"
        case .customTitleSave: return "Save"
        case .customTitleCancel: return "Cancel"
        case .customTitleOnly: return "Show only application with edited titles."
        case .loadingApplications: return "Loading applications…"
        case .customIconTitle: return "Application icon"
        case .customIconChoose: return "Choose…"
        case .customIconReset: return "Restore default"
        case .customIconHint: return "PNG/ICNS files at 512×512 work best. Changes apply instantly."
        case .customIconError: return "Could not load the selected image."
        case .pageIndicatorOffsetLabel: return "Page indicator spacing"
        case .folderWindowWidth: return "Folder window width"
        case .folderWindowHeight: return "Folder window height"
        case .folderWindowSizeHint: return "Applies to windowed mode only; classic fullscreen uses a fixed layout."
        case .folderNamePlaceholder: return "Folder Name"
        case .chooseButton: return "Choose"
        case .exportPanelMessage: return "Choose a destination folder to export LaunchMad data"
        case .importPrompt: return "Import"
        case .importPanelMessage: return "Choose a folder previously exported from LaunchMad"
        case .legacyArchivePanelMessage: return "Choose a Launchpad database file (.db)"
        case .importSuccessfulTitle: return "Import Successful"
        case .importFailedTitle: return "Import Failed"
        case .okButton: return "OK"
        case .aboutAttribution: return "LaunchMad is based on LaunchMad by RoversX, which is built on LaunchNow by ggkevinnnn."
        case .aboutLicense: return "Licensed under the GNU General Public License v3.0."
        case .aboutOfflineNotice: return "LaunchMad has no updater, analytics, accounts or online features."
        case .importLegacyDatabaseHint: return "Import a layout from a Launchpad database file (.db). Unzip archives in Finder first."
        case .launcherRowPinnedTitle: return "Pinned"
        case .launcherRowPinnedEmpty: return "Right-click an app and choose Pin to add it here."
        case .launcherRowRecentTitle: return "Last used"
        case .launcherRowRecentEmpty: return "Apps you open from LaunchMad appear here."
        case .launcherRowClearRecents: return "Clear"
        case .launcherRowClearRecentsHelp: return "Clear the Last used list"
        case .contextMenuPinToLauncher: return "Pin"
        case .contextMenuUnpinFromLauncher: return "Unpin"
        case .contextMenuRemoveFromRecents: return "Remove from Last Used"
        }
    }
}
