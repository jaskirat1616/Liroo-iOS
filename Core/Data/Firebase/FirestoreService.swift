import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseCrashlytics

enum FirestoreError: Error {
    case encodingError
    case decodingError
    case documentNotFound
    case imageUploadError
    case unauthorized
    case quotaExceeded
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .encodingError:
            return "Failed to encode document"
        case .decodingError:
            return "Failed to decode document"
        case .documentNotFound:
            return "Document not found"
        case .imageUploadError:
            return "Failed to upload image"
        case .unauthorized:
            return "Unauthorized to perform this operation"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Storage Logger
private class StorageLogger {
    static func log(_ message: String, type: LogType = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = type.prefix
        print("[FirebaseStorage][\(timestamp)] \(prefix) \(message)")
    }
    
    enum LogType {
        case info
        case warning
        case error
        case success
        
        var prefix: String {
            switch self {
            case .info: return "ℹ️ INFO"
            case .warning: return "⚠️ WARNING"
            case .error: return "❌ ERROR"
            case .success: return "✅ SUCCESS"
            }
        }
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {
        StorageLogger.log("Initializing FirestoreService")
        StorageLogger.log("Storage bucket: \(storage.reference().bucket)")
    }
    
    // MARK: - Create
    func create<T: Encodable>(_ document: T, in collection: String, documentId: String? = nil) async throws -> String {
        print("[FirestoreService] Starting document creation process")
        print("[FirestoreService] Collection: \(collection)")
        print("[FirestoreService] Document ID provided: \(documentId ?? "nil")")
        
        do {
            let documentRef: DocumentReference
            if let documentId = documentId {
                documentRef = db.collection(collection).document(documentId)
                print("[FirestoreService] Using provided document ID: \(documentId)")
            } else {
                documentRef = db.collection(collection).document()
                print("[FirestoreService] Generated new document ID: \(documentRef.documentID)")
            }
            
            print("[FirestoreService] Setting document data using Firestore.Encoder")
            try await documentRef.setData(from: document)
            print("[FirestoreService] Successfully set document data")
            
            print("[FirestoreService] Verifying document creation")
            let snapshot = try await documentRef.getDocument()
            if snapshot.exists {
                print("[FirestoreService] Document verified to exist")
                print("[FirestoreService] Document data: \(snapshot.data() ?? [:])")
            } else {
                print("[FirestoreService] WARNING: Document does not exist after creation")
                
                CrashlyticsManager.shared.logNonFatalError(
                    message: "Document does not exist after creation",
                    context: "firestore_document_verification",
                    additionalData: [
                        "collection": collection,
                        "document_id": documentRef.documentID
                    ]
                )
            }
            
            print("[FirestoreService] Document creation completed successfully")
            return documentRef.documentID
        } catch {
            print("[FirestoreService] ERROR: Failed to create document in collection '\(collection)'")
            print("[FirestoreService] Error: \(error.localizedDescription)")
            
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "create",
                collection: collection,
                documentId: documentId
            )
            
            throw FirestoreError.unknown(error)
        }
    }
    
    // MARK: - Read
    func fetch<T: Decodable>(_ type: T.Type, from collection: String, documentId: String) async throws -> T {
        do {
            let document = try await db.collection(collection).document(documentId).getDocument()
            guard document.exists else {
                throw FirestoreError.documentNotFound
            }
            
            return try document.data(as: T.self)
        } catch let error as DecodingError {
            throw FirestoreError.decodingError
        } catch {
            throw FirestoreError.unknown(error)
        }
    }
    
    func fetchAll<T: Decodable>(_ type: T.Type, from collection: String) async throws -> [T] {
        do {
            let snapshot = try await db.collection(collection).getDocuments()
            return try snapshot.documents.compactMap { document in
                try document.data(as: T.self)
            }
        } catch let error as DecodingError {
            throw FirestoreError.decodingError
        } catch {
            throw FirestoreError.unknown(error)
        }
    }
    
    // MARK: - Update
    func update<T: Encodable>(_ document: T, in collection: String, documentId: String) async throws {
        do {
            try await db.collection(collection).document(documentId).setData(from: document, merge: true)
        } catch {
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "update",
                collection: collection,
                documentId: documentId
            )
            throw FirestoreError.unknown(error)
        }
    }
    
    // MARK: - Delete
    func delete(from collection: String, documentId: String) async throws {
        do {
            try await db.collection(collection).document(documentId).delete()
        } catch {
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "delete",
                collection: collection,
                documentId: documentId
            )
            throw FirestoreError.unknown(error)
        }
    }
    
    // MARK: - Query
    func query<T: Decodable>(_ type: T.Type, from collection: String, field: String, isEqualTo value: Any) async throws -> [T] {
        do {
            let snapshot = try await db.collection(collection)
                .whereField(field, isEqualTo: value)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: T.self)
            }
        } catch let error as DecodingError {
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "query_decode",
                collection: collection
            )
            throw FirestoreError.decodingError
        } catch {
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "query",
                collection: collection
            )
            throw FirestoreError.unknown(error)
        }
    }
    
    // MARK: - Image Storage
    enum UploadError: Error {
        case imageDataConversionFailed
        case uploadFailed(Error)
        case downloadURLNotFound
        case unknownError
    }

    func uploadImage(_ imageData: Data, path: String, metadata: StorageMetadata?) async throws -> URL {
        print("[FirebaseStorage][\(Date())] ℹ️ INFO Starting image upload process")
        print("[FirebaseStorage][\(Date())] ℹ️ INFO Path: \(path)")
        print("[FirebaseStorage][\(Date())] ℹ️ INFO Image data size: \(imageData.count) bytes")

        guard imageData.count > 0 else {
            let error = UploadError.imageDataConversionFailed
            
            CrashlyticsManager.shared.logFirebaseStorageError(
                error: error,
                operation: "upload",
                path: path,
                fileSize: 0
            )
            
            print("[FirebaseStorage][\(Date())] 🆘 ERROR Image data is empty.")
            throw error
        }

        let storageRef = storage.reference().child(path)
        print("[FirebaseStorage][\(Date())] ℹ️ INFO Created storage reference for path: \(storageRef.fullPath)")
        print("[FirebaseStorage][\(Date())] ℹ️ INFO Storage bucket: \(storageRef.bucket)")

        print("[FirebaseStorage][\(Date())] ℹ️ INFO Starting image upload with metadata...")
        if let meta = metadata {
            print("[FirebaseStorage][\(Date())] ℹ️ INFO Content type: \(meta.contentType ?? "Not set")")
            print("[FirebaseStorage][\(Date())] ℹ️ INFO Custom metadata: \(meta.customMetadata ?? [:])")
        }
            

        // Using async/await version of putData
        // This version doesn't require manual progress observation, which might be
        // where the NaN/Infinity issue is triggered if the SDK's internal progress is faulty
        // or if existing manual observation is not handling NaN/Infinity safely.
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putData(imageData, metadata: metadata) { resultMetadata, error in
                if let error = error {
                    print("[FirebaseStorage][\(Date())] 🆘 ERROR Uploading image to Firebase Storage failed for path: \(path)")
                    print("[FirebaseStorage][\(Date())] 🆘 ERROR Details: \(error.localizedDescription)")
                    // Log more detailed error information if available
                    let nsError = error as NSError
                    print("[FirebaseStorage][\(Date())] 🆘 ERROR Code: \(nsError.code), Domain: \(nsError.domain)")
                    print("[FirebaseStorage][\(Date())] 🆘 ERROR UserInfo: \(nsError.userInfo)")
                    
                    CrashlyticsManager.shared.logFirebaseStorageError(
                        error: error,
                        operation: "upload",
                        path: path,
                        fileSize: imageData.count
                    )
                    
                    continuation.resume(throwing: UploadError.uploadFailed(error))
                    return
                }

                guard resultMetadata != nil else {
                    let error = UploadError.unknownError
                    
                    CrashlyticsManager.shared.logFirebaseStorageError(
                        error: error,
                        operation: "upload_metadata",
                        path: path,
                        fileSize: imageData.count
                    )
                    
                    print("[FirebaseStorage][\(Date())] 🆘 ERROR Upload completed but metadata is nil for path: \(path).")
                    continuation.resume(throwing: error)
                    return
                }

                print("[FirebaseStorage][\(Date())] ✅ SUCCESS Image uploaded successfully to path: \(path)")
                
                // Get the download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("[FirebaseStorage][\(Date())] 🆘 ERROR Failed to get download URL for path: \(path)")
                        print("[FirebaseStorage][\(Date())] 🆘 ERROR Details: \(error.localizedDescription)")
                        
                        CrashlyticsManager.shared.logFirebaseStorageError(
                            error: error,
                            operation: "download_url",
                            path: path,
                            fileSize: imageData.count
                        )
                        
                        continuation.resume(throwing: UploadError.downloadURLNotFound)
                        return
                    }
                    
                    if let downloadURL = url {
                        print("[FirebaseStorage][\(Date())] ✅ SUCCESS Got download URL: \(downloadURL.absoluteString)")
                        continuation.resume(returning: downloadURL)
                    } else {
                        let error = UploadError.downloadURLNotFound
                        
                        CrashlyticsManager.shared.logFirebaseStorageError(
                            error: error,
                            operation: "download_url_nil",
                            path: path,
                            fileSize: imageData.count
                        )
                        
                        print("[FirebaseStorage][\(Date())] 🆘 ERROR Download URL is nil after successful fetch attempt for path: \(path).")
                        continuation.resume(throwing: error)
                }
            }
            }
        }
    }
    
    func deleteImage(at path: String) async throws {
        StorageLogger.log("Attempting to delete image at path: \(path)")
        do {
            let storageRef = storage.reference().child(path)
            try await storageRef.delete()
            StorageLogger.log("Successfully deleted image at path: \(path)", type: .success)
        } catch {
            StorageLogger.log("Failed to delete image at path: \(path)", type: .error)
            StorageLogger.log("Error: \(error.localizedDescription)", type: .error)
            
            CrashlyticsManager.shared.logFirebaseStorageError(
                error: error,
                operation: "delete",
                path: path
            )
            
            throw FirestoreError.unknown(error)
        }
    }
    
    // MARK: - Cleanup
    func cleanupOrphanedFiles(userId: String) async throws {
        StorageLogger.log("Starting cleanup of orphaned files for user: \(userId)")
        
        // Get all stories for the user
        let storiesSnapshot = try await db.collection("stories")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        // Get all user content for the user
        let contentSnapshot = try await db.collection("userGeneratedContent")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        // Collect all valid image paths
        var validImagePaths = Set<String>()
        
        // Add story chapter images
        for storyDoc in storiesSnapshot.documents {
            if let story = try? storyDoc.data(as: FirebaseStory.self),
               let chapters = story.chapters {
                for chapter in chapters {
                    if let imageUrl = chapter.imageUrl,
                       let path = extractPathFromUrl(imageUrl) {
                        validImagePaths.insert(path)
                        StorageLogger.log("Found valid story image path: \(path)")
                    }
                }
            }
        }
        
        // Add content block images
        for contentDoc in contentSnapshot.documents {
            if let content = try? contentDoc.data(as: FirebaseUserContent.self),
               let blocks = content.blocks {
                for block in blocks {
                    if let imageUrl = block.firebaseImageUrl,
                       let path = extractPathFromUrl(imageUrl) {
                        validImagePaths.insert(path)
                        StorageLogger.log("Found valid content image path: \(path)")
                    }
                }
            }
        }
        
        // List all files in user's storage folders
        let storageRef = storage.reference()
        let userStoriesRef = storageRef.child("stories/\(userId)")
        let userContentRef = storageRef.child("content/\(userId)")
        
        StorageLogger.log("Checking story images folder...")
        try await cleanupFolder(userStoriesRef, validImagePaths: validImagePaths)
        
        StorageLogger.log("Checking content images folder...")
        try await cleanupFolder(userContentRef, validImagePaths: validImagePaths)
        
        StorageLogger.log("Cleanup completed successfully", type: .success)
    }
    
    private func cleanupFolder(_ folderRef: StorageReference, validImagePaths: Set<String>) async throws {
        do {
            let result = try await folderRef.listAll()
            
            for item in result.items {
                let path = item.fullPath
                if !validImagePaths.contains(path) {
                    StorageLogger.log("Found orphaned file: \(path)", type: .warning)
                    try await item.delete()
                    StorageLogger.log("Deleted orphaned file: \(path)", type: .success)
                }
            }
            
            // Recursively check subfolders
            for prefix in result.prefixes {
                StorageLogger.log("Checking subfolder: \(prefix.fullPath)")
                try await cleanupFolder(prefix, validImagePaths: validImagePaths)
            }
        } catch {
            StorageLogger.log("Error during folder cleanup: \(error.localizedDescription)", type: .error)
            throw error
        }
    }
    
    private func extractPathFromUrl(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            StorageLogger.log("Invalid URL: \(urlString)", type: .error)
            return nil
        }
        
        // Extract path from Firebase Storage URL
        let components = url.pathComponents
        guard components.count >= 2 else {
            StorageLogger.log("Invalid URL path components: \(components)", type: .error)
            return nil
        }
        
        // Remove "v0" and "b" components from the path
        let pathComponents = components.filter { $0 != "v0" && $0 != "b" }
        let path = pathComponents.joined(separator: "/")
        StorageLogger.log("Extracted path from URL: \(path)")
        return path
    }
}
