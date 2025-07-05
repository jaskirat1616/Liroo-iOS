import CoreData
import Combine // For future use if service returns Combine publishers

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    // A preview persistence controller for SwiftUI previews with sample data
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Add sample data for previews
        // Comment out or remove the creation of the sample book
        /*
        let book1 = Book(context: viewContext)
        book1.id = UUID()
        book1.title = "SwiftUI for Dummies (Preview)"
        book1.author = "Preview Author"
        book1.lastReadDate = Date()
        book1.progress = 0.5
        book1.isArchived = false // Ensure preview book is not archived
        */

        // You can keep other sample data if needed, for example, for ReadingLog
        let log1 = ReadingLog(context: viewContext)
        log1.id = UUID()
        log1.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        log1.duration = 30 * 60 // 30 minutes
        log1.wordsRead = 1500
        // book1.addToReadingLogs(log1) // If you add relationship - this would now cause an error if book1 is removed

        let log2 = ReadingLog(context: viewContext)
        log2.id = UUID()
        log2.date = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        log2.duration = 60 * 60 // 1 hour
        log2.wordsRead = 3000
        // book1.addToReadingLogs(log2) // This would also cause an error if book1 is removed

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo) during preview setup")
        }
        return controller
    }()

    init(inMemory: Bool = false) {
        // Name must match your .xcdatamodeld file name
        container = NSPersistentContainer(name: "LirooDataModel") 

        if inMemory {
            // For testing and previews, use an in-memory store
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate.
                // You should not use this function in a shipping application, although it may be useful during development.
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        // Automatically merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // Helper function to save context
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                // Consider robust error handling for production
                print("Error saving context: \(nsError), \(nsError.userInfo)")
                // fatalError("Unresolved error \(nsError), \(nsError.userInfo)") // Avoid fatalError in production
            }
        }
    }

    // MARK: - CoreData Migration Utility
    /// Call this once after adding the `isArchived` attribute to Book to ensure all existing books are properly configured.
    func migrateBooksSetIsArchivedAndLastReadDateIfNeeded() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        do {
            let books = try context.fetch(fetchRequest)
            var didChange = false
            for book in books {
                // Set isArchived = false if nil
                if book.value(forKey: "isArchived") == nil {
                    book.setValue(false, forKey: "isArchived")
                    didChange = true
                }
                // Optionally, set lastReadDate if nil (for testing)
                // Commenting this out to prevent old data from appearing new
                /*
                if book.lastReadDate == nil {
                    book.lastReadDate = Date()
                    didChange = true
                }
                */
            }
            if didChange {
                try context.save()
                print("[Migration] Updated Book records with missing isArchived.") // Modified log message
            }
        } catch {
            print("[Migration] Error updating Book records: \(error)")
        }
    }
}
