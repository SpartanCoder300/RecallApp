import Foundation

/// The three possible outcomes a user can give when recalling an item.
enum Rating: String, Codable, CaseIterable {
    case forgot = "Forgot"
    case hard   = "Hard"
    case easy   = "Easy"
}
