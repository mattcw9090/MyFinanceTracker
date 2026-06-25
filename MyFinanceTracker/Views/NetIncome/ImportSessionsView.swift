import SwiftUI
import SwiftData

struct ImportSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var netIncomeManager: NetIncomeManager

    @State private var jsonText = ""
    @State private var parsedSessions: [ImportedSession] = []
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        FinanceSectionLabel(
                            title: "Session JSON",
                            detail: parsedSessions.isEmpty ? "Paste array" : importSummary
                        )

                        Text("Paste sessions with dayOfWeek, sessionFee, and sessionName. Each item will become an income transaction for that day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $jsonText)
                            .font(.callout.monospaced())
                            .frame(minHeight: 260)
                            .padding(10)
                            .background(FinanceTheme.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(FinanceTheme.border, lineWidth: 1)
                            }
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("ImportSessions_JSONTextEditor")
                    }
                    .financeCard(padding: 18)

                    if !parsedSessions.isEmpty {
                        previewCard
                    }

                    Button(action: previewSessions) {
                        Text("Preview Sessions")
                    }
                    .buttonStyle(FinancePrimaryButtonStyle())
                    .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    .accessibilityIdentifier("ImportSessions_PreviewButton")

                    if !parsedSessions.isEmpty {
                        Button(action: importSessions) {
                            Text("Import \(parsedSessions.count) Sessions")
                        }
                        .buttonStyle(FinancePrimaryButtonStyle())
                        .accessibilityIdentifier("ImportSessions_ImportButton")
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .financeBackground()
            .navigationTitle("Import Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("ImportSessions_CancelButton")
                }
            }
            .onChange(of: jsonText) {
                parsedSessions = []
            }
            .alert("Import Problem", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
            .alert("Sessions Imported", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Added \(parsedSessions.count) income transactions to your week.")
            }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FinanceSectionLabel(title: "Preview", detail: importSummary)

            ForEach(Weekday.allNames, id: \.self) { day in
                let sessions = parsedSessions.filter { $0.dayOfWeek == day }
                if !sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FinanceTheme.income)

                        ForEach(sessions) { session in
                            HStack {
                                Text(session.sessionName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                Text(session.sessionFee.formattedAsCurrency())
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FinanceTheme.income)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .financeCard(padding: 18)
    }

    private var importSummary: String {
        let total = parsedSessions.reduce(0) { $0 + $1.sessionFee }
        return "\(parsedSessions.count) sessions • \(total.formattedAsCurrency())"
    }

    private func previewSessions() {
        do {
            parsedSessions = try SessionImportParser.parse(jsonText)
        } catch let importError as SessionImportError {
            errorMessage = importError.localizedDescription
            showError = true
        } catch {
            errorMessage = "Failed to preview sessions: \(error.localizedDescription)"
            showError = true
        }
    }

    private func importSessions() {
        do {
            for session in sessions {
                let transaction = Transaction(
                    desc: session.sessionName,
                    amount: session.sessionFee,
                    dayOfWeek: session.dayOfWeek,
                    isCompleted: false,
                    isIncome: true
                )
                modelContext.insert(transaction)
                netIncomeManager.adjustNetIncome(by: session.sessionFee, isIncome: true, isDeletion: false)
            }

            try modelContext.save()
            showSuccess = true
        } catch {
            errorMessage = "Failed to import sessions: \(error.localizedDescription)"
            showError = true
        }
    }

    private var sessions: [ImportedSession] {
        parsedSessions
    }
}
