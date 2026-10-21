import Foundation

extension Double {
    /// Locale-aware currency string. Falls back to USD when the locale has no currency.
    func formattedAsCurrency() -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return self.formatted(.currency(code: code))
    }

    /// Two decimal places for an amount field. The separator stays `.` because those fields reject other separators.
    func amountFieldText() -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), abs(self))
    }
}

enum CurrencyAmount {
    /// Symbol taken from `formattedAsCurrency()` so the field matches the lists.
    static var symbol: String {
        let sample = 0.0.formattedAsCurrency()
        let ignored = CharacterSet.decimalDigits
            .union(CharacterSet(charactersIn: ".,\u{00a0}\u{202f} \u{2212}+-"))
        let symbol = sample.unicodeScalars
            .filter { !ignored.contains($0) }
            .map(String.init)
            .joined()
            .trimmingCharacters(in: .whitespaces)
        return symbol.isEmpty ? "$" : symbol
    }
}
