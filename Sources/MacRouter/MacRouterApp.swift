import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    let processManager = RouterProcessManager()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = PopoverContentView(processManager: processManager)
        
        popover.contentSize = NSSize(width: 320, height: 455)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: contentView)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = makeMaterialRouteIcon(size: NSSize(width: 18, height: 18))
            button.title = ""
            button.imagePosition = .imageOnly
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover(sender)
        } else {
            button.window?.layoutIfNeeded()
            let anchorRect = NSRect(x: 0, y: 0, width: button.bounds.width, height: button.bounds.height)
            popover.show(relativeTo: anchorRect, of: button, preferredEdge: .minY)
            
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
            
            // Global click monitor to dismiss on outside click
            if eventMonitor == nil {
                eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                    Task { @MainActor in
                        self?.closePopover(nil)
                    }
                }
            }
        }
    }

    func closePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        }
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

@main
struct MacRouterApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
