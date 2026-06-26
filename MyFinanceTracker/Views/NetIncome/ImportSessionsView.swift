import SwiftUI
import SwiftData

struct ImportSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var netIncomeManager: NetIncomeManager

    @State private var parsedSessions: [ImportedSession] = []
    @State private var bridgeInfo: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    coachPlannerCard

                    if parsedSessions.isEmpty {
                        EmptyStateView(
                            message: "Open CoachPlanner and tap the money icon to share your sessions, then load them here.",
                            imageName: "tray.and.arrow.down"
                        )
                        .padding(.top, 8)
                    } else {
                        previewCard

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
            .task {
                // Silently pre-fill if CoachPlanner has already shared a snapshot.
                if parsedSessions.isEmpty {
                    loadFromCoachPlanner(showErrors: false)
                }
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

    private var coachPlannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FinanceSectionLabel(
                title: "From CoachPlanner",
                detail: bridgeInfo ?? "Shared on this device"
            )

            Text("Pull the latest sessions CoachPlanner shared via the App Group. Tapping the money icon in CoachPlanner refreshes this snapshot.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: { loadFromCoachPlanner(showErrors: true) }) {
                Label("Load from CoachPlanner", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(FinancePrimaryButtonStyle())
            .accessibilityIdentifier("ImportSessions_LoadFromCoachPlannerButton")
        }
        .financeCard(padding: 18)
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

    private func loadFromCoachPlanner(showErrors: Bool) {
        do {
            let result = try CoachPlannerBridge.readSessions()
            parsedSessions = result.sessions
            let when = result.envelope.exportedAt.formatted(date: .abbreviated, time: .shortened)
            bridgeInfo = "\(result.envelope.source) • \(when)"
        } catch {
            guard showErrors else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Failed to load from CoachPlanner: \(error.localizedDescription)"
            showError = true
        }
    }

    private func importSessions() {
        do {
            for session in parsedSessions {
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
}
