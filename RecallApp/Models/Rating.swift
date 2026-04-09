import Foundation

/// The three possible outcomes a user can give when recalling an item.
enum Rating: String, Codable, CaseIterable {
    case missed  = "Missed"
    case partial = "Partial"
    case nailed  = "Nailed"
}
