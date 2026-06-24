import Foundation
import SwiftData

@Model
final class CashFlowItem {
    var id: UUID
    var name: String?
    var amount: Double
    var isOwedToMe: Bool
    var isSettled: Bool

    init(
        id: UUID = UUID(),
        name: String? = nil,
        amount: Double = 0,
        isOwedToMe: Bool = false,
        isSettled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isOwedToMe = isOwedToMe
        self.isSettled = isSettled
    }
}
