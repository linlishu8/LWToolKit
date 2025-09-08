import SwiftUI
import PhotosUI
@available(iOS 14.0, *)
public struct LWImagePicker: UIViewControllerRepresentable {
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var c = PHPickerConfiguration(photoLibrary: .shared()); c.filter = .images
        return PHPickerViewController(configuration: c)
    }
    public func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
}
