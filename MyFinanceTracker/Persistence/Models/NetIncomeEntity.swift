import Foundation
import SwiftData

@Model
final class NetIncomeEntity {
    var value: Double

    init(value: Double = 0.0) {
        self.value = value
    }
}
