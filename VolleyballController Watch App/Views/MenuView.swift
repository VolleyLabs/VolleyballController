import SwiftUI

struct MenuView: View {
    let points: [Point]
    let onReset: () -> Void
    let onShowHistory: () -> Void
    let onCancel: () -> Void
    let resetDisabled: Bool
    
    @State private var showingResetConfirmation = false
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Menu content
            VStack(spacing: 12) {
                Text("Menu")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(spacing: 6) {
                    Button {
                        onShowHistory()
                        onCancel()
                    } label: {
                        HStack {
                            Text("📋")
                            Text("History")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Text("🔄")
                            Text("Reset All")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(resetDisabled)
                    .foregroundColor(resetDisabled ? .gray : .white)
                    .background(resetDisabled ? Color.gray.opacity(0.3) : Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button {
                        onCancel()
                    } label: {
                        HStack {
                            Text("❌")
                            Text("Cancel")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .frame(maxWidth: 120)
        }
        .alert("Reset All Data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                onReset()
                onCancel()
            }
        } message: {
            Text("This will delete all today's points from the database and reset all scores. This action cannot be undone.")
        }
    }
}

#Preview {
    MenuView(
        points: [],
        onReset: {},
        onShowHistory: {},
        onCancel: {},
        resetDisabled: false
    )
}