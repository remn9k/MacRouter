import SwiftUI
import AppKit

public struct StatusIconView: View {
    let status: RouterStatus

    public var body: some View {
        Image(nsImage: makeMaterialRouteIcon())
    }
}

public func makeMaterialRouteIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
    let image = NSImage(size: size, flipped: false) { rect in
        let scale = rect.width / 18.0
        let path = NSBezierPath()
        
        // Start Node Circle (Bottom-Left)
        let startOval = NSBezierPath(ovalIn: NSRect(x: 2.5 * scale, y: 3.0 * scale, width: 4.5 * scale, height: 4.5 * scale))
        NSColor.black.setStroke()
        startOval.lineWidth = 1.6 * scale
        startOval.stroke()
        
        // End Node Circle (Top-Right)
        let endOval = NSBezierPath(ovalIn: NSRect(x: 11.0 * scale, y: 10.5 * scale, width: 4.5 * scale, height: 4.5 * scale))
        endOval.lineWidth = 1.6 * scale
        endOval.stroke()
        
        // Curved Route line
        path.move(to: NSPoint(x: 7.0 * scale, y: 5.25 * scale))
        path.curve(to: NSPoint(x: 11.0 * scale, y: 12.75 * scale),
                   controlPoint1: NSPoint(x: 11.0 * scale, y: 5.25 * scale),
                   controlPoint2: NSPoint(x: 7.0 * scale, y: 12.75 * scale))
        path.lineWidth = 1.6 * scale
        path.stroke()
        
        // Direction arrowhead
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 12.5 * scale, y: 15.5 * scale))
        arrow.line(to: NSPoint(x: 15.5 * scale, y: 12.75 * scale))
        arrow.line(to: NSPoint(x: 12.5 * scale, y: 10.0 * scale))
        arrow.lineWidth = 1.4 * scale
        arrow.stroke()
        
        return true
    }
    image.isTemplate = true
    return image
}
