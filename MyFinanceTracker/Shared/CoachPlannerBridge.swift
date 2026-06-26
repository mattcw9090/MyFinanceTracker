import Foundation

// MARK: - Wire format (must match CoachPlanner's FinanceBridge exactly)

struct ExportEnvelope: Codable {
    let source: String
    let schemaVersion: Int
    let exportedAt: Date
    let sessions: [SessionPayload]
}

struct SessionPayload: Codable {
    let sessionName: String
    let dayOfWeek: String
    let sessionFee: Double
}

// MARK: - App Group bridge

/// Reads the snapshot CoachPlanner writes into the shared App Group container.
/// One-directional and snapshot-style: each CoachPlanner export overwrites the
/// same file, so reading is idempotent (the same file yields the same sessions).
enum CoachPlannerBridge {
    static let appGroupID = "group.com.matthewchew.apptalk"
    static let fileName = "CoachPlannerExport.json"

    enum BridgeError: LocalizedError {
        case appGroupUnavailable
        case noExportFound
        case unreadable

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                return "The shared App Group container is unavailable. Check that the App Group capability is enabled for this app."
            case .noExportFound:
                return "No CoachPlanner export found yet. Open CoachPlanner and tap the money icon to share your sessions."
            case .unreadable:
                return "The CoachPlanner export couldn't be read. It may be from an incompatible version."
            }
        }
    }

    /// URL of the shared export file, or nil if the App Group is not configured.
    static var exportFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// Whether an export file currently exists in the shared container.
    static var hasExport: Bool {
        guard let url = exportFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Reads and decodes the envelope written by CoachPlanner.
    static func readEnvelope() throws -> ExportEnvelope {
        guard let url = exportFileURL else { throw BridgeError.appGroupUnavailable }
        guard let data = try? Data(contentsOf: url) else { throw BridgeError.noExportFound }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(ExportEnvelope.self, from: data)
        } catch {
            throw BridgeError.unreadable
        }
    }

    /// Reads the envelope and validates each session into the app's import model,
    /// applying the same rules as the manual paste flow.
    static func readSessions() throws -> (envelope: ExportEnvelope, sessions: [ImportedSession]) {
        let envelope = try readEnvelope()
        let sessions = try envelope.sessions.map {
            try SessionImportParser.validatedSession(
                dayOfWeek: $0.dayOfWeek,
                sessionFee: $0.sessionFee,
                sessionName: $0.sessionName
            )
        }
        return (envelope, sessions)
    }
}
