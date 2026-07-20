import SwiftUI

struct CaptureWorkbenchArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(LedgerTheme.graphite)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.76))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 0.34))
                }
                .stroke(LedgerTheme.amber.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
                VStack(spacing: 0) {
                    HStack { Image(systemName: "circle.fill").font(.caption2); Spacer(); Image(systemName: "barcode") }
                    Spacer()
                    VStack(alignment: .leading, spacing: 5) {
                        Capsule().frame(width: 88, height: 6)
                        Capsule().frame(width: 136, height: 6)
                        Capsule().frame(width: 64, height: 6)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundColor(LedgerTheme.graphite)
                .padding(18)
                .frame(width: proxy.size.width * 0.48, height: proxy.size.height * 0.72)
                .background(LedgerTheme.paper)
                .cornerRadius(10)
                .rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.22), radius: 7, x: 3, y: 6)
            }
        }
        .accessibilityLabel("Abstract local receipt workbench")
    }
}

struct ReviewHighlightArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18).fill(LedgerTheme.paperShadow)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Capsule().fill(LedgerTheme.graphite).frame(width: proxy.size.width * 0.34, height: 10)
                        Capsule().fill(LedgerTheme.moss).frame(width: proxy.size.width * 0.46, height: 22)
                        Capsule().fill(LedgerTheme.graphite.opacity(0.55)).frame(width: proxy.size.width * 0.27, height: 10)
                    }
                    Spacer()
                    Image(systemName: "pencil.line").font(.system(size: 36, weight: .medium)).foregroundColor(LedgerTheme.amber)
                }.padding(20)
            }
        }
        .accessibilityLabel("Editable draft field highlight")
    }
}

struct TallyArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 14) {
                TallyCard(number: "08", label: "unreviewed", fill: LedgerTheme.amber)
                TallyCard(number: "14", label: "reviewed", fill: LedgerTheme.moss)
                VStack(alignment: .leading, spacing: 8) {
                    Text("MONTHLY").font(.caption.weight(.bold)).tracking(1.5).foregroundColor(LedgerTheme.inkSecondary)
                    Text("Close the loop").font(.system(.title3, design: .serif).weight(.bold)).foregroundColor(LedgerTheme.graphite)
                    Rectangle().fill(LedgerTheme.rule).frame(height: 1)
                    Text("Review records, then export.").font(.caption).foregroundColor(LedgerTheme.inkSecondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel("Monthly expense tally")
    }
}

private struct TallyCard: View {
    let number: String
    let label: String
    let fill: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(number).font(.system(.title, design: .monospaced).weight(.bold)).foregroundColor(.white)
            Text(label).font(.caption2).foregroundColor(.white.opacity(0.88))
        }.padding(12).frame(width: 82, height: 88, alignment: .leading).background(fill).cornerRadius(16)
    }
}
