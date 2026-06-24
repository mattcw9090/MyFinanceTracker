import SwiftUI

struct DuplicatePredefinedTransactionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let source: PredefinedTransaction

    private let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @State private var selectedDays: Set<String> = []
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Description", value: source.desc ?? "—")
                    LabeledContent("Amount", value: source.amount.formattedAsCurrency())
                    LabeledContent("Type", value: source.isIncome ? "Income" : "Expense")
                    LabeledContent("From", value: source.dayOfWeek ?? "—")
                } header: {
                    Text("Source")
                }

                Section {
                    ForEach(targetDays, id: \.self) { day in
                        Toggle(day, isOn: bindingFor(day))
                            .accessibilityIdentifier("DuplicatePredefined_Day_\(day)")
                    }
                } header: {
                    Text("Duplicate To")
                } footer: {
                    Text("Each selected day will get a copy of this transaction.")
                }
            }
            .navigationTitle("Duplicate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("DuplicatePredefined_CancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saveTitle) {
                        duplicate()
                    }
                    .disabled(selectedDays.isEmpty)
                    .accessibilityIdentifier("DuplicatePredefined_SaveButton")
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private var targetDays: [String] {
        daysOfWeek.filter { $0 != source.dayOfWeek }
    }

    private var saveTitle: String {
        selectedDays.isEmpty ? "Duplicate" : "Duplicate (\(selectedDays.count))"
    }

    private func bindingFor(_ day: String) -> Binding<Bool> {
        Binding(
            get: { selectedDays.contains(day) },
            set: { isOn in
                if isOn { selectedDays.insert(day) } else { selectedDays.remove(day) }
            }
        )
    }

    private func duplicate() {
        guard !selectedDays.isEmpty else { return }
        for day in selectedDays {
            let copy = PredefinedTransaction(context: viewContext)
            copy.id = UUID()
            copy.desc = source.desc
            copy.amount = source.amount
            copy.isIncome = source.isIncome
            copy.dayOfWeek = day
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Failed to duplicate: \(error.localizedDescription)"
            showAlert = true
        }
    }
}
