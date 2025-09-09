import SwiftUI
import UIKit
import UniformTypeIdentifiers

/**
 LWDocumentPicker
 ----------------
 作用：
 一个 **SwiftUI 封装的文档选择器**（`UIDocumentPickerViewController`）。
 支持自定义文件类型（`UTType`）、是否拷贝到应用沙盒、是否多选，并通过回调把所选 URL 返回给上层。

 使用示例：
 ```swift
 @State private var showPicker = false
 @State private var picked: [URL] = []

 var body: some View {
     VStack {
         Button("选择文件") { showPicker = true }
         List(picked, id: \.self) { Text($0.lastPathComponent) }
     }
     .sheet(isPresented: $showPicker) {
         // 只选 PDF 与图片，多选，选择后自动拷贝副本
         LWDocumentPicker(
             contentTypes: [.pdf, .image],
             allowsMultipleSelection: true,
             asCopy: true,
             onPick: { urls in
                 self.picked = urls
             },
             onCancel: {
                 print("用户取消选择")
             }
         )
     }
 }
 ```

 注意事项：
 - 回调中的 URL 可能是 **安全作用域 URL**（iCloud/外部位置）。若需要长期读写，建议复制到应用沙盒后再使用。
 - 当 `asCopy = true` 时，系统会在可能的情况下提供副本（更安全）；如需直接访问原文件，可将其设为 `false`。
 - 某些类型（如 `.data`）非常宽泛，可能带来过多文件类型；请按需收窄 `contentTypes`。
 */
@available(iOS 14.0, *)
public struct LWDocumentPicker: UIViewControllerRepresentable {

    public typealias UIViewControllerType = UIDocumentPickerViewController

    // MARK: - Config
    public var contentTypes: [UTType]
    public var allowsMultipleSelection: Bool
    public var asCopy: Bool
    public var onPick: ([URL]) -> Void
    public var onCancel: () -> Void

    // MARK: - Init
    public init(contentTypes: [UTType] = [.pdf, .image, .text, .data],
                allowsMultipleSelection: Bool = false,
                asCopy: Bool = true,
                onPick: @escaping ([URL]) -> Void,
                onCancel: @escaping () -> Void = {}) {
        self.contentTypes = contentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.asCopy = asCopy
        self.onPick = onPick
        self.onCancel = onCancel
    }

    // MARK: - Representable
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: asCopy)
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = allowsMultipleSelection
        return vc
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    // MARK: - Coordinator
    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    public final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
