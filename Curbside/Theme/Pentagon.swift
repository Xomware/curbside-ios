import SwiftUI

/// The school-zone sign: a house shape, point up.
struct Pentagon: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addLines([
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.36),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.36),
            ])
            path.closeSubpath()
        }
    }
}
