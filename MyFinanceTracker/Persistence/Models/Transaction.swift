import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var desc: String?
    var amount: Double
    var dayOfWeek: String?
    var isCompleted: Bool
    var isIncome: Bool

    init(
        id: UUID = UUID(),
        desc: String? = nil,
        amount: Double = 0,
        dayOfWeek: String? = nil,
        isCompleted: Bool = false,
        isIncome: Bool = false
    ) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.dayOfWeek = dayOfWeek
        self.isCompleted = isCompleted
        self.isIncome = isIncome
    }
}
