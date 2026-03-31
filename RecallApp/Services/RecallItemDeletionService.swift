import SwiftData

enum RecallItemDeletionService {
    static func delete(_ item: RecallItem, from modelContext: ModelContext) throws {
        let reviews = item.reviews ?? []

        try modelContext.transaction {
            for review in reviews {
                modelContext.delete(review)
            }

            item.reviews = nil
            modelContext.delete(item)
        }

        try modelContext.save()
    }
}
