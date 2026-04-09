import Foundation
import SwiftData

@Model
final class Review {
    var id: UUID = UUID()
    var reviewedAt: Date = Date()
    /// Stored as a raw String — SwiftData cannot reliably persist custom Codable
    /// enums as stored properties on device. Access via the `rating` computed property.
    var ratingValue: String = Rating.missed.rawValue
    var recalledText: String?

    var item: RecallItem?

    /// Typed access to the stored rating value.
    var rating: Rating {
        get { Rating(rawValue: ratingValue) ?? .missed }
        set { ratingValue = newValue.rawValue }
    }

    init(rating: Rating, recalledText: String? = nil) {
        self.id = UUID()
        self.reviewedAt = Date()
        self.ratingValue = rating.rawValue
        self.recalledText = recalledText
    }
}
