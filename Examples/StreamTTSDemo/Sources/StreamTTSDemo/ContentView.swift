import SwiftUI

/// Main window layout: provider picker, settings, text input, and playback controls.
struct ContentView: View {
    @State private var viewModel = TTSViewModel()

    var body: some View {
        Form {
            // MARK: - Provider picker
            Section("Provider") {
                Picker("Provider", selection: $viewModel.selectedProvider) {
                    ForEach(ProviderType.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // MARK: - Provider-specific settings
            ProviderSettingsView(viewModel: viewModel)

            // MARK: - Text input
            Section("Text to Speak") {
                TextEditor(text: $viewModel.inputText)
                    .frame(minHeight: 100)
                    .font(.body)
            }

            // MARK: - Controls
            Section {
                HStack {
                    statusLabel
                    Spacer()
                    if viewModel.isPlaying {
                        Button("Stop") {
                            viewModel.stop()
                        }
                        .keyboardShortcut(".", modifiers: .command)
                    }
                    Button("Speak") {
                        viewModel.speak()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!viewModel.canSpeak)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Status display

    @ViewBuilder
    private var statusLabel: some View {
        switch viewModel.status {
        case .ready:
            Text("Ready")
                .foregroundStyle(.secondary)
        case .connecting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Connecting...")
            }
        case .streaming:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Streaming...")
            }
        case .playing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Playing...")
            }
        case .finished:
            Text("Finished")
                .foregroundStyle(.green)
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
                .lineLimit(2)
                .help(message)
        }
    }
}
