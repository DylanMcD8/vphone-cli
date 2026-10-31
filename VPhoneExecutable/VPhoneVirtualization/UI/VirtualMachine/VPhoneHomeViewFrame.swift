import AppKit

enum VPhoneHomeViewFrame {
    private static let preference = "homeViewDeviceFrameEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: preference) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: preference) }
    }

    // Measured from the supplied 1699-square PNG's alpha aperture. The screen
    // extends one pixel under the bezel so resampling cannot expose a seam.
    static func geometry(in bounds: CGRect) -> (frame: CGRect, screen: CGRect) {
        let side = min(bounds.width, bounds.height)
        let frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2,
                           width: side, height: side)
        return (frame, frame.insetBy(dx: side * 114 / 1699, dy: side * 114 / 1699))
    }
}

/// The transparent screen opening passes events through to the actual VM
/// view. Opaque bezel pixels catch clicks, so they cannot become edge swipes.
final class VPhoneHomeViewFrameView: NSImageView {
    private let bitmap: NSBitmapImageRep

    init?(resourceBundle: Bundle = .main) {
        guard let url = resourceBundle.url(forResource: "HomeView Device Frame", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              let bitmap = NSBitmapImageRep(data: data)
        else { return nil }
        self.bitmap = bitmap
        super.init(frame: .zero)
        self.image = image
        imageScaling = .scaleAxesIndependently
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local), bounds.width > 0, bounds.height > 0 else { return nil }
        let x = min(bitmap.pixelsWide - 1, max(0, Int(local.x / bounds.width * CGFloat(bitmap.pixelsWide))))
        let y = min(bitmap.pixelsHigh - 1, max(0, Int((1 - local.y / bounds.height) * CGFloat(bitmap.pixelsHigh))))
        return (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
