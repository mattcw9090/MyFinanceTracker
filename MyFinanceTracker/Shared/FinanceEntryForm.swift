import SwiftUI

struct CurrencyAmountField: View {
    @Binding var amount: String
    var identifier: String
    var prompt: String = "0.00"

    var body: some View {
        HStack(spacing: 8) {
            Text(CurrencyAmount.symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $amount)
                .decimalInput($amount)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel("Amount")
        }
    }
}

struct WeekdaySegmentedControl: View {
    @Binding var selection: String
    var pickerID: String

    @ScaledMetric(relativeTo: .caption) private var segmentHeight: CGFloat = 44

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Weekday.allNames, id: \.self) { day in
                let isSelected = selection == day
                Button {
                    selection = day
                } label: {
                    Text(String(day.prefix(3)))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(maxWidth: .infinity, minHeight: segmentHeight)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            isSelected ? FinanceTheme.accent : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day)
                .accessibilityIdentifier("\(pickerID)_\(day)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(FinanceTheme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier(pickerID)
    }
}

struct WeekdayPickerCard: View {
    @Binding var selection: String
    var pickerID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day")
                .font(.subheadline.weight(.semibold))
            WeekdaySegmentedControl(selection: $selection, pickerID: pickerID)
        }
        .financeCard(padding: 18)
    }
}

struct TransactionTypePicker: View {
    @Binding var isIncome: Bool
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type")
                .font(.subheadline.weight(.semibold))
            Picker("Type", selection: $isIncome) {
                Text("Income").tag(true)
                Text("Expense").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(identifier)
        }
        .financeCard(padding: 18)
    }
}

/// Shared description and currency amount fields for add, edit, and predefined transactions.
struct FinanceEntryForm<Details: View>: View {
    @Binding var descriptionText: String
    @Binding var amount: String
    var descriptionPrompt: String
    var descriptionIdentifier: String
    var amountIdentifier: String
    @ViewBuilder var details: () -> Details

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Description")
                        .font(.subheadline.weight(.semibold))
                    TextField(descriptionPrompt, text: $descriptionText)
                        .financeField()
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier(descriptionIdentifier)

                    Text("Amount")
                        .font(.subheadline.weight(.semibold))
                    CurrencyAmountField(amount: $amount, identifier: amountIdentifier)
                        .financeField()
                }
                .financeCard(padding: 18)

                details()
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .financeBackground()
    }
}
