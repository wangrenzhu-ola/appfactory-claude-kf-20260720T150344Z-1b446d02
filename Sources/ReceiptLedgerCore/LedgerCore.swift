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
    public var localImagePath: String?
    public var draft: ExpenseDraft?
    public var entryID: UUID?

    public init(id: UUID = UUID(), capturedAt: Date = Date(), title: String, localImagePath: String? = nil, draft: ExpenseDraft? = nil, entryID: UUID? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.title = title
        self.localImagePath = localImagePath
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
        let ordered = entries.sorted { $0.date > $1.date }
        let rows = ordered.map { entry in
            let amount = String(
                format: "%.2f",
                locale: Locale(identifier: "en_US_POSIX"),
                NSDecimalNumber(decimal: entry.amount).doubleValue
            )
            return [entry.merchant, exportDateString(entry.date), amount, entry.category.rawValue, entry.isReviewed ? "true" : "false"]
                .map(csvCell)
                .joined(separator: ",")
        }
        return (["merchant,date,amount,category,reviewed"] + rows).joined(separator: "\n")
    }

    private static func exportDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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


public enum ReceiptDraftParser {
    public static func candidate(
        for receiptID: UUID,
        recognizedText: String,
        capturedAt: Date = Date()
    ) -> ExpenseDraft {
        let lines = recognizedText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let merchant = merchantCandidate(from: lines)
        let amount = amountCandidate(from: recognizedText)
        let date = dateCandidate(from: recognizedText) ?? capturedAt
        let category = categoryCandidate(from: recognizedText)
        let isComplete = !merchant.isEmpty && !amount.isEmpty
        return ExpenseDraft(
            receiptID: receiptID,
            merchant: merchant,
            amount: amount,
            date: date,
            category: category,
            state: isComplete ? .ready : .manual
        )
    }

    public static func needsManualInput(_ draft: ExpenseDraft) -> Bool {
        draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || LedgerCore.parsedAmount(draft.amount) == nil
    }

    private static func merchantCandidate(from lines: [String]) -> String {
        for line in lines {
            let lowercased = line.lowercased()
            let hasLetters = line.rangeOfCharacter(from: .letters) != nil
            let looksLikeLabel = ["total", "subtotal", "tax", "date", "thank", "change"].contains {
                lowercased.contains($0)
            }
            if hasLetters && !looksLikeLabel && line.count > 2 {
                return line.prefix(56).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private static func amountCandidate(from text: String) -> String {
        let pattern = #"(?i)(?:total|amount|balance)[^0-9]{0,12}\$?([0-9]{1,6}(?:[,.][0-9]{2}))|\$([0-9]{1,6}(?:[,.][0-9]{2}))"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return "" }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range) else { return "" }
        for group in [1, 2] where match.range(at: group).location != NSNotFound {
            guard let groupRange = Range(match.range(at: group), in: text) else { continue }
            return String(text[groupRange]).replacingOccurrences(of: ",", with: ".")
        }
        return ""
    }

    private static func dateCandidate(from text: String) -> Date? {
        let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            let expression = #"\b\d{1,4}[/-]\d{1,2}[/-]\d{2,4}\b"#
            guard let match = try? NSRegularExpression(pattern: expression).firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ), let range = Range(match.range, in: text) else { continue }
            if let date = formatter.date(from: String(text[range])) { return date }
        }
        return nil
    }

    private static func categoryCandidate(from text: String) -> ReceiptCategory {
        let value = text.lowercased()
        if value.contains("parking") || value.contains("garage") || value.contains("meter") { return .parking }
        if value.contains("flight") || value.contains("airline") || value.contains("hotel") || value.contains("fuel") { return .travel }
        if value.contains("restaurant") || value.contains("cafe") || value.contains("diner") || value.contains("coffee") { return .meals }
        if value.contains("lumber") || value.contains("hardware") || value.contains("supply") || value.contains("material") { return .materials }
        return .other
    }
}
