import SwiftUI

@main
struct ReceiptLedgerApp: App {
    @StateObject private var store = LedgerStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
        }
    }
}
