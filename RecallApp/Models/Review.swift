import Foundation
import SwiftData

@Model
final class Review {
    // CloudKit requires all attributes to be optional or have stored default values.
    var id: UUID = UUID()
    var reviewedAt: Date = Date()
    var rating: Rating = Rating.forgot
    /// The text the user typed during recall, if any.
    var recalledText: String?

    /// Back-reference to the owning item. Managed by SwiftData via the
    /// inverse declared on RecallItem.reviews.
    var item: RecallItem?

    init(rating: Rating, recalledText: String? = nil) {
        self.id = UUID()
        self.reviewedAt = Date()
        self.rating = rating
        self.recalledText = recalledText
    }
}
