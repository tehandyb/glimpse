import SwiftUI

struct SettingsView: View {

    let vm: GlimpseViewModel

    @State private var apiKeyInput: String = ""
    @State private var saved: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Anthropic API Key") {
                    SecureField("sk-ant-...", text: $apiKeyInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button(saved ? "Saved!" : "Save Key") {
                        vm.saveAPIKey(apiKeyInput)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            saved = false
                            dismiss()
                        }
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Model") {
                    Picker("Claude Model", selection: Binding(
                        get: { vm.claude.model },
                        set: { vm.claude.model = $0 }
                    )) {
                        ForEach(ClaudeModel.allCases, id: \.rawValue) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1 (MVP)")
                    LabeledContent("SDK", value: "Meta Wearables DAT")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Pre-fill with existing key (masked)
            if vm.claude.apiKey != nil {
                apiKeyInput = "••••••••••••••••"
            }
        }
    }
}
