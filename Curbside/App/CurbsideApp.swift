import SwiftUI

@main
struct CurbsideApp: App {
    @State private var model = RootModel.live()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
