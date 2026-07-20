import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if store.didCompleteOnboarding {
                TabView(selection: $selectedTab) {
                    NavigationView { CaptureView(selectedTab: $selectedTab) }
                        .tabItem { Label("Capture", systemImage: "camera.viewfinder") }
                        .tag(0)
                    NavigationView { ReceiptsView() }
                        .tabItem { Label("Receipts", systemImage: "doc.text") }
                        .tag(1)
                    NavigationView { MonthlyReviewView() }
                        .tabItem { Label("Review", systemImage: "checklist") }
                        .tag(2)
                    NavigationView { SettingsView() }
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(3)
                }
                .accentColor(LedgerTheme.moss)
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.light)
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var store: LedgerStore
    @State private var showPrivacy = false

    var body: some View {
        ZStack {
            LedgerTheme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 24)
                Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(LedgerTheme.moss)
                    .accessibilityHidden(true)
                Text("Receipt Ledger")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundColor(LedgerTheme.graphite)
                Text("Turn a receipt into a local expense record you can review later.")
                    .font(.title3)
                    .foregroundColor(LedgerTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                BoundaryNote(icon: "iphone", text: "Your receipts stay on this iPhone. You can delete local data at any time.")
                BoundaryNote(icon: "exclamationmark.circle", text: "Receipt Ledger is not tax advice. Device backups and recovery after moving or deleting the app are not guaranteed.")
                Spacer()
                Button(action: continueToLedger) {
                    HStack { Text("Continue to Capture"); Spacer(); Image(systemName: "arrow.right") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("Continue to Receipt Capture")
                Button("View privacy summary", action: { showPrivacy = true })
                    .font(.headline)
                    .foregroundColor(LedgerTheme.moss)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("View privacy summary")
            }
            .padding(28)
        }
        .sheet(isPresented: $showPrivacy) { PrivacySummaryView() }
    }

    private func continueToLedger() { store.didCompleteOnboarding = true }
}

struct PrivacySummaryView: View {
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy summary").font(.title2.bold())
                    Text("Draft suggestions in this version are created on your device. No receipt image is sent unless a future optional service is clearly explained before you choose it.")
                    Text("You can clear all local receipts and entries from Settings. Device backups are controlled by your device settings and are not guaranteed.")
                    Text("Manual entry is always available.")
                }
                .padding(24)
            }
            .navigationBarTitle("Privacy", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
        }
    }
}

struct BoundaryNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(LedgerTheme.moss).frame(width: 22)
            Text(text).font(.subheadline).foregroundColor(LedgerTheme.inkSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(LedgerTheme.paperShadow)
        .cornerRadius(14)
    }
}

enum LedgerTheme {
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let paperShadow = Color(red: 0.90, green: 0.88, blue: 0.80)
    static let graphite = Color(red: 0.17, green: 0.18, blue: 0.16)
    static let inkSecondary = Color(red: 0.35, green: 0.36, blue: 0.32)
    static let moss = Color(red: 0.23, green: 0.38, blue: 0.24)
    static let amber = Color(red: 0.67, green: 0.41, blue: 0.10)
    static let rule = Color(red: 0.75, green: 0.72, blue: 0.64)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(configuration.isPressed ? LedgerTheme.graphite : LedgerTheme.moss)
            .cornerRadius(14)
    }
}
