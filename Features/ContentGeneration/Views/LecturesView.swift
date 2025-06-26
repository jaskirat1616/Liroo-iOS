import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LecturesView: View {
    @State private var lectures: [FirebaseLecture] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var isPresentingLecture = false
    @State private var selectedLecture: Lecture? = nil
    @State private var selectedLectureAudioFiles: [AudioFile] = []

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
                        Button {
                            presentLecture(lecture)
                        } label: {
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
            .sheet(isPresented: $isPresentingLecture) {
                if let lecture = selectedLecture {
                    LectureView(lecture: lecture, audioFiles: selectedLectureAudioFiles)
                }
            }
        }
    }

    private func fetchLectures() {
        isLoading = true
        errorMessage = nil
        lectures = []
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated."
            isLoading = false
            return
        }
        let db = Firestore.firestore()
        db.collection("lectures").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                guard let docs = snapshot?.documents else {
                    errorMessage = "No lectures found."
                    return
                }
                do {
                    lectures = try docs.compactMap { try $0.data(as: FirebaseLecture.self) }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func presentLecture(_ firebaseLecture: FirebaseLecture) {
        // Convert to Lecture and AudioFile models
        let sections = (firebaseLecture.sections ?? []).enumerated().map { index, section in
            LectureSection(
                id: UUID(uuidString: section.sectionId) ?? UUID(),
                title: section.title ?? "Section \(index + 1)",
                script: section.script ?? "",
                imagePrompt: section.imagePrompt ?? "",
                imageUrl: section.imageUrl,
                order: section.order ?? (index + 1)
            )
        }
        let lecture = Lecture(
            id: UUID(uuidString: firebaseLecture.id ?? "") ?? UUID(),
            title: firebaseLecture.title,
            sections: sections,
            level: ReadingLevel(rawValue: firebaseLecture.level) ?? .standard,
            imageStyle: firebaseLecture.imageStyle
        )
        let audioFiles = (firebaseLecture.audioFiles ?? []).map { audio in
            AudioFile(
                id: UUID(),
                type: AudioFileType(rawValue: audio.type ?? "section_script") ?? .sectionScript,
                text: audio.text ?? "",
                url: audio.url ?? "",
                filename: audio.filename ?? "",
                section: audio.section
            )
        }
        selectedLecture = lecture
        selectedLectureAudioFiles = audioFiles
        isPresentingLecture = true
    }
}

struct LecturesView_Previews: PreviewProvider {
    static var previews: some View {
        LecturesView()
    }
} 