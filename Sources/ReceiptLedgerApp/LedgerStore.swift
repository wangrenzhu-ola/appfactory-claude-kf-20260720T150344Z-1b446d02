import Combine
import Foundation

final class LedgerStore: ObservableObject {
    @Published private(set) var receipts: [Receipt] = []
    @Published private(set) var entries: [ExpenseEntry] = []
    @Published var remoteProcessingAllowed = false {
        didSet { save() }
    }
    @Published var didCompleteOnboarding = false {
        didSet { save() }
    }
    @Published var lastError: String?

    private let storageKey = "ReceiptLedger.localStore.v1"
    private var saveCancellable: AnyCancellable?

    init() {
        restore()
        saveCancellable = Publishers.CombineLatest($receipts, $entries)
            .dropFirst()
            .sink { [weak self] _, _ in self?.save() }
    }

    var unreviewedCount: Int { entries.filter { !$0.isReviewed }.count }

    func receipt(with id: UUID) -> Receipt? {
        receipts.first { $0.id == id }
    }

    func entry(for receiptID: UUID) -> ExpenseEntry? {
        entries.first { $0.receiptID == receiptID }
    }

    func createReceipt(title: String = "New local receipt", localImagePath: String? = nil) -> Receipt {
        let receipt = Receipt(title: title, localImagePath: localImagePath)
        receipts.insert(receipt, at: 0)
        return receipt
    }

    func beginDraft(for receiptID: UUID) {
        guard let receipt = receipt(with: receiptID) else { return }
        setDraft(
            ExpenseDraft(
                receiptID: receiptID,
                merchant: "",
                amount: "",
                date: receipt.capturedAt,
                category: .other,
                state: .creating
            ),
            for: receiptID
        )
    }

    func completeRecognizedDraft(for receiptID: UUID, recognizedText: String) -> ExpenseDraft? {
        guard let receipt = receipt(with: receiptID) else { return nil }
        let draft = ReceiptDraftParser.candidate(
            for: receiptID,
            recognizedText: recognizedText,
            capturedAt: receipt.capturedAt
        )
        setDraft(draft, for: receiptID)
        return draft
    }

    func createFailedDraft(for receiptID: UUID) -> ExpenseDraft? {
        guard let receipt = receipt(with: receiptID) else { return nil }
        let draft = ExpenseDraft(
            receiptID: receiptID,
            merchant: "",
            amount: "",
            date: receipt.capturedAt,
            category: .other,
            state: .failed
        )
        setDraft(draft, for: receiptID)
        return draft
    }

    func createManualDraft(for receiptID: UUID) -> ExpenseDraft {
        let capturedAt = receipt(with: receiptID)?.capturedAt ?? Date()
        let draft = ExpenseDraft(receiptID: receiptID, merchant: "", amount: "", date: capturedAt, category: .other, state: .manual)
        setDraft(draft, for: receiptID)
        return draft
    }

    func updateDraft(_ draft: ExpenseDraft) {
        setDraft(draft, for: draft.receiptID)
    }

    @discardableResult
    func confirm(_ draft: ExpenseDraft) -> Result<ExpenseEntry, LedgerError> {
        guard entry(for: draft.receiptID) == nil else {
            if let entry = entry(for: draft.receiptID) { return .success(entry) }
            return .failure(.duplicateEntry)
        }
        guard !draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.merchantMissing)
        }
        guard let amount = LedgerCore.parsedAmount(draft.amount), amount > 0 else {
            return .failure(.amountInvalid)
        }
        let entry = ExpenseEntry(receiptID: draft.receiptID, merchant: draft.merchant, amount: amount, date: draft.date, category: draft.category)
        entries.append(entry)
        updateReceipt(draft.receiptID) { receipt in
            receipt.entryID = entry.id
            receipt.draft = draft
        }
        return .success(entry)
    }

    func markReviewed(_ entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].reviewedAt = Date()
    }

    func deleteReceipt(_ receiptID: UUID) {
        receipts.removeAll { $0.id == receiptID }
    }

    func deleteEntry(_ entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }) else { return }
        entries.removeAll { $0.id == entryID }
        updateReceipt(entry.receiptID) { receipt in receipt.entryID = nil }
    }

    func clearAllLocalData() {
        receipts = []
        entries = []
        remoteProcessingAllowed = false
        lastError = nil
    }

    func entries(in month: Date) -> [ExpenseEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }.sorted { $0.date > $1.date }
    }

    func exportCSV(for month: Date) -> String {
        LedgerCore.csv(entries: entries(in: month))
    }

    private func setDraft(_ draft: ExpenseDraft, for receiptID: UUID) {
        updateReceipt(receiptID) { receipt in receipt.draft = draft }
    }

    private func updateReceipt(_ receiptID: UUID, update: (inout Receipt) -> Void) {
        guard let index = receipts.firstIndex(where: { $0.id == receiptID }) else { return }
        update(&receipts[index])
    }

    private func save() {
        let snapshot = StoredLedger(receipts: receipts, entries: entries, remoteProcessingAllowed: remoteProcessingAllowed, didCompleteOnboarding: didCompleteOnboarding)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(StoredLedger.self, from: data) else { return }
        receipts = snapshot.receipts
        entries = snapshot.entries
        remoteProcessingAllowed = snapshot.remoteProcessingAllowed
        didCompleteOnboarding = snapshot.didCompleteOnboarding
    }
}

private struct StoredLedger: Codable {
    var receipts: [Receipt]
    var entries: [ExpenseEntry]
    var remoteProcessingAllowed: Bool
    var didCompleteOnboarding: Bool
}

enum LedgerError: LocalizedError {
    case merchantMissing
    case amountInvalid
    case duplicateEntry

    var errorDescription: String? {
        switch self {
        case .merchantMissing: return "Add a merchant before confirming."
        case .amountInvalid: return "Enter an amount greater than zero."
        case .duplicateEntry: return "This receipt is already confirmed."
        }
    }
}
