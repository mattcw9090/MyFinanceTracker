import SwiftUI
import SwiftData

struct ImportSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weekStart = PerthWeek.monday(containing: .now)
    @State private var sessions: [CoachingSessionPreview] = []
    @State private var previewLoaded = false
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var loadGeneration = 0
    @State private var addedCount = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    private var importable: [CoachingSessionPreview] {
        importableCoachingSessions(sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weekCard

                    if isLoading && sessions.isEmpty {
                        ProgressView("Loading sessions")
                            .padding(.top, 24)
                    } else if sessions.isEmpty {
                        EmptyStateView(
                            message: previewLoaded
                                ? "No coaching sessions this week."
                                : "Couldn't load this week's sessions.",
                            imageName: "calendar"
                        )
                        .padding(.top, 8)

                        if !previewLoaded && !isLoading {
                            Button("Try Again") {
                                Task { await showWeek(weekStart) }
                            }
                            .buttonStyle(FinancePrimaryButtonStyle())
                        }
                    } else {
                        previewCard

                        Button(action: { Task { await importShownWeek() } }) {
                            Text(isImporting ? "Importing…" : "Import \(importable.count) Sessions")
                        }
                        .buttonStyle(FinancePrimaryButtonStyle())
                        .disabled(isLoading || isImporting)
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
                await loadInitialWeek()
            }
            .alert("Import Problem", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
            .alert("Sessions Imported", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text(importSessionsSuccessMessage(added: addedCount))
            }
        }
    }

    private var weekCard: some View {
        HStack(spacing: 12) {
            Button {
                Task { await showWeek(PerthWeek.addingWeeks(-1, to: weekStart)) }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isLoading || isImporting)
            .accessibilityIdentifier("ImportSessions_PreviousWeek")

            Spacer()

            VStack(spacing: 2) {
                Text(PerthWeek.label(for: weekStart))
                    .font(.headline)
                Text("Perth week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await showWeek(PerthWeek.addingWeeks(1, to: weekStart)) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isLoading || isImporting)
            .accessibilityIdentifier("ImportSessions_NextWeek")
        }
        .financeCard(padding: 18)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FinanceSectionLabel(title: "Preview", detail: importSummary)

            ForEach(groupedDays) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.day.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FinanceTheme.income)

                    ForEach(group.sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .financeCard(padding: 18)
    }

    private func sessionRow(_ session: CoachingSessionPreview) -> some View {
        let counted = !session.alreadyImported && session.sessionFee > 0
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionName)
                    .font(.subheadline)
                    .foregroundStyle(counted ? .primary : .secondary)
                    .lineLimit(2)
                if session.alreadyImported {
                    Text("Imported")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if session.sessionFee <= 0 {
                    Text("No fee")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(session.sessionFee.formattedAsCurrency())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(counted ? FinanceTheme.income : .secondary)
                .monospacedDigit()
        }
    }

    private struct DayGroup: Identifiable {
        var day: String
        var sessions: [CoachingSessionPreview]
        var id: String { day }
    }

    private var groupedDays: [DayGroup] {
        let known = Weekday.allNames.compactMap { day -> DayGroup? in
            let rows = sessions.filter { $0.dayOfWeek == day }
            return rows.isEmpty ? nil : DayGroup(day: day, sessions: rows)
        }
        let extras = sessions.filter { !Weekday.allNames.contains($0.dayOfWeek) }
        if extras.isEmpty { return known }
        return known + [DayGroup(day: "Other", sessions: extras)]
    }

    private var importSummary: String {
        let total = importable.reduce(0) { $0 + $1.sessionFee }
        let importedCount = sessions.filter(\.alreadyImported).count
        let summary = "\(importable.count) new • \(total.formattedAsCurrency())"
        guard importedCount > 0 else { return summary }
        return "\(summary) • \(importedCount) imported"
    }

    private func loadInitialWeek() async {
        let current = PerthWeek.monday(containing: .now)
        weekStart = current
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        do {
            let chosen = try await defaultCoachingWeekStart(currentMonday: current) { week in
                try await FinanceCloud.shared.previewCoachingSessions(weekStart: week)
            }
            guard generation == loadGeneration else { return }
            weekStart = chosen.week
            sessions = chosen.rows
            previewLoaded = true
        } catch {
            guard generation == loadGeneration else { return }
            sessions = []
            previewLoaded = false
            present(error)
        }
    }

    private func showWeek(_ monday: Date) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration { isLoading = false }
        }
        do {
            let rows = try await FinanceCloud.shared.previewCoachingSessions(weekStart: monday)
            guard generation == loadGeneration else { return }
            weekStart = monday
            sessions = rows
            previewLoaded = true
        } catch {
            guard generation == loadGeneration else { return }
            present(error)
        }
    }

    private func importShownWeek() async {
        guard previewLoaded, !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let added = try await FinanceCloud.shared.importCoachingSessions(weekStart: weekStart, in: modelContext)
            addedCount = added
            if let rows = try? await FinanceCloud.shared.previewCoachingSessions(weekStart: weekStart) {
                sessions = rows
            }
            showSuccess = true
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showError = true
    }
}
