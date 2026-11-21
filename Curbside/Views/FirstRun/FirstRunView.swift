import SwiftUI

/// Everything after the display name, one step at a time. `done` runs once the model reaches `.done`.
struct FirstRunView: View {
    let model: FirstRunModel
    let done: () -> Void

    var body: some View {
        content
            .onChange(of: model.step) { _, step in
                if step == .done { done() }
            }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .home:
            HomeStep(model: model)
        case .people:
            PeopleStep(model: model)
        case .tour:
            TourView(done: model.finishTour)
        case .done:
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .accessibilityLabel("Opening your street")
        }
    }
}

/// "STEP 2 OF 3" over each first-run screen. The tour isn't counted: it can be skipped and only shows once.
struct StepLabel: View {
    let number: Int

    var body: some View {
        Text("STEP \(number) OF 3")
            .font(CurbsideFont.label)
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityLabel("Step \(number) of 3")
    }
}

/// A quiet way out of a step, under its main sign.
struct SkipButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(CurbsideFont.detail)
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .buttonStyle(SignPressStyle())
    }
}
