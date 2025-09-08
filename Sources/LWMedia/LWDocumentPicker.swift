import SwiftUI
import UniformTypeIdentifiers
@available(iOS 14.0, *)
public struct LWDocumentPicker: UIViewControllerRepresentable {
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf, .image, .text, .data], asCopy: true)
    }
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
