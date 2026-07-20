import SwiftUI
import UIKit

struct ReviewDraftView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedTab: Int
    @State private var draft: ExpenseDraft
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    init(draft: ExpenseDraft, selectedTab: Binding<Int>) {
        _draft = State(initialValue: draft)
        _selectedTab = selectedTab
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReviewHighlightArtwork().frame(height: 118).accessibilityHidden(true)
                Text("Review draft").font(.system(.largeTitle, design: .serif).weight(.bold))
                Text("Suggestions are editable. Confirm Entry is the only action that saves an expense entry.")
                    .foregroundColor(LedgerTheme.inkSecondary).fixedSize(horizontal: false, vertical: true)
                if let errorMessage = errorMessage {
                    StatusPanel(symbol: "exclamationmark.triangle", title: "Draft not saved", detail: errorMessage, tint: .red)
                        .accessibilityLabel("Draft not saved. \(errorMessage)")
                }
                DraftField(label: "Merchant", text: $draft.merchant, prompt: "Where did you pay?")
                DraftField(label: "Amount", text: $draft.amount, prompt: "0.00", keyboard: .decimalPad)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date").font(.headline).foregroundColor(LedgerTheme.graphite)
                    DatePicker("Receipt date", selection: $draft.date, displayedComponents: .date).labelsHidden()
                        .accessibilityLabel("Receipt date")
                }
                .padding(14).background(Color.white.opacity(0.62)).cornerRadius(12)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category").font(.headline).foregroundColor(LedgerTheme.graphite)
                    Picker("Expense category", selection: $draft.category) {
                        ForEach(ReceiptCategory.allCases) { category in Text(category.rawValue).tag(category) }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accessibilityLabel("Expense category")
                }
                .padding(14).background(Color.white.opacity(0.62)).cornerRadius(12)
                Text("Draft not saved until you confirm it.")
                    .font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
                Button("Confirm Entry", action: prepareConfirmation)
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("Confirm expense entry")
                Button("Enter details manually", action: resetForManualEntry)
                    .foregroundColor(LedgerTheme.moss).frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Clear suggestions and enter details manually")
                Button("Cancel and keep draft", action: cancel)
                    .foregroundColor(LedgerTheme.inkSecondary).frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Cancel and keep receipt draft")
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Review draft", displayMode: .inline)
        .sheet(isPresented: $showConfirmation) {
            EntryConfirmationView(draft: draft, selectedTab: $selectedTab, onFinish: { presentationMode.wrappedValue.dismiss() })
                .environmentObject(store)
        }
    }

    private func prepareConfirmation() {
        switch validate() {
        case .success:
            store.updateDraft(draft)
            showConfirmation = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func validate() -> Result<Void, LedgerError> {
        if draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .failure(.merchantMissing) }
        if LedgerCore.parsedAmount(draft.amount) == nil { return .failure(.amountInvalid) }
        return .success(())
    }

    private func resetForManualEntry() {
        draft.merchant = ""
        draft.amount = ""
        draft.category = .other
        draft.state = .manual
        errorMessage = nil
        store.updateDraft(draft)
    }

    private func cancel() {
        store.updateDraft(draft)
        presentationMode.wrappedValue.dismiss()
    }
}

struct DraftField: View {
    let label: String
    @Binding var text: String
    let prompt: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline).foregroundColor(LedgerTheme.graphite)
            TextField(prompt, text: $text)
                .keyboardType(keyboard)
                .submitLabel(.done)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .accessibilityLabel(label)
        }
        .padding(14)
        .background(Color.white.opacity(0.62))
        .cornerRadius(12)
    }
}

struct EntryConfirmationView: View {
    @EnvironmentObject private var store: LedgerStore
    @Environment(\.presentationMode) private var presentationMode
    let draft: ExpenseDraft
    @Binding var selectedTab: Int
    let onFinish: () -> Void
    @State private var saveError: String?
    @State private var didSave = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(didSave ? "Entry saved" : "Confirm entry")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                if didSave {
                    StatusPanel(symbol: "checkmark.circle.fill", title: "Entry saved", detail: "Your expense is ready for Monthly Review.", tint: LedgerTheme.moss)
                    Button("Open Monthly Review", action: openReview).buttonStyle(PrimaryButtonStyle())
                } else {
                    Text("This saves one local expense entry from your editable draft.")
                        .foregroundColor(LedgerTheme.inkSecondary)
                    EntrySummary(entry: ExpenseEntry(receiptID: draft.receiptID, merchant: draft.merchant, amount: LedgerCore.parsedAmount(draft.amount) ?? 0, date: draft.date, category: draft.category))
                    if let saveError = saveError {
                        StatusPanel(symbol: "exclamationmark.triangle", title: "Could not save entry", detail: saveError, tint: .red)
                    }
                    Button("Confirm Entry", action: confirm).buttonStyle(PrimaryButtonStyle())
                    Button("Back to edit", action: { presentationMode.wrappedValue.dismiss() })
                        .foregroundColor(LedgerTheme.moss).frame(maxWidth: .infinity, minHeight: 44)
                }
                Spacer()
            }
            .padding(24)
            .navigationBarItems(trailing: Button("Close") { presentationMode.wrappedValue.dismiss() })
        }
    }

    private func confirm() {
        switch store.confirm(draft) {
        case .success:
            didSave = true
        case .failure(let error):
            saveError = error.localizedDescription
        }
    }

    private func openReview() {
        selectedTab = 2
        presentationMode.wrappedValue.dismiss()
        onFinish()
    }
}

struct MonthlyReviewView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var month = Date()
    @State private var entryToDelete: ExpenseEntry?

    private var entries: [ExpenseEntry] { store.entries(in: month) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TallyArtwork().frame(height: 130).accessibilityHidden(true)
                Text("Monthly review").font(.system(.largeTitle, design: .serif).weight(.bold))
                DatePicker("Review month", selection: $month, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .accessibilityLabel("Select review month")
                StatusPanel(symbol: "circle.dashed", title: "\(entries.filter { !$0.isReviewed }.count) unreviewed this month", detail: "Mark entries reviewed when your records are complete.", tint: LedgerTheme.amber)
                if entries.isEmpty {
                    Text("No entries this month").font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LedgerTheme.rule, style: StrokeStyle(lineWidth: 1, dash: [5])))
                        .accessibilityLabel("No entries this month")
                } else {
                    ForEach(entries) { entry in
                        ReviewEntryRow(entry: entry, onReview: { store.markReviewed(entry.id) }, onDelete: { entryToDelete = entry })
                    }
                }
                NavigationLink(destination: ExportPreviewView(month: month)) {
                    Label("Open export preview", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Open CSV export preview")
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Monthly review", displayMode: .inline)
        .alert(item: $entryToDelete) { entry in
            Alert(title: Text("Delete this entry?"), message: Text("This updates the monthly count and export range immediately."), primaryButton: .destructive(Text("Delete")) { store.deleteEntry(entry.id) }, secondaryButton: .cancel())
        }
    }
}

struct ReviewEntryRow: View {
    let entry: ExpenseEntry
    let onReview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(entry.merchant).font(.headline)
                Spacer()
                Text(CurrencyFormatter.string(from: entry.amount)).font(.system(.headline, design: .monospaced))
            }
            Text("\(entry.category.rawValue) · \(entry.date, style: .date)")
                .font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
            HStack {
                if entry.isReviewed {
                    Label("Marked reviewed", systemImage: "checkmark.circle").font(.subheadline).foregroundColor(LedgerTheme.moss)
                } else {
                    Button("Mark reviewed", action: onReview).font(.subheadline.bold()).foregroundColor(LedgerTheme.moss).accessibilityLabel("Mark \(entry.merchant) as reviewed")
                }
                Spacer()
                Button("Delete", action: onDelete).font(.subheadline).foregroundColor(.red).accessibilityLabel("Delete \(entry.merchant) entry")
            }
        }
        .padding(15).background(Color.white.opacity(0.55)).cornerRadius(14)
    }
}

struct ExportPreviewView: View {
    @EnvironmentObject private var store: LedgerStore
    let month: Date
    @State private var isSharing = false
    @State private var exportError: String?

    private var csv: String { store.exportCSV(for: month) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Export preview").font(.system(.largeTitle, design: .serif).weight(.bold))
                Text("\(store.entries(in: month).count) entries · \(month, formatter: MonthFormatter.shared)")
                    .foregroundColor(LedgerTheme.inkSecondary)
                Text("merchant,date,amount,category,reviewed")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                Text(csv).font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Color.white.opacity(0.65)).cornerRadius(12)
                if let exportError = exportError {
                    StatusPanel(symbol: "exclamationmark.triangle", title: "Export not shared", detail: exportError, tint: .red)
                    Button("Try again", action: share).buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Confirm and share CSV", action: share).buttonStyle(PrimaryButtonStyle())
                        .accessibilityLabel("Confirm and share CSV export")
                }
                Text("Your entries are unchanged if sharing is cancelled or unavailable.")
                    .font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Export preview", displayMode: .inline)
        .sheet(isPresented: $isSharing) { ActivitySheet(items: [temporaryCSVURL() as Any]) }
    }

    private func temporaryCSVURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("receipt-ledger-export.csv")
        do { try csv.write(to: url, atomically: true, encoding: .utf8) } catch { exportError = "Try again. The CSV could not be prepared." }
        return url
    }

    private func share() {
        guard !store.entries(in: month).isEmpty else {
            exportError = "Add an entry before exporting."
            return
        }
        isSharing = true
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showDisclosure = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Privacy settings").font(.system(.largeTitle, design: .serif).weight(.bold))
                StatusPanel(symbol: "lock.fill", title: "Local by default", detail: "Receipt images and entries are stored on this device.", tint: LedgerTheme.moss)
                Toggle(isOn: $store.remoteProcessingAllowed) {
                    VStack(alignment: .leading) {
                        Text("Allow optional processing")
                        Text("No remote service is active in this version.").font(.caption).foregroundColor(LedgerTheme.inkSecondary)
                    }
                }
                .tint(LedgerTheme.moss)
                .accessibilityLabel("Allow optional processing")
                Button("Review what would be shared", action: { showDisclosure = true })
                    .buttonStyle(OutlineButtonStyle())
                    .accessibilityLabel("Review processing disclosure")
                Text("Turning this off keeps future optional processing disabled. Manual entry remains available.")
                    .font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Privacy", displayMode: .inline)
        .sheet(isPresented: $showDisclosure) { ProcessingDisclosureView() }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(.system(.largeTitle, design: .serif).weight(.bold))
                NavigationLink(destination: PrivacySettingsView()) {
                    SettingRow(icon: "hand.raised", title: "Privacy settings", detail: "Local storage and optional processing")
                }.buttonStyle(PlainButtonStyle())
                StatusPanel(symbol: "gift", title: "No purchases in this version", detail: "Receipt Ledger has no subscriptions or in-app purchases.", tint: LedgerTheme.moss)
                BoundaryNote(icon: "tray.and.arrow.down", text: "Local data can be deleted below. Device backups and recovery after uninstalling or moving the app are not guaranteed.")
                BoundaryNote(icon: "text.book.closed", text: "This app helps organize records. It does not provide tax advice.")
                Button("Delete all local data", action: { showClear = true })
                    .foregroundColor(.red).frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red, lineWidth: 1))
                    .accessibilityLabel("Delete all local receipt data")
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Settings", displayMode: .inline)
        .alert(isPresented: $showClear) {
            Alert(title: Text("Delete all local data?"), message: Text("This removes receipts and expense entries from this device."), primaryButton: .destructive(Text("Delete all")) { store.clearAllLocalData() }, secondaryButton: .cancel())
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundColor(LedgerTheme.moss).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundColor(LedgerTheme.graphite)
                Text(detail).font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundColor(LedgerTheme.inkSecondary)
        }
        .padding(15).background(Color.white.opacity(0.55)).cornerRadius(14)
    }
}

struct StatusPanel: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundColor(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundColor(LedgerTheme.graphite)
                Text(detail).font(.subheadline).foregroundColor(LedgerTheme.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
        .background(Color.white.opacity(0.56)).cornerRadius(14)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundColor(LedgerTheme.moss)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LedgerTheme.moss, lineWidth: configuration.isPressed ? 2 : 1))
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

enum CurrencyFormatter {
    static func string(from decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "$0.00"
    }
}

enum MonthFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "MMMM yyyy"; return formatter
    }()
}
