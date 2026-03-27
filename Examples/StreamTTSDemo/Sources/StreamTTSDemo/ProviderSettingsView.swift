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
            TextField("Language Code", text: $viewModel.googleLanguageCode)
            TextField("Voice Name", text: $viewModel.googleVoiceName)
            TextField("Project ID (optional)", text: $viewModel.googleProjectID)
        }
    }
}
