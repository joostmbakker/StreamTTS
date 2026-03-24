/// Provides OAuth2 access tokens for Google Cloud API authentication.
/// The adapter calls this before each stream and on 401 responses.
public protocol GoogleAuthProvider: Sendable {
    /// Retrieves a valid OAuth2 access token.
    /// - Returns: A valid token string.
    func accessToken() async throws -> String
}
