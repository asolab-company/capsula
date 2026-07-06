import SwiftUI
import UIKit

enum ProfilePhotoSource: String, Identifiable {
    case camera
    case gallery

    var id: String { rawValue }
}

struct ProfileCameraPicker: UIViewControllerRepresentable {
    var source: ProfilePhotoSource = .camera
    var onGallery: (() -> Void)?
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        let resolvedSourceType = resolvedSourceType
        picker.sourceType = resolvedSourceType

        if resolvedSourceType == .camera {
            picker.showsCameraControls = true
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            }
            if onGallery != nil {
                picker.cameraOverlayView = context.coordinator.makeGalleryOverlay()
            }
        }

        return picker
    }

    private var resolvedSourceType: UIImagePickerController.SourceType {
        #if targetEnvironment(simulator)
        return .photoLibrary
        #else
        switch source {
        case .camera:
            return UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        case .gallery:
            return .photoLibrary
        }
        #endif
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel, onGallery: onGallery)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void
        let onGallery: (() -> Void)?

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void, onGallery: (() -> Void)?) {
            self.onImage = onImage
            self.onCancel = onCancel
            self.onGallery = onGallery
        }

        func makeGalleryOverlay() -> UIView {
            let overlay = UIView(frame: UIScreen.main.bounds)
            overlay.backgroundColor = .clear
            overlay.isUserInteractionEnabled = true

            let button = UIButton(type: .system)
            button.frame = CGRect(x: overlay.bounds.width - 86, y: overlay.bounds.height - 122, width: 56, height: 56)
            button.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
            button.backgroundColor = UIColor.white.withAlphaComponent(0.19)
            button.layer.cornerRadius = 28
            button.clipsToBounds = true
            button.tintColor = .white
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(named: "app_btn_gallery")?.withRenderingMode(.alwaysTemplate) ?? UIImage(systemName: "photo")
            configuration.baseForegroundColor = .white
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            button.configuration = configuration
            button.imageView?.contentMode = .scaleAspectFit
            button.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)

            overlay.addSubview(button)
            return overlay
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }

            onImage(image.normalizedOrientation())
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        @objc private func galleryTapped() {
            onGallery?()
        }
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
