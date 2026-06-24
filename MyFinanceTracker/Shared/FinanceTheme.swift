import SwiftUI

enum FinanceTheme {
    static let accent = Color(red: 0.34, green: 0.33, blue: 0.88)
    static let accentDeep = Color(red: 0.22, green: 0.20, blue: 0.66)
    static let income = Color(red: 0.08, green: 0.58, blue: 0.43)
    static let expense = Color(red: 0.88, green: 0.29, blue: 0.34)
    static let amber = Color(red: 0.92, green: 0.57, blue: 0.16)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let field = Color(uiColor: .tertiarySystemGroupedBackground)
    static let border = Color.primary.opacity(0.07)

    static var background: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.07), canvas, canvas],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FinanceCardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FinanceTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(FinanceTheme.border, lineWidth: 1)
            }
    }
}

struct FinanceFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(FinanceTheme.field, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(FinanceTheme.border, lineWidth: 1)
            }
    }
}

extension View {
    func financeCard(padding: CGFloat = 16) -> some View {
        modifier(FinanceCardModifier(padding: padding))
    }

    func financeField() -> some View {
        modifier(FinanceFieldModifier())
    }

    func financeBackground() -> some View {
        background(FinanceTheme.background.ignoresSafeArea())
    }
}

struct FinanceSectionLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FinanceActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct FinancePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                LinearGradient(
                    colors: [FinanceTheme.accent, FinanceTheme.accentDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
