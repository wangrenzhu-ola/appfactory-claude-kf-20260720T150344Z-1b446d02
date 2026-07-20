import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var store: LedgerStore
    @Binding var selectedTab: Int
    @State private var isCreating = false
    @State private var activeDraft: ExpenseDraft?
    @State private var showDisclosure = false
    @State private var statusText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CaptureWorkbenchArtwork()
                    .frame(height: 210)
                    .accessibilityHidden(true)
                Text("Capture a receipt")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundColor(LedgerTheme.graphite)
                Text("Create a local draft first. Nothing becomes an expense entry until you confirm it.")
                    .font(.body)
                    .foregroundColor(LedgerTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if isCreating {
                    StatusPanel(symbol: "hourglass", title: "Creating draft…", detail: "Your local receipt draft is being prepared. You can switch tabs and return without losing it.", tint: LedgerTheme.amber)
                        .accessibilityLabel("Creating draft. Your local receipt draft is being prepared.")
                } else if let statusText = statusText {
                    StatusPanel(symbol: "checkmark.seal", title: statusText, detail: "Review every field before confirming an entry.", tint: LedgerTheme.moss)
                        .accessibilityLabel(statusText)
                } else {
                    StatusPanel(symbol: "lock", title: "Local by default", detail: "Draft suggestions are created on this device. Manual entry is always available.", tint: LedgerTheme.moss)
                }
                Button(action: startPhotoSelection) {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Choose a receipt photo")
                Button(action: startCapture) {
                    Label("Capture receipt", systemImage: "camera")
                }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityLabel("Capture a receipt")
                Button("Enter details manually", action: startManualEntry)
                    .foregroundColor(LedgerTheme.moss)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Enter receipt details manually")
                Button("How optional processing works", action: { showDisclosure = true })
                    .font(.subheadline)
                    .foregroundColor(LedgerTheme.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .accessibilityLabel("How optional processing works")
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Capture", displayMode: .inline)
        .background(NavigationLink(destination: reviewDestination, isActive: reviewIsActive) { EmptyView() }.hidden())
        .sheet(isPresented: $showDisclosure) { ProcessingDisclosureView() }
    }

    private var reviewDestination: some View {
        Group {
            if let draft = activeDraft { ReviewDraftView(draft: draft, selectedTab: $selectedTab) }
            else { EmptyView() }
        }
    }

    private var reviewIsActive: Binding<Bool> {
        Binding(get: { activeDraft != nil && !isCreating }, set: { if !$0 { activeDraft = nil } })
    }

    private func startPhotoSelection() { createSuggestedReceipt(title: "Selected receipt photo") }
    private func startCapture() { createSuggestedReceipt(title: "Captured receipt") }

    private func createSuggestedReceipt(title: String) {
        let receipt = store.createReceipt(title: title)
        isCreating = true
        statusText = nil
        store.createSuggestedDraft(for: receipt.id) { draft in
            isCreating = false
            guard let draft = draft else {
                statusText = "Draft could not be created"
                return
            }
            statusText = "Draft created"
            activeDraft = draft
        }
    }

    private func startManualEntry() {
        let receipt = store.createReceipt(title: "Manual receipt")
        activeDraft = store.createManualDraft(for: receipt.id)
    }
}

struct ProcessingDisclosureView: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Optional processing").font(.title2.bold())
                    DisclosureRow(label: "Receipt image", detail: "The image you selected")
                    DisclosureRow(label: "Purpose", detail: "Create editable merchant, amount, date, and category suggestions")
                    DisclosureRow(label: "Service", detail: "No remote service is active in this version")
                    Text("Cancel keeps your receipt local and opens manual entry instead. You can change your preference in Privacy Settings.")
                        .foregroundColor(LedgerTheme.inkSecondary)
                    Button("Keep this receipt local") { presentationMode.wrappedValue.dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(24)
            }
            .navigationBarTitle("Before processing", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

struct DisclosureRow: View {
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LedgerTheme.rule, lineWidth: 1))
    }
}

struct ReceiptsView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var onlyUnconfirmed = false
    @State private var receiptToDelete: Receipt?

    private var displayedReceipts: [Receipt] {
        onlyUnconfirmed ? store.receipts.filter { $0.entryID == nil } : store.receipts
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Receipts").font(.system(.largeTitle, design: .serif).weight(.bold))
                        Text("\(store.receipts.count) local \(store.receipts.count == 1 ? "receipt" : "receipts")")
                            .foregroundColor(LedgerTheme.inkSecondary)
                    }
                    Spacer()
                    Toggle("Unconfirmed", isOn: $onlyUnconfirmed)
                        .labelsHidden()
                        .accessibilityLabel("Show unconfirmed receipts only")
                }
                if displayedReceipts.isEmpty {
                    EmptyReceiptState()
                } else {
                    ForEach(displayedReceipts) { receipt in
                        NavigationLink(destination: ReceiptDetailView(receiptID: receipt.id)) {
                            ReceiptRow(receipt: receipt)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(20)
        }
        .background(LedgerTheme.paper.ignoresSafeArea())
        .navigationBarTitle("Receipts", displayMode: .inline)
    }
}

struct EmptyReceiptState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus").font(.system(size: 36)).foregroundColor(LedgerTheme.amber)
            Text("No receipts yet").font(.title3.bold())
            Text("Capture a receipt to make an editable local draft.")
                .multilineTextAlignment(.center).foregroundColor(LedgerTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 44)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LedgerTheme.rule, style: StrokeStyle(lineWidth: 1, dash: [5])))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No receipts yet. Capture a receipt to make an editable local draft.")
    }
}

struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.image").font(.title2).foregroundColor(LedgerTheme.moss).frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.title).font(.headline).foregroundColor(LedgerTheme.graphite)
                Text(receipt.capturedAt, style: .date).font(.subheadline).foregroundColor(LedgerTheme.inkSecondary)
            }
            Spacer()
            StatusPill(text: receipt.statusLabel, tint: receipt.entryID == nil ? LedgerTheme.amber : LedgerTheme.moss)
        }
        .padding(14)
        .background(Color.white.opacity(0.55))
        .cornerRadius(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(receipt.title), \(receipt.statusLabel)")
    }
}

struct ReceiptDetailView: View {
    @EnvironmentObject private var store: LedgerStore
    let receiptID: UUID
    @State private var showDelete = false

    var body: some View {
        Group {
            if let receipt = store.receipt(with: receiptID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Receipt detail").font(.system(.largeTitle, design: .serif).weight(.bold))
                        StatusPanel(symbol: "doc.text.image", title: receipt.title, detail: receipt.entryID == nil ? "Not yet confirmed" : "Linked to a confirmed expense entry", tint: receipt.entryID == nil ? LedgerTheme.amber : LedgerTheme.moss)
                        if let draft = receipt.draft, receipt.entryID == nil {
                            NavigationLink(destination: ReviewDraftView(draft: draft, selectedTab: .constant(1))) {
                                Label("Review draft", systemImage: "pencil")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityLabel("Review receipt draft")
                        }
                        if let entry = store.entry(for: receiptID) {
                            EntrySummary(entry: entry)
                        }
                        Button("Delete this receipt", action: { showDelete = true })
                            .foregroundColor(.red).frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityLabel("Delete this receipt")
                    }
                    .padding(20)
                }
                .background(LedgerTheme.paper.ignoresSafeArea())
                .alert(isPresented: $showDelete) {
                    Alert(title: Text("Delete this receipt?"), message: Text("The linked expense entry will remain unless you delete it separately."), primaryButton: .destructive(Text("Delete")) { store.deleteReceipt(receiptID) }, secondaryButton: .cancel())
                }
            } else {
                Text("Receipt not found").padding()
            }
        }
        .navigationBarTitle("Receipt detail", displayMode: .inline)
    }
}

struct EntrySummary: View {
    let entry: ExpenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked expense entry").font(.headline)
            Text(entry.merchant).font(.title3)
            Text(CurrencyFormatter.string(from: entry.amount)).font(.system(.title2, design: .monospaced).weight(.bold))
            Text(entry.isReviewed ? "Reviewed" : "Not reviewed yet").foregroundColor(entry.isReviewed ? LedgerTheme.moss : LedgerTheme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color.white.opacity(0.55)).cornerRadius(14)
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: text == "Confirmed" ? "checkmark.circle.fill" : "circle.fill").font(.caption2)
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(tint.opacity(0.12)).cornerRadius(10)
        .accessibilityLabel(text)
    }
}
