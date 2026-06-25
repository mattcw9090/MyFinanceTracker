import Foundation

struct ImportedSession: Identifiable, Equatable {
    let id = UUID()
    let dayOfWeek: String
    let sessionFee: Double
    let sessionName: String
}

enum SessionImportError: LocalizedError, Equatable {
    case emptyInput
    case invalidJSON
    case noSessions
    case invalidDay(String)
    case invalidFee(String)
    case emptySessionName

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Paste a JSON array of sessions before importing."
        case .invalidJSON:
            return "That JSON could not be read. Check that it is a valid array of session objects."
        case .noSessions:
            return "No sessions were found in the JSON."
        case .invalidDay(let day):
            return "\"\(day)\" is not a valid day. Use Monday through Sunday."
        case .invalidFee(let sessionName):
            return "\"\(sessionName)\" needs a sessionFee greater than 0."
        case .emptySessionName:
            return "Every session needs a non-empty sessionName."
        }
    }
}

enum SessionImportParser {
    private struct RawSession: Decodable {
        let dayOfWeek: String
        let sessionFee: Double
        let sessionName: String
    }

    static func parse(_ input: String) throws -> [ImportedSession] {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedInput.isEmpty else {
            throw SessionImportError.emptyInput
        }

        let rawSessions: [RawSession]
        do {
            rawSessions = try JSONDecoder().decode([RawSession].self, from: Data(trimmedInput.utf8))
        } catch {
            throw SessionImportError.invalidJSON
        }

        guard !rawSessions.isEmpty else {
            throw SessionImportError.noSessions
        }

        return try rawSessions.map { rawSession in
            let sessionName = rawSession.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sessionName.isEmpty else {
                throw SessionImportError.emptySessionName
            }

            guard rawSession.sessionFee > 0 else {
                throw SessionImportError.invalidFee(sessionName)
            }

            guard let normalizedDay = normalizedWeekday(rawSession.dayOfWeek) else {
                throw SessionImportError.invalidDay(rawSession.dayOfWeek)
            }

            return ImportedSession(
                dayOfWeek: normalizedDay,
                sessionFee: rawSession.sessionFee,
                sessionName: sessionName
            )
        }
    }

    private static func normalizedWeekday(_ day: String) -> String? {
        let trimmedDay = day.trimmingCharacters(in: .whitespacesAndNewlines)
        return Weekday.allNames.first { $0.caseInsensitiveCompare(trimmedDay) == .orderedSame }
    }
}
