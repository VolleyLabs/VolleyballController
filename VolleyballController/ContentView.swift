import SwiftUI

struct ContentView: View {
    @StateObject private var speechService = SpeechRecognitionService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("VolleyballController")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Companion App")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: speechService.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(speechService.hasPermission ? .green : .red)
                        Text("Speech Recognition")
                        Spacer()
                        Text(speechService.hasPermission ? "Enabled" : "Disabled")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: speechService.isWatchConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(speechService.isWatchConnected ? .green : .red)
                        Text("Watch Connection")
                        Spacer()
                        Text(speechService.connectionStatus)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    if let lastData = speechService.lastDataReceived {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                            Text("Last Audio Data")
                            Spacer()
                            Text(lastData, style: .time)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Voice Commands")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Say \"Left\" to add point to left team")
                        Text("• Say \"Right\" to add point to right team")
                        Text("• Say \"Cancel\" or \"Undo\" to reverse last action")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                if !speechService.commandHistory.isEmpty {
                    VStack(spacing: 8) {
                        Text("Recent Commands")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(speechService.commandHistory) { item in
                                    HStack {
                                        Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(item.success ? .green : .red)
                                            .font(.caption)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(item.command)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Text(item.timestamp, style: .time)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text("Said: \"\(item.transcription)\"")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
