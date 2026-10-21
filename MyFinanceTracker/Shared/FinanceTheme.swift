import SwiftUI
import UIKit

enum FinanceTheme {
    static let accent = Color(red: 0.34, green: 0.33, blue: 0.88)
    static let accentDeep = Color(red: 0.22, green: 0.20, blue: 0.66)
    /// Text and icons. Deeper on a light surface, lighter on a dark one.
    static let income = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.55, green: 0.86, blue: 0.70, alpha: 1)
        }
        return UIColor(red: 0.02, green: 0.42, blue: 0.28, alpha: 1)
    })
    static let expense = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 1.00, green: 0.64, blue: 0.66, alpha: 1)
        }
        return UIColor(red: 0.70, green: 0.12, blue: 0.18, alpha: 1)
    })
    /// Solid button fills, kept deep so white labels stay readable in both modes.
    static let incomeFill = Color(red: 0.04, green: 0.40, blue: 0.28)
    static let expenseFill = Color(red: 0.62, green: 0.12, blue: 0.18)
    static let amber = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.98, green: 0.74, blue: 0.36, alpha: 1)
        }
        return UIColor(red: 0.62, green: 0.36, blue: 0.05, alpha: 1)
    })
    static let amberFill = Color(red: 0.55, green: 0.30, blue: 0.04)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                tint.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

enum FinanceMark {
    static let income = "arrow.up.circle.fill"
    static let expense = "arrow.down.circle.fill"

    static func symbol(isIncome: Bool) -> String {
        isIncome ? income : expense
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
