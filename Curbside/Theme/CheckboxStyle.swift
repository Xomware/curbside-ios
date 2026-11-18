import SwiftUI

/// The mockup's capture checkbox: an ink-ruled square, green with a white check when on. 44 pt to tap.
struct CheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(configuration.isOn ? Palette.signGreen : Palette.surface)
                .strokeBorder(configuration.isOn ? Palette.signWhite : Palette.ink, lineWidth: configuration.isOn ? 1.5 : 2.5)
                .overlay {
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Palette.signWhite)
                    }
                }
                .frame(width: 28, height: 28)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(SignPressStyle())
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
