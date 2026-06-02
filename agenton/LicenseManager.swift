import Foundation
import Observation

/// Trial + license state for Agent On.
///
/// Trial logic: first launch date is persisted in UserDefaults; after
/// `trialDays` the app enters `.trialExpired` and the Enable button is locked
/// until a valid Gumroad license key is activated.
///
/// License validation: POSTs to `https://api.gumroad.com/v2/licenses/verify`.
/// On success the key is cached in UserDefaults; we re-validate every
/// `revalidateInterval` so refunded/revoked keys eventually lose access.
@Observable
final class LicenseManager {
    enum Status: Equatable {
        case trial(daysRemaining: Int)
        case trialExpired
        case validating
        case licensed
        case invalid(reason: String)
    }

    // MARK: - Configuration

    /// Gumroad product ID — shown on Content tab → "Use your product ID to verify licenses through the API."
    static let gumroadProductID = "i3Op2HFBClCrpnbrFBroIQ=="

    /// Public purchase page URL.
    static let purchaseURL = URL(string: "https://shipanoo.gumroad.com/l/agenton")!

    private let trialDays = 7
    private let revalidateInterval: TimeInterval = 7 * 24 * 3600

    // MARK: - Persistent keys

    private let firstLaunchKey = "AgentOn.firstLaunchDate"
    private let licenseKeyKey = "AgentOn.licenseKey"
    private let licenseValidatedAtKey = "AgentOn.licenseValidatedAt"

    // MARK: - Observable state

    var status: Status = .trial(daysRemaining: 7)

    var canEnable: Bool { true }

    // MARK: - Init

    init() {
        status = .licensed
    }

    // MARK: - Public

    /// No-op in free mode — app is always licensed.
    func refresh() {
        status = .licensed
    }

    /// Validate and activate a Gumroad license key.
    func activate(key rawKey: String) async {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            status = .invalid(reason: "License key is empty")
            return
        }

        status = .validating
        do {
            let success = try await verify(key: key, incrementUses: true)
            if success {
                UserDefaults.standard.set(key, forKey: licenseKeyKey)
                UserDefaults.standard.set(Date(), forKey: licenseValidatedAtKey)
                status = .licensed
            } else {
                status = .invalid(reason: "License key not recognized")
            }
        } catch {
            status = .invalid(reason: "Network error — \(error.localizedDescription)")
        }
    }

    /// Clear stored license (for testing / "deactivate this Mac").
    func deactivate() {
        UserDefaults.standard.removeObject(forKey: licenseKeyKey)
        UserDefaults.standard.removeObject(forKey: licenseValidatedAtKey)
        refresh()
    }

    // MARK: - Private

    private func silentlyRevalidate(key: String) async {
        guard let ok = try? await verify(key: key, incrementUses: false) else { return }
        if ok {
            UserDefaults.standard.set(Date(), forKey: licenseValidatedAtKey)
        } else {
            // Key was revoked or refunded — fall back to expired state.
            UserDefaults.standard.removeObject(forKey: licenseKeyKey)
            UserDefaults.standard.removeObject(forKey: licenseValidatedAtKey)
            refresh()
        }
    }

    private func verify(key: String, incrementUses: Bool) async throws -> Bool {
        var req = URLRequest(url: URL(string: "https://api.gumroad.com/v2/licenses/verify")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // URL-encode the product ID (contains "==" which must be percent-escaped)
        let encodedID = Self.gumroadProductID
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? Self.gumroadProductID
        let body = "product_id=\(encodedID)" +
                   "&license_key=\(key)" +
                   "&increment_uses_count=\(incrementUses ? "true" : "false")"
        req.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return (json["success"] as? Bool) == true
    }

    private func recordFirstLaunchIfNeeded() {
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    private func daysSinceFirstLaunch() -> Int {
        let first = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date ?? Date()
        return Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
    }
}
