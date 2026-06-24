import SwiftUI

/// Filters a String binding to only allow decimal numeric input,
/// truncating at `maxLength` characters. Use on `TextField` for amounts.
struct DecimalInputModifier: ViewModifier {
    @Binding var text: String
    var maxLength: Int = 10

    func body(content: Content) -> some View {
        content
            .keyboardType(.decimalPad)
            .onChange(of: text) { _, newValue in
                let filtered = newValue.filter { "0123456789.".contains($0) }
                if filtered != newValue {
                    text = String(filtered.prefix(maxLength))
                } else if filtered.count > maxLength {
                    text = String(filtered.prefix(maxLength))
                }
            }
    }
}

extension View {
    /// Restrict a `TextField`'s value to decimal-numeric input.
    func decimalInput(_ binding: Binding<String>, maxLength: Int = 10) -> some View {
        modifier(DecimalInputModifier(text: binding, maxLength: maxLength))
    }
}
