import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// How ``SwiftUI/View/netTrace(_:isEnabled:store:)`` opens the inspector.
public struct NetTraceTrigger: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Shaking the device (Device > Shake in the simulator). iOS only.
    public static let shake = NetTraceTrigger(rawValue: 1 << 0)
    /// A floating button in the bottom trailing corner with the request count.
    public static let floatingButton = NetTraceTrigger(rawValue: 1 << 1)
    /// Both.
    public static let all: NetTraceTrigger = [.shake, .floatingButton]
}

extension View {
    /// Opens the inspector as a sheet on a shake, from a floating button, or both.
    ///
    /// ```swift
    /// ContentView()
    ///     #if DEBUG
    ///     .netTrace([.shake, .floatingButton])
    ///     #endif
    /// ```
    public func netTrace(
        _ triggers: NetTraceTrigger = .shake,
        isEnabled: Bool = true,
        store: NetTraceStore = NetTrace.store
    ) -> some View {
        modifier(NetTracePresenter(triggers: triggers, isEnabled: isEnabled, store: store))
    }

    /// Shows the inspector as a sheet while `isPresented` is true, for your own trigger.
    public func netTrace(isPresented: Binding<Bool>, store: NetTraceStore = NetTrace.store) -> some View {
        sheet(isPresented: isPresented) {
            NetTraceSheet(store: store)
        }
    }
}

struct NetTracePresenter: ViewModifier {
    let triggers: NetTraceTrigger
    let isEnabled: Bool
    let store: NetTraceStore

    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if isEnabled && triggers.contains(.floatingButton) {
                    NetTraceFloatingButton(store: store) {
                        isPresented = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
                }
            }
            .background {
                if isEnabled && triggers.contains(.shake) {
                    ShakeListener {
                        isPresented = true
                    }
                }
            }
            .sheet(isPresented: $isPresented) {
                NetTraceSheet(store: store)
            }
    }
}

struct NetTraceSheet: View {
    let store: NetTraceStore

    var body: some View {
        NetTraceView(store: store, showsDoneButton: true)
            #if os(macOS)
            .frame(minWidth: 560, minHeight: 640)
            #endif
    }
}

/// A round glass button with the number of recorded requests.
struct NetTraceFloatingButton: View {
    @State private var inspector: NetTraceInspector
    private let action: () -> Void

    init(store: NetTraceStore, action: @escaping () -> Void) {
        _inspector = State(initialValue: NetTraceInspector(store: store))
        self.action = action
    }

    var body: some View {
        let count = inspector.records.count
        let hasErrors = inspector.records.contains {
            $0.category == .clientError || $0.category == .serverError || $0.category == .failed
        }

        Button(action: action) {
            Image(systemName: "network")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .netTraceGlass(in: Circle())
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(hasErrors ? Color.red : Color.accentColor, in: Capsule())
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityLabel("Network inspector")
        .accessibilityValue("\(count) requests")
    }
}

/// Calls `action` when the device is shaken. Does nothing where there is no UIKit.
struct ShakeListener: View {
    let action: () -> Void

    var body: some View {
        #if canImport(UIKit)
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .netTraceDeviceDidShake)) { _ in
                action()
            }
        #else
        Color.clear
        #endif
    }
}

#if canImport(UIKit)
extension Notification.Name {
    static let netTraceDeviceDidShake = Notification.Name("io.github.halilozel1903.NetTrace.deviceDidShake")
}

// Shake events travel up the responder chain to the window. Posting a notification here
// lets any SwiftUI view react; `super` keeps the event going to the rest of the chain.
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .netTraceDeviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
#endif
