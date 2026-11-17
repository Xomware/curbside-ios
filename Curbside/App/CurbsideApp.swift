import SwiftUI

@main
struct CurbsideApp: App {
    @State private var model: RootModel = {
        #if DEBUG
        if Demo.scenario != nil { return Demo.rootModel() }
        #endif
        return RootModel.live()
    }()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
