import XCTest
@testable import ReceiptLedgerCore

final class LedgerCoreTests: XCTestCase {
    func testParsesUSAmount() {
        XCTAssertEqual(LedgerCore.parsedAmount("$48.20"), Decimal(string: "48.20"))
        XCTAssertNil(LedgerCore.parsedAmount("forty"))
    }

    func testCSVUsesHeaderAndDescendingDates() {
        let early = ExpenseEntry(receiptID: UUID(), merchant: "Parking", amount: 12.5, date: Date(timeIntervalSince1970: 1), category: .parking)
        let late = ExpenseEntry(receiptID: UUID(), merchant: "Supply, Co", amount: 48.2, date: Date(timeIntervalSince1970: 2), category: .materials, reviewedAt: Date())
        let csv = LedgerCore.csv(entries: [early, late])
        XCTAssertTrue(csv.hasPrefix("merchant,date,amount,category,reviewed"))
        XCTAssertTrue(csv.contains("\"Supply, Co\""))
        XCTAssertLessThan(csv.range(of: "Supply")!.lowerBound, csv.range(of: "Parking")!.lowerBound)
    }

    func testCandidateIsEditableBeforeConfirmation() {
        let receiptID = UUID()
        var draft = LocalDraftEngine.candidate(for: receiptID)
        draft.amount = "52.00"
        XCTAssertEqual(draft.receiptID, receiptID)
        XCTAssertEqual(draft.amount, "52.00")
        XCTAssertEqual(draft.state, .ready)
    }
}
