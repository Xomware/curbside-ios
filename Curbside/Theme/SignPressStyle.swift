import SwiftUI

/// Press feedback for sign buttons: a short push into the post plus a haptic.
struct SignPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pressed(configuration: configuration)
    }

    private struct Pressed: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
                .opacity(configuration.isPressed && reduceMotion ? 0.8 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
                .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
        }
    }
}
