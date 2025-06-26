import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LecturesView: View {
    @State private var lectures: [FirebaseLecture] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Lectures...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Text("Error loading lectures")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.red)
                        Button("Retry") { fetchLectures() }
                    }
                    .padding()
                } else if lectures.isEmpty {
                    Text("No lectures found.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(lectures) { lecture in
                        NavigationLink(destination: LectureDestinationView(
                            lectureID: lecture.id ?? "",
                            lectureTitle: lecture.title
                        )) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(lecture.title)
                                        .font(.headline)
                                    Text(lecture.createdAt?.dateValue() ?? Date(), style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.purple)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Lectures")
            .onAppear(perform: fetchLectures)
        }
    }

    private func fetchLectures() {
        isLoading = true
        errorMessage = nil
        
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("lectures")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }
                    
                    do {
                        let fetchedLectures = try snapshot?.documents.compactMap { document in
                            try document.data(as: FirebaseLecture.self)
                        } ?? []
                        self.lectures = fetchedLectures
                    } catch {
                        errorMessage = "Failed to decode lectures: \(error.localizedDescription)"
                    }
                }
            }
    }
}

struct LecturesView_Previews: PreviewProvider {
    static var previews: some View {
        LecturesView()
    }
} 