import SwiftUI

struct ContentView: View {

    @State private var vm = GlimpseViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer()

                // Glasses connection badge
                GlassesStatusBadge(state: vm.glasses.state)

                // Listening indicator / phase display
                PhaseView(phase: vm.phase, partialTranscript: vm.recognizer.partialTranscript)

                // Transcript + response
                if !vm.transcript.isEmpty {
                    ConversationBubble(role: "You", text: vm.transcript, color: .blue)
                }
                if !vm.lastResponse.isEmpty {
                    ConversationBubble(role: "Claude", text: vm.lastResponse, color: .indigo)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Glimpse")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $vm.showSettings) {
                SettingsView(vm: vm)
            }
            .task {
                await vm.setup()
            }
            .onDisappear {
                vm.teardown()
            }
        }
    }
}

// MARK: - Subviews

private struct GlassesStatusBadge: View {
    let state: GlassesState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private var dotColor: Color {
        switch state {
        case .connected, .streaming: return .green
        case .scanning, .connecting: return .yellow
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    private var label: String {
        switch state {
        case .disconnected: return "Glasses disconnected"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .streaming: return "Glasses connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

private struct PhaseView: View {
    let phase: AppPhase
    let partialTranscript: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: phaseIcon)
                .font(.system(size: 48))
                .foregroundStyle(phaseColor)
                .symbolEffect(.pulse, isActive: isAnimating)

            Text(phaseLabel)
                .font(.headline)
                .foregroundStyle(.secondary)

            if case .idle = phase, !partialTranscript.isEmpty {
                Text(partialTranscript)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .frame(height: 120)
    }

    private var phaseIcon: String {
        switch phase {
        case .idle: return "waveform.circle"
        case .processing: return "arrow.trianglehead.clockwise.rotate.90.circle"
        case .responding: return "speaker.wave.2.circle"
        case .error: return "exclamationmark.circle"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .idle: return .blue
        case .processing: return .orange
        case .responding: return .green
        case .error: return .red
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .idle: return "Listening..."
        case .processing: return "Thinking..."
        case .responding: return "Responding"
        case .error(let msg): return msg
        }
    }

    private var isAnimating: Bool {
        if case .idle = phase { return true }
        if case .processing = phase { return true }
        return false
    }
}

private struct ConversationBubble: View {
    let role: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(role)
                .font(.caption2)
                .foregroundStyle(color)
                .fontWeight(.semibold)
            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
