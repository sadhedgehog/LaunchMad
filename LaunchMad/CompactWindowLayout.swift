import CoreGraphics

enum CompactWindowLayout {
    private static let aspectRatio: CGFloat = 4.0 / 3.0

    // Window width as a fraction of the screen's reference width.
    static let defaultSizeFraction: Double = 0.4
    static let sizeFractionRange: ClosedRange<Double> = 0.3...1.0

    static func normalizedSizeFraction(_ value: Double) -> Double {
        guard value.isFinite else { return defaultSizeFraction }
        return min(max(value, sizeFractionRange.lowerBound), sizeFractionRange.upperBound)
    }

    // Zero means automatic. Custom limits retain the normal settings minimum;
    // only the available screen area may require a smaller window.
    static func normalizedMaximumWidth(_ value: Int) -> Int {
        value <= 0 ? 0 : max(800, value)
    }

    static func normalizedMaximumHeight(_ value: Int) -> Int {
        value <= 0 ? 0 : max(600, value)
    }

    static func minimumSize(in visibleFrame: CGRect, preferred: CGSize) -> CGSize {
        let preferredWidth = max(preferred.width, preferred.height * aspectRatio)
        let width = min(preferredWidth, fittingWidth(in: visibleFrame))
        return CGSize(width: width, height: width / aspectRatio)
    }

    static func frame(in visibleFrame: CGRect, minimum: CGSize,
                      maximumWidth: Int = 0, maximumHeight: Int = 0,
                      sizeFraction: Double = defaultSizeFraction) -> CGRect {
        // Extra ultrawide space must not increase the height of a 4:3 launcher.
        let referenceWidth = min(visibleFrame.width, visibleFrame.height * 16.0 / 9.0)
        let minimumWidth = minimumSize(in: visibleFrame, preferred: minimum).width
        let fraction = CGFloat(normalizedSizeFraction(sizeFraction))
        var width = min(max(referenceWidth * fraction, minimumWidth), fittingWidth(in: visibleFrame))
        let widthLimit = normalizedMaximumWidth(maximumWidth)
        let heightLimit = normalizedMaximumHeight(maximumHeight)
        if widthLimit > 0 { width = min(width, CGFloat(widthLimit)) }
        if heightLimit > 0 { width = min(width, CGFloat(heightLimit) * aspectRatio) }
        let height = width / aspectRatio
        return CGRect(x: visibleFrame.midX - width / 2,
                      y: visibleFrame.midY - height / 2,
                      width: width, height: height)
    }

    private static func fittingWidth(in frame: CGRect) -> CGFloat {
        max(0, min(frame.width, frame.height * aspectRatio))
    }
}
