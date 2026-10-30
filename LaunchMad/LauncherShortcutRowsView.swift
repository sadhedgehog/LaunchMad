import AppKit
import SwiftUI

enum LauncherShortcutRow: Equatable {
    case pinned
    case recent
}

/// Keyboard focus inside the Pinned / Last used rows.
struct LauncherShortcutFocus: Equatable {
    var row: LauncherShortcutRow
    var index: Int
}

/// The two labeled rows shown above the launcher grid: "Pinned" (user ordered)
/// and "Last used" (most recent successful launches through LaunchMad).
struct LauncherShortcutRowsView: View {
    @ObservedObject var appStore: AppStore
    let pinnedApps: [AppInfo]
    let recentApps: [AppInfo]
    let iconSize: CGFloat
    let focus: LauncherShortcutFocus?
    let onLaunch: (AppInfo) -> Void

    @State private var dropTargetPath: String?

    private var cellWidth: CGFloat { max(iconSize + 28, 64) }
    private var labelFontSize: CGFloat { min(CGFloat(appStore.iconLabelFontSize), 11) }
    private var rowHeight: CGFloat {
        iconSize + 16 + (appStore.showLabels ? labelFontSize + 8 : 0)
    }
    private let titleColumnWidth: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row(.pinned,
                title: appStore.localized(.launcherRowPinnedTitle),
                apps: pinnedApps,
                emptyText: appStore.localized(.launcherRowPinnedEmpty))
            row(.recent,
                title: appStore.localized(.launcherRowRecentTitle),
                apps: recentApps,
                emptyText: appStore.localized(.launcherRowRecentEmpty))
        }
    }

    @ViewBuilder
    private func row(_ kind: LauncherShortcutRow, title: String, apps: [AppInfo], emptyText: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if kind == .recent, !apps.isEmpty {
                    Button(appStore.localized(.launcherRowClearRecents)) {
                        appStore.clearRecentApps()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .help(appStore.localized(.launcherRowClearRecentsHelp))
                }
            }
            .frame(width: titleColumnWidth, alignment: .leading)

            if apps.isEmpty {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                                cell(app: app, index: index, kind: kind)
                                    .id(cellID(kind, app))
                            }
                        }
                    }
                    .onChange(of: focus) { _, newFocus in
                        guard let newFocus, newFocus.row == kind, apps.indices.contains(newFocus.index) else { return }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(cellID(kind, apps[newFocus.index]))
                        }
                    }
                }
            }
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func cellID(_ kind: LauncherShortcutRow, _ app: AppInfo) -> String {
        (kind == .pinned ? "pinned:" : "recent:") + app.id
    }

    @ViewBuilder
    private func cell(app: AppInfo, index: Int, kind: LauncherShortcutRow) -> some View {
        let button = LaunchpadItemButton(
            item: .app(app),
            iconSize: iconSize,
            labelWidth: cellWidth - 8,
            isSelected: focus == LauncherShortcutFocus(row: kind, index: index),
            showLabel: appStore.showLabels,
            labelFontSize: labelFontSize,
            labelFontWeight: appStore.iconLabelFontWeightValue,
            hoverMagnificationEnabled: appStore.enableHoverMagnification,
            hoverMagnificationScale: CGFloat(appStore.hoverMagnificationScale),
            activePressEffectEnabled: appStore.enableActivePressEffect,
            activePressScale: CGFloat(appStore.activePressScale),
            onTap: { onLaunch(app) }
        )
        .frame(width: cellWidth)
        .launchNextHideAppContextMenu(app: app,
                                      appStore: appStore,
                                      alwaysShowInLayout: true,
                                      isRecentRow: kind == .recent)
        .accessibilityLabel(app.name)

        if kind == .pinned, !appStore.isLayoutLocked {
            // Drag a pinned app onto another pinned app to reorder the row.
            button
                .overlay(alignment: .leading) {
                    if dropTargetPath == app.url.path {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: iconSize)
                            .offset(x: -2)
                    }
                }
                .draggable(PinnedAppDragPayload.encode(app.url.path))
                .dropDestination(for: String.self) { payloads, _ in
                    guard let path = payloads.first.flatMap(PinnedAppDragPayload.decode),
                          path != app.url.path else { return false }
                    appStore.movePinnedApp(path: path, before: app)
                    return true
                } isTargeted: { targeted in
                    if targeted {
                        dropTargetPath = app.url.path
                    } else if dropTargetPath == app.url.path {
                        dropTargetPath = nil
                    }
                }
        } else {
            button
        }
    }
}
