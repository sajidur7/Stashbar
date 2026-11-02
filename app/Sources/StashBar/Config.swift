import Foundation

/// Public client configuration. None of these values are secrets: Firebase web API keys
/// only identify the project, and access is enforced by Firestore security rules.
enum Config {
    static let firebaseProjectID = "stashbar-a2455"
    /// Firebase console → Project settings → General → Your apps → Web app → apiKey
    static let firebaseAPIKey = "FIREBASE_API_KEY"

    /// Hosted sign-in page (web/auth.html on Vercel). It runs Firebase's Google / Apple web flow
    /// and hands the session back to the app on a 127.0.0.1 loopback port.
    static let website = URL(string: "https://stashbar.vercel.app")!
    static var signInPage: URL { website.appendingPathComponent("auth") }
    static var helpPage: URL { website.appendingPathComponent("help") }
    static var privacyPage: URL { website.appendingPathComponent("privacy") }
    static let repo = URL(string: "https://github.com/sajidur7/Stashbar")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/sajidur7/Stashbar/releases/latest")!

    /// Apple sign-in needs an Apple Developer account (Services ID + key in Firebase).
    /// Flip to true once it's configured in the Firebase console.
    static let appleSignInEnabled = true

    static var isFirebaseConfigured: Bool { !firebaseAPIKey.isEmpty && firebaseAPIKey != "FIREBASE_API_KEY" }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
