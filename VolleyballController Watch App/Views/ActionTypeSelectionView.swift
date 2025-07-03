import SwiftUI

struct ActionTypeSelectionView: View {
    let isLeft: Bool
    let onActionSelected: (PointType) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Point Type")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(PointType.allCases, id: \.self) { pointType in
                    Button(action: {
                        onActionSelected(pointType)
                    }) {
                        VStack(spacing: 2) {
                            Text(pointType.emoji)
                                .font(.title2)
                            Text(pointType.displayName)
                                .font(.system(size: 8))
                                .lineLimit(1)
                        }
                        .frame(width: 50, height: 40)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Cancel") {
                onCancel()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onTapGesture {
            onCancel()
        }
    }
}