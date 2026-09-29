import NetTrace
import SwiftUI

@main
struct NetTraceDemoApp: App {
    init() {
        // Screenshot scenes show fixed sample data and never touch the network.
        if ScreenshotScene.current == nil {
            #if DEBUG
            NetTrace.enable(options: NetTraceOptions(redactedHeaders: Redactor.defaultHeaders.union(["X-Api-Key"])))
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            if let scene = ScreenshotScene.current {
                scene.content
            } else {
                ContentView()
                    #if DEBUG
                    .netTrace(.all)
                    #endif
            }
        }
    }
}
