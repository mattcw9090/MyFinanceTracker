import Foundation

extension Double {
    /// Locale-aware currency string. Falls back to USD when the locale has no currency.
    func formattedAsCurrency() -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return self.formatted(.currency(code: code))
    }
}
