import SwiftUI
import UIKit

struct CaptureView: View {
    @EnvironmentObject private var store: LedgerStore
    @Binding var selectedTab: Int
    @State private var isCreating = false
    @State private var activeDraft: ExpenseDraft?
    @State private var showDisclosure = false
    @State private var pickerSource: ReceiptCaptureSource?
    @State private var statusText: String?
    @State private var captureError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CaptureWorkbenchArtwork()
                    .frame(height: 210)
                    .accessibilityHidden(true)
                Text("Capture a receipt")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundColor(LedgerTheme.graphite)
                Text("Choose a receipt image to make an editable local draft. Nothing becomes an expense entry until you confirm it.")
                    .font(.body)
                    .foregroundColor(LedgerTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                captureStatus
                Button(action: choosePhoto) {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Choose a receipt photo")
                Button(action: chooseCamera) {
                    Label("Capture receipt", systemImage: "camera")
                }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityLabel("Capture a receipt with the camera")
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
        .sheet(item: $pickerSource) { source in
            ReceiptImagePicker(source: source, onImage: importReceiptImage, onCancel: dismissPicker)
        }
    }

    @ViewBuilder
    private var captureStatus: some View {
        if isCreating {
            StatusPanel(symbol: "hourglass", title: "Creating draft…", detail: "Reading this selected receipt on your device. You can return to it without losing the local draft.", tint: LedgerTheme.amber)
                .accessibilityLabel("Creating draft. Reading this receipt on your device.")
        } else if let captureError = captureError {
            StatusPanel(symbol: "exclamationmark.triangle", title: "Draft needs your input", detail: captureError, tint: .red)
                .accessibilityLabel("Draft needs your input. \(captureError)")
        } else if let statusText = statusText {
            StatusPanel(symbol: "checkmark.seal", title: statusText, detail: "Review every field before confirming an entry.", tint: LedgerTheme.moss)
                .accessibilityLabel(statusText)
        } else {
            StatusPanel(symbol: "lock", title: "Local by default", detail: "Receipt text is read on this device. Manual entry is always available.", tint: LedgerTheme.moss)
        }
    }

    private var reviewDestination: some View {
        Group {
            if let draft = activeDraft {
                ReviewDraftView(draft: draft, selectedTab: $selectedTab)
            } else {
                EmptyView()
            }
        }
    }

    private var reviewIsActive: Binding<Bool> {
        Binding(get: { activeDraft != nil && !isCreating }, set: { if !$0 { activeDraft = nil } })
    }

    private func choosePhoto() {
        captureError = nil
        pickerSource = .photoLibrary
    }

    private func chooseCamera() {
        captureError = nil
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            captureError = "Camera is unavailable on this device. Choose a photo or enter details manually."
            return
        }
        pickerSource = .camera
    }

    private func importReceiptImage(_ image: UIImage) {
        pickerSource = nil
        do {
            let path = try ReceiptImageStore.save(image)
            let receipt = store.createReceipt(title: "Local receipt image", localImagePath: path)
            isCreating = true
            statusText = nil
            captureError = nil
            store.beginDraft(for: receipt.id)
            ReceiptTextRecognitionService.recognize(image: image) { result in
                finishRecognition(result, receiptID: receipt.id)
            }
        } catch {
            captureError = error.localizedDescription
        }
    }

    private func finishRecognition(_ result: Result<String, ReceiptRecognitionError>, receiptID: UUID) {
        isCreating = false
        switch result {
        case .success(let text):
            guard let draft = store.completeRecognizedDraft(for: receiptID, recognizedText: text) else {
                captureError = "The local draft could not be opened. Try another photo or enter details manually."
                return
            }
            activeDraft = draft
            if ReceiptDraftParser.needsManualInput(draft) {
                captureError = "We found partial receipt details. Complete the empty fields before confirming."
            } else {
                statusText = "Draft created"
            }
        case .failure(let error):
            activeDraft = store.createFailedDraft(for: receiptID)
            captureError = error.localizedDescription
        }
    }

    private func dismissPicker() {
        pickerSource = nil
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
                        ReceiptImagePreview(localImagePath: receipt.localImagePath)
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

struct ReceiptImagePreview: View {
    let localImagePath: String?

    var body: some View {
        Group {
            if let image = ReceiptImageStore.load(path: localImagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.62))
                    .cornerRadius(14)
                    .accessibilityLabel("Locally stored receipt image")
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.image")
                        .font(.title2)
                        .foregroundColor(LedgerTheme.inkSecondary)
                    Text("No image was saved for this receipt.")
                        .foregroundColor(LedgerTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 82)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LedgerTheme.rule, lineWidth: 1))
                .accessibilityLabel("No image was saved for this receipt")
            }
        }
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
