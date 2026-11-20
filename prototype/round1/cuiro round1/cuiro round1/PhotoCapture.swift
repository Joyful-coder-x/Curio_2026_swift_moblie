import PhotosUI
import SwiftUI
import UIKit

// Photo-library loading follows Joyce's Week 07 PhotosPicker/Transferable exercise:
// https://github.com/Joyful-coder-x/molab-2026-ima-joyce
// The camera/model separation follows the course MoGallery example:
// https://github.com/molab-itp/98-MoGallery
// Curio keeps the image as local JPEG data until its backend accepts an immutable upload.
struct PhotoSourceButtons: View {
    @Binding var photoItem: PhotosPickerItem?
    @Binding var showsCamera: Bool
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showsCamera = true
                } label: {
                    Label("Take photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
            if isLoading {
                ProgressView("Loading photo…")
            }
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                Text("Camera capture requires a physical iPhone. Use Photo Library or a sample in the simulator.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

enum PhotoSelectionError: Error {
    case invalidImage
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { parent.dismiss() }
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.82) else {
                return
            }
            parent.onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
