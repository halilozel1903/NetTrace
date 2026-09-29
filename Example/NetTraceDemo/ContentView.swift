import NetTrace
import SwiftUI

/// A few buttons that send real requests, so there is something to inspect.
/// Shake the device (Device > Shake in the simulator) or tap the floating button to open NetTrace.
struct ContentView: View {
    /// A custom session: its configuration went through NetTrace, so it is recorded too.
    private static let session = URLSession(configuration: NetTrace.configuration())

    @State private var results: [DemoRequest.ID: String] = [:]
    @State private var inFlight: Set<DemoRequest.ID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(DemoRequest.all) { demo in
                        Button {
                            Task { await send(demo) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: demo.systemImage)
                                    .frame(width: 28)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(demo.title)
                                        .foregroundStyle(.primary)
                                    Text("\(demo.method) \(demo.url.host() ?? "")\(demo.url.path())")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if inFlight.contains(demo.id) {
                                    ProgressView()
                                } else if let result = results[demo.id] {
                                    Text(result)
                                        .font(.callout.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Send a request")
                } footer: {
                    Text("Requests go to httpbin.org and jsonplaceholder.typicode.com. Shake the device or tap the round button to open the inspector.")
                }

                Section {
                    Button("Add Sample Requests", systemImage: "tray.and.arrow.down") {
                        for record in SampleData.makeRecords(stableIDs: false) {
                            NetTrace.store.insert(record)
                        }
                    }
                    Button("Clear Recorded Requests", systemImage: "trash", role: .destructive) {
                        NetTrace.clear()
                        results = [:]
                    }
                } footer: {
                    Text("Sample requests work offline: they are added to the store directly.")
                }
            }
            .navigationTitle("NetTrace Demo")
        }
    }

    private func send(_ demo: DemoRequest) async {
        inFlight.insert(demo.id)
        defer { inFlight.remove(demo.id) }

        var request = URLRequest(url: demo.url)
        request.httpMethod = demo.method
        request.httpBody = demo.body.map { Data($0.utf8) }
        for (name, value) in demo.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        do {
            let (_, response) = try await Self.session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            results[demo.id] = String(code)
        } catch {
            results[demo.id] = "Error"
        }
    }
}

struct DemoRequest: Identifiable {
    let title: String
    let systemImage: String
    let method: String
    let url: URL
    var headers: [String: String] = [:]
    var body: String?

    var id: String { title }

    static let all: [DemoRequest] = [
        DemoRequest(title: "Fetch a post", systemImage: "doc.text", method: "GET",
                    url: URL(string: "https://jsonplaceholder.typicode.com/posts/1")!),
        DemoRequest(title: "Create a post", systemImage: "square.and.pencil", method: "POST",
                    url: URL(string: "https://jsonplaceholder.typicode.com/posts")!,
                    headers: ["Content-Type": "application/json; charset=utf-8"],
                    body: #"{"title":"Hello","body":"Sent from NetTrace Demo","userId":1}"#),
        DemoRequest(title: "Authorized request", systemImage: "key", method: "GET",
                    url: URL(string: "https://httpbin.org/bearer")!,
                    headers: ["Authorization": "Bearer demo-token", "X-Api-Key": "demo-key"]),
        DemoRequest(title: "Not found", systemImage: "questionmark.folder", method: "GET",
                    url: URL(string: "https://httpbin.org/status/404")!),
        DemoRequest(title: "Server error", systemImage: "exclamationmark.triangle", method: "POST",
                    url: URL(string: "https://httpbin.org/status/500")!),
        DemoRequest(title: "Slow response", systemImage: "tortoise", method: "GET",
                    url: URL(string: "https://httpbin.org/delay/2")!),
        DemoRequest(title: "Image download", systemImage: "photo", method: "GET",
                    url: URL(string: "https://httpbin.org/image/jpeg")!),
    ]
}
