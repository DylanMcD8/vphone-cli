import AppKit

@main
struct HomeViewFrameTests {
    @MainActor
    static func main() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let resources = temporary.appendingPathComponent("FrameTest.bundle/Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: CommandLine.arguments[1],
                                        toPath: resources.appendingPathComponent("HomeView Device Frame.png").path)
        let bundle = Bundle(path: resources.deletingLastPathComponent().deletingLastPathComponent().path)!
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        for size in [CGSize(width: 1699, height: 1699), CGSize(width: 450, height: 450),
                     CGSize(width: 1200, height: 800), CGSize(width: 600, height: 1000)] {
            let scene = NSView(frame: CGRect(origin: .zero, size: size))
            let geometry = VPhoneHomeViewFrame.geometry(in: scene.bounds)
            let display = NSView(frame: geometry.screen)
            scene.addSubview(display)
            let bezel = VPhoneHomeViewFrameView(resourceBundle: bundle)!
            bezel.frame = geometry.frame
            scene.addSubview(bezel)
            check(abs(geometry.screen.width / geometry.frame.width - 1471.0 / 1699) < 0.000001,
                  "Aperture changed relative to supplied PNG")
            check(geometry.screen.width == geometry.screen.height, "Display must not stretch")
            let center = CGPoint(x: geometry.screen.midX, y: geometry.screen.midY)
            check(scene.hitTest(center) === display, "Screen center must reach guest")
            let border = CGPoint(x: geometry.frame.minX + geometry.frame.width * 0.03,
                                 y: geometry.frame.midY)
            check(scene.hitTest(border) === bezel, "Bezel must intercept edge gestures")
            let camera = CGPoint(x: geometry.frame.midX, y: geometry.frame.maxY - geometry.frame.height * 0.03)
            check(scene.hitTest(camera) === bezel, "Camera border must intercept clicks")
            check(bezel.hitTest(CGPoint(x: geometry.frame.minX + 1, y: geometry.frame.minY + 1)) == nil,
                  "Transparent outer corner must not catch input")
            let mapping = VPhoneDisplayGeometry(viewBounds: display.bounds,
                                               displaySize: CGSize(width: 1088, height: 1088), isFlipped: false)
            for normalized in [CGPoint(x: 0.25, y: 0.7), CGPoint(x: 0.5, y: 0.99), CGPoint(x: 0.9, y: 0.5)] {
                let host = CGPoint(x: geometry.screen.minX + normalized.x * geometry.screen.width,
                                   y: geometry.screen.maxY - normalized.y * geometry.screen.height)
                let mapped = mapping.normalizedPoint(display.convert(host, from: scene))
                check(abs(mapped.x - normalized.x) < 0.000001 && abs(mapped.y - normalized.y) < 0.000001,
                      "Resized framed input must map to the same guest coordinate")
            }
        }
        _ = NSApplication.shared
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 544, height: 544),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 544, height: 544))
        window.toolbar = NSToolbar(identifier: "toolbar-visibility-test")
        window.toolbarStyle = .unified
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = NSView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        accessory.layoutAttribute = .right
        window.addTitlebarAccessoryViewController(accessory)
        let size = window.contentView!.bounds.size
        for _ in 0..<3 {
            VPhoneHomeViewToolbar.setVisible(false, in: window)
            check(window.contentView!.bounds.size == size, "Hiding toolbar must preserve display size")
            check(window.frame.height == size.height, "Hidden toolbar must leave no strip above the display")
            check(window.standardWindowButton(.closeButton)!.superview!.isHidden,
                  "Titlebar and its custom background must be hidden")
            check(accessory.isHidden, "Home accessory must hide with the toolbar")
            check(window.canBecomeKey, "Hidden toolbar must not break keyboard focus")
            VPhoneHomeViewToolbar.setVisible(true, in: window)
            check(window.contentView!.bounds.size == size, "Restoring toolbar must preserve display size")
            check(window.toolbar!.isVisible && !accessory.isHidden, "Toolbar and Home accessory must restore")
            check(!window.standardWindowButton(.closeButton)!.superview!.isHidden,
                  "Window buttons and custom title must restore")
        }
        window.close()
        print("Passed \(checks) HomeView frame, input, and toolbar checks")
    }
}
