import SwiftUI

struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        // 7.6 / 28: the corner cut of a regular octagon, from the mockup's stop sign path.
        let cut = min(rect.width, rect.height) * 0.2714
        return Path { path in
            path.addLines([
                CGPoint(x: rect.minX + cut, y: rect.minY),
                CGPoint(x: rect.maxX - cut, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + cut),
                CGPoint(x: rect.maxX, y: rect.maxY - cut),
                CGPoint(x: rect.maxX - cut, y: rect.maxY),
                CGPoint(x: rect.minX + cut, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY - cut),
                CGPoint(x: rect.minX, y: rect.minY + cut),
            ])
            path.closeSubpath()
        }
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addLines([
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY),
            ])
            path.closeSubpath()
        }
    }
}

/// The no-passing-zone pennant: square edge on the left, point on the right.
struct Pennant: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addLines([
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.minX, y: rect.maxY),
            ])
            path.closeSubpath()
        }
    }
}

extension View {
    /// A rectangular sign: solid face, an inset rule line, and the hard drop shadow of a sign on a post.
    func signFace(_ fill: Color, rule: Color, cornerRadius: CGFloat = 8) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .inset(by: 2)
                        .strokeBorder(rule, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.25), radius: 0, y: 3)
        }
    }
}
