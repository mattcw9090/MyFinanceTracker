import Foundation
import SwiftData

@Model
final class QuickAddTransaction {
    var id: UUID
    var desc: String?
    var amount: Double
    var isIncome: Bool

    init(
        id: UUID = UUID(),
        desc: String? = nil,
        amount: Double = 0,
        isIncome: Bool = false
    ) {
        self.id = id
        self.desc = desc
        self.amount = amount
        self.isIncome = isIncome
    }
}
