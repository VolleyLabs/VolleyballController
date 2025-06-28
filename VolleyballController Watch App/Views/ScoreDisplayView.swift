import SwiftUI

struct ScoreDisplayView: View {
    let leftWins: Int
    let rightWins: Int
    let connectionStatus: String
    let connectionColor: Color
    let isLoading: Bool
    let onReset: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Button("Reset") {
                onReset()
            }
            .font(.caption2)
            .buttonStyle(.borderless)
            .focusable(false)
            .padding(.trailing, 4)
        }
        .overlay(
            VStack(spacing: 2) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .scaleEffect(0.6)
                        .frame(height: 12)
                } else {
                    Text("\(leftWins) – \(rightWins)")
                        .font(.caption2)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 6, height: 6)
                    Text(connectionStatus)
                        .font(.system(size: 8))
                }
            },
            alignment: .center
        )
    }
}