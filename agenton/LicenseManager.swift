import Foundation
import Observation

/// Manages app enablement state. The app is free — all features are always available.
@Observable
final class LicenseManager {
    enum Status: Equatable {
        case licensed
    }

    var status: Status = .licensed
    var canEnable: Bool { true }

    func refresh() {}
}
