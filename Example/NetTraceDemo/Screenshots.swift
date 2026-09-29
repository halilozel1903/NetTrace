import NetTrace
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    /// The request list with a mix of methods and 2xx / 3xx / 4xx / 5xx / failed requests.
    case list
    /// The Response tab of a JSON product request.
    case detail

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    @MainActor
    @ViewBuilder
    var content: some View {
        switch self {
        case .list:
            NetTraceView(store: SampleData.makeStore())
        case .detail:
            NavigationStack {
                RequestDetailView(record: SampleData.productDetail, initialTab: .response)
            }
        }
    }
}
