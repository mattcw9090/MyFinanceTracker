import Foundation
import SwiftData

@Model
final class PredefinedTransaction {
    var id: UUID
    var desc: String?
    var amount: Double
    var dayOfWeek: String?
    var isIncome: Bool

    init(
        id: UUID = UUID(),
        desc: String? = nil,
        amount: Double = 0,
        dayOfWeek: String? = nil,
        isIncome: Bool = false
    ) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.dayOfWeek = dayOfWeek
        self.isIncome = isIncome
    }
}

extension PredefinedTransaction {
    static let everyDaySchedule = "Every day"

    var repeatsEveryDay: Bool {
        dayOfWeek == Self.everyDaySchedule
    }
}
