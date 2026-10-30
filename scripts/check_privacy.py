#!/usr/bin/env python3
"""Static privacy scan for LaunchMad's application sources.

Fails (exit 1) when app code contains a pattern associated with network access,
external processes, logging, local servers, notifications, cloud sync or
telemetry. It is a guard against regressions, not proof of runtime behaviour:
see PRIVACY.md for what is and is not covered.

Usage: python3 scripts/check_privacy.py [repo-root]
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent)
SOURCE_DIRS = ["LaunchMad", "LaunchMadContextMenuCore", "LaunchMadWallpaperCore"]
EXTENSIONS = {".swift", ".m", ".h", ".c"}

# (name, regex) pairs that must not appear in application code.
FORBIDDEN = [
    ("network: URLSession", r"\bURLSession\b"),
    ("network: Network framework", r"^\s*import\s+Network\b|\bNWConnection\b|\bNWListener\b|\bNWBrowser\b"),
    ("network: CFNetwork/streams", r"\bCFStreamCreatePairWithSocket|\bCFSocketCreate|\bCFReadStreamCreateWithFTPURL"),
    ("network: web view", r"^\s*import\s+(WebKit|SafariServices)\b|\bWKWebView\b|\bSFSafariViewController\b"),
    ("network: web URL literal", r"\"https?://"),
    ("network: SwiftUI Link / openURL", r"\bLink\s*\(\s*destination:|@Environment\(\\\.openURL\)"),
    ("network: mail links", r"mailto:"),
    ("socket server/client", r"(?<![\w.])(?<!func )(socket|bind|listen|accept|connect)\s*\(|sockaddr_un|AF_UNIX|AF_INET"),
    ("XPC / distributed objects", r"\bNSXPCListener\b|\bNSXPCConnection\b|\bNSConnection\b|\bCFMessagePort"),
    ("external process", r"(?<![\w.])Process\s*\(|\bNSTask\b|\bposix_spawn|(?<![\w.])system\s*\(|(?<![\w.])popen\s*\(|\bexecv"),
    ("AppleScript", r"\bNSAppleScript\b|\bosascript\b|\bOSAScript\b"),
    ("Terminal automation", r"com\.apple\.Terminal|\bTerminal\.app\b|\.command\b\""),
    ("logging: print", r"(?<![\w.])print\s*\("),
    ("logging: NSLog", r"(?<!define )\bNSLog\s*\("),
    ("logging: os_log / Logger", r"\bos_log\b|\bos_signpost\b|\bLogger\s*\(|\bOSLog\b"),
    ("logging: debugPrint/dump", r"(?<![\w.])(debugPrint|dump)\s*\("),
    ("logging: log file paths", r"Library/Logs|\.log\""),
    ("notifications", r"\bUserNotifications\b|\bUNUserNotificationCenter\b|\bNSUserNotification\b"),
    ("cloud: CloudKit / ubiquity", r"^\s*import\s+CloudKit\b|\bCKContainer\b|\bNSUbiquitousKeyValueStore\b|ubiquityIdentityToken|forUbiquityContainerIdentifier"),
    ("telemetry / crash reporting", r"\bMetricKit\b|\bMXMetricManager\b|Crashlytics|Sentry|Firebase|Mixpanel|Amplitude|AppCenter|TelemetryDeck|Bugsnag"),
    ("updater", r"\bSparkle\b|\bSUUpdater\b|releases/latest|api\.github\.com|SwiftUpdater"),
    ("quarantine removal", r"com\.apple\.quarantine|\bxattr\b"),
    ("shell profile edits", r"\.zprofile|\.zshrc|\.bash_profile|/usr/local/bin|/opt/homebrew/bin"),
]

# Exact (file, substring) pairs reviewed as safe.
ALLOWED = {
    # XMP namespace identifier inside image metadata; never fetched.
    ("LaunchMadWallpaperCore/WallpaperImageRenderer.swift", "http://ns.apple.com/namespace/1.0/"),
}

MODEL_CONFIGURATION = re.compile(r"ModelConfiguration\s*\(")


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"(?m)//.*$", "", text)


def model_configuration_calls(text: str):
    for match in MODEL_CONFIGURATION.finditer(text):
        depth, i = 0, match.end() - 1
        while i < len(text):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield match.start(), text[match.start():i + 1]


def main() -> int:
    findings = []
    files = [p for d in SOURCE_DIRS for p in sorted((ROOT / d).rglob("*")) if p.suffix in EXTENSIONS]
    if not files:
        print(f"No sources found under {ROOT}", file=sys.stderr)
        return 2

    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        code = strip_comments(path.read_text(encoding="utf-8"))
        # Vendored Objective-C files may compile NSLog out with a no-op macro.
        nslog_disabled = re.search(r"^#define NSLog\(\.\.\.\) \(\(void\)0\)$", code, re.M) is not None
        lines = code.split("\n")
        for number, line in enumerate(lines, 1):
            for name, pattern in FORBIDDEN:
                if name == "logging: NSLog" and nslog_disabled:
                    continue
                if re.search(pattern, line):
                    if any(rel == f and s in line for f, s in ALLOWED):
                        continue
                    findings.append(f"{rel}:{number}: {name}: {line.strip()[:120]}")
        if path.suffix == ".swift":
            for offset, call in model_configuration_calls(code):
                if "cloudKitDatabase: .none" not in call:
                    number = code.count("\n", 0, offset) + 1
                    findings.append(f"{rel}:{number}: SwiftData configuration without cloudKitDatabase: .none")

    if findings:
        print("Privacy scan FAILED:")
        for finding in findings:
            print("  " + finding)
        return 1
    print(f"Privacy scan passed: {len(files)} source files, {len(FORBIDDEN)} rule groups, "
          "every ModelConfiguration disables CloudKit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
