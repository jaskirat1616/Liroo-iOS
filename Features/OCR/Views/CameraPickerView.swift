import SwiftUI
import AVFoundation // For camera permission check

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (UIImage?) -> Void

    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // Check if camera is available, otherwise use photo library as a fallback (or disable button)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            // Fallback or handle error: Camera not available
            // For this example, it will likely show a blank picker if .camera is forced on a simulator without camera
            // or on a device where camera access is restricted.
            // A real app should handle this more gracefully, perhaps by disabling the button
            // that presents this picker, or showing an alert.
            picker.sourceType = .photoLibrary // Fallback for simulator, or if camera is broken.
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("📷 CameraPicker Coordinator: didFinishPickingMediaWithInfo called.")
            print("📷 Info dictionary keys: \(info.keys)")

            var pickedImage: UIImage? = nil
            if let originalImage = info[.originalImage] as? UIImage {
                print("📷 Successfully cast .originalImage to UIImage.")
                pickedImage = originalImage
            } else {
                print("📷 Failed to get .originalImage as UIImage from info dictionary.")
            }
            
            // Update the binding (optional if callback is primary)
            parent.selectedImage = pickedImage
            // Call the new callback
            parent.onImagePicked(pickedImage)
            
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("📷 CameraPicker Coordinator: imagePickerControllerDidCancel called.")
            // Call callback with nil if cancelled, or if selectedImage was already nil.
            // This ensures the calling view knows cancellation happened.
            parent.onImagePicked(nil)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    // Helper function to check camera permissions
    static func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            completion(true)
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied: // The user has previously denied access.
            completion(false)
        case .restricted: // The user can't grant access due to restrictions.
            completion(false)
        @unknown default:
            completion(false)
        }
    }
} 