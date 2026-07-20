import Foundation

public enum ReceiptCategory: String, CaseIterable, Codable, Identifiable {
    case materials = "Materials"
    case parking = "Parking"
    case travel = "Travel"
    case meals = "Meals"
    case other = "Other"

    public var id: String { rawValue }
}

public struct ExpenseDraft: Identifiable, Codable, Equatable {
    public let id: UUID
    public let receiptID: UUID
    public var merchant: String
    public var amount: String
    public var date: Date
    public var category: ReceiptCategory
    public var state: DraftState

    public init(id: UUID = UUID(), receiptID: UUID, merchant: String, amount: String, date: Date, category: ReceiptCategory, state: DraftState = .ready) {
        self.id = id
        self.receiptID = receiptID
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.category = category
        self.state = state
    }
}

public enum DraftState: String, Codable {
    case creating
    case ready
    case failed
    case manual
}

public struct Receipt: Identifiable, Codable, Equatable {
    public let id: UUID
    public var capturedAt: Date
    public var title: String
    public var draft: ExpenseDraft?
    public var entryID: UUID?

    public init(id: UUID = UUID(), capturedAt: Date = Date(), title: String, draft: ExpenseDraft? = nil, entryID: UUID? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.title = title
        self.draft = draft
        self.entryID = entryID
    }

    public var statusLabel: String {
        if entryID != nil { return "Confirmed" }
        if draft?.state == .creating { return "Creating draft" }
        if draft?.state == .failed { return "Needs attention" }
        return "Ready to review"
    }
}

public struct ExpenseEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public let receiptID: UUID
    public var merchant: String
    public var amount: Decimal
    public var date: Date
    public var category: ReceiptCategory
    public var reviewedAt: Date?

    public init(id: UUID = UUID(), receiptID: UUID, merchant: String, amount: Decimal, date: Date, category: ReceiptCategory, reviewedAt: Date? = nil) {
        self.id = id
        self.receiptID = receiptID
        self.merchant = merchant
        self.amount = amount
        self.date = date
        self.category = category
        self.reviewedAt = reviewedAt
    }

    public var isReviewed: Bool { reviewedAt != nil }
}

public enum LedgerCore {
    public static func parsedAmount(_ value: String) -> Decimal? {
        let cleaned = value.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US"))
    }

    public static func csv(entries: [ExpenseEntry]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let ordered = entries.sorted { $0.date > $1.date }
        let rows = ordered.map { entry in
            let amount = NSDecimalNumber(decimal: entry.amount).stringValue
            return [entry.merchant, dateFormatter.string(from: entry.date), amount, entry.category.rawValue, entry.isReviewed ? "true" : "false"]
                .map(csvCell)
                .joined(separator: ",")
        }
        return (["merchant,date,amount,category,reviewed"] + rows).joined(separator: "\n")
    }

    private static func csvCell(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

public enum LocalDraftEngine {
    public static func candidate(for receiptID: UUID, capturedAt: Date = Date()) -> ExpenseDraft {
        ExpenseDraft(
            receiptID: receiptID,
            merchant: "Corner Materials",
            amount: "48.20",
            date: capturedAt,
            category: .materials,
            state: .ready
        )
    }
}
