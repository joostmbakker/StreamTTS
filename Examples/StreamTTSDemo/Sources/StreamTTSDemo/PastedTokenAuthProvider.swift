import StreamTTSGoogleCloud

/// A simple auth provider that returns a user-pasted OAuth2 access token.
///
/// Use this with tokens obtained from `gcloud auth print-access-token`.
/// Tokens expire after ~1 hour; paste a fresh one when needed.
struct PastedTokenAuthProvider: GoogleAuthProvider {
    let token: String

    func accessToken() async throws -> String { token }
}
