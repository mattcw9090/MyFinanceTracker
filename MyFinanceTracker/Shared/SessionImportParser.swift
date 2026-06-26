import Foundation

struct ImportedSession: Identifiable, Equatable {
    let id = UUID()
    let dayOfWeek: String
    let sessionFee: Double
    let sessionName: String
}

enum SessionImportError: LocalizedError, Equatable {
    case invalidDay(String)
    case invalidFee(String)
    case emptySessionName

    var errorDescription: String? {
        switch self {
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
    /// Validates and normalizes a single raw session shared by CoachPlanner.
    static func validatedSession(dayOfWeek: String, sessionFee: Double, sessionName: String) throws -> ImportedSession {
        let trimmedName = sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SessionImportError.emptySessionName
        }

        guard sessionFee > 0 else {
            throw SessionImportError.invalidFee(trimmedName)
        }

        guard let normalizedDay = normalizedWeekday(dayOfWeek) else {
            throw SessionImportError.invalidDay(dayOfWeek)
        }

        return ImportedSession(
            dayOfWeek: normalizedDay,
            sessionFee: sessionFee,
            sessionName: trimmedName
        )
    }

    private static func normalizedWeekday(_ day: String) -> String? {
        let trimmedDay = day.trimmingCharacters(in: .whitespacesAndNewlines)
        return Weekday.allNames.first { $0.caseInsensitiveCompare(trimmedDay) == .orderedSame }
    }
}
