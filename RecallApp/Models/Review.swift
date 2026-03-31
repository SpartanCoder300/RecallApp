import Foundation
import SwiftData

@Model
final class Review {
    var id: UUID
    var reviewedAt: Date
    var rating: Rating
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
