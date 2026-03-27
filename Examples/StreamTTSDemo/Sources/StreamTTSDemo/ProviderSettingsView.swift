import SwiftUI

/// Credential and configuration forms for each TTS provider.
struct ProviderSettingsView: View {
    @Bindable var viewModel: TTSViewModel

    var body: some View {
        switch viewModel.selectedProvider {
        case .elevenLabs:
            elevenLabsSettings
        case .googleCloud:
            googleCloudSettings
        }
    }

    // MARK: - ElevenLabs

    @ViewBuilder
    private var elevenLabsSettings: some View {
        Section("ElevenLabs Credentials") {
            SecureField("API Key", text: $viewModel.elevenLabsAPIKey)
                .textContentType(.password)
            TextField("Voice ID", text: $viewModel.elevenLabsVoiceID)
                .textContentType(.none)
            Picker("Model", selection: $viewModel.elevenLabsModelID) {
                Text("Eleven Flash v2.5").tag("eleven_flash_v2_5")
                Text("Eleven Flash v2").tag("eleven_flash_v2")
                Text("Eleven Multilingual v2").tag("eleven_multilingual_v2")
                Text("Eleven Turbo v2.5").tag("eleven_turbo_v2_5")
                Text("Eleven Turbo v2").tag("eleven_turbo_v2")
            }
        }
    }

    // MARK: - Google Cloud

    @ViewBuilder
    private var googleCloudSettings: some View {
        Section("Google Cloud Credentials") {
            TextField("Access Token", text: $viewModel.googleAccessToken)
                .textContentType(.none)
            Text("Run `gcloud auth print-access-token` in Terminal")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Voice (Model)", selection: $viewModel.googleVoiceName) {
                Text("Chirp 3 HD Achernar (en-US-Chirp3-HD-Achernar)").tag("en-US-Chirp3-HD-Achernar")
                Text("Chirp 3 HD Aoede (en-US-Chirp3-HD-Aoede)").tag("en-US-Chirp3-HD-Aoede")
                Text("Journey D (en-US-Journey-D)").tag("en-US-Journey-D")
                Text("Journey F (en-US-Journey-F)").tag("en-US-Journey-F")
                Text("Journey O (en-US-Journey-O)").tag("en-US-Journey-O")
                Text("Neural2 F (en-US-Neural2-F)").tag("en-US-Neural2-F")
                Text("Neural2 J (en-US-Neural2-J)").tag("en-US-Neural2-J")
            }
            TextField("Project ID", text: $viewModel.googleProjectID)
        }
    }
}
