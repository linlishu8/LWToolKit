import SwiftUI
import UIKit
import PhotosUI

/**
 LWImagePicker
 ----------------
 作用：
 一个 **SwiftUI** 封装的系统图片选择器（`PHPickerViewController`）。
 支持：设置可选数量（`selectionLimit`）、自定义筛选（仅图片/仅视频/Live Photos 等），
 并通过回调返回所选的 `UIImage` 数组。

 使用示例：
 ```swift
 @State private var showing = false
 @State private var images: [UIImage] = []

 var body: some View {
     VStack {
         Button("选择图片") { showing = true }
         ScrollView(.horizontal) {
             HStack {
                 ForEach(images.indices, id: \.self) { i in
                     Image(uiImage: images[i])
                         .resizable()
                         .scaledToFill()
                         .frame(width: 80, height: 80)
                         .clipped()
                         .cornerRadius(10)
                 }
             }
         }
     }
     .sheet(isPresented: $showing) {
         // 允许最多选 5 张，仅图片
         LWImagePicker(selectionLimit: 5, filter: .images) { imgs in
             self.images = imgs
         } onCancel: {
             print("用户取消")
         }
     }
 }
 ```

 注意事项：
 - `PHPicker` 返回的是 **安全作用域资源**，本实现使用 `NSItemProvider` 加载为 `UIImage`；
   若需原始数据/EXIF，可扩展为 `loadFileRepresentation` 或 `loadDataRepresentation`。
 - `selectionLimit = 1` 表示单选；传 `0` 表示无限多选（系统会给出合理上限与 UI）。
 - 选择器不会弹系统权限框（与旧的 `UIImagePickerController` 不同），
   更友好且可同时从 iCloud 中选择照片。
 */
@available(iOS 14.0, *)
public struct LWImagePicker: UIViewControllerRepresentable {

    public typealias UIViewControllerType = PHPickerViewController

    // MARK: - Config
    public var selectionLimit: Int
    public var filter: PHPickerFilter
    public var onPick: ([UIImage]) -> Void
    public var onCancel: () -> Void

    // MARK: - Init
    public init(selectionLimit: Int = 1,
                filter: PHPickerFilter = .images,
                onPick: @escaping ([UIImage]) -> Void,
                onCancel: @escaping () -> Void = {}) {
        self.selectionLimit = selectionLimit
        self.filter = filter
        self.onPick = onPick
        self.onCancel = onCancel
    }

    // MARK: - Representable
    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = filter
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    // MARK: - Coordinator
    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: ([UIImage]) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // 没选即取消
            guard !results.isEmpty else {
                picker.dismiss(animated: true) { self.onCancel() }
                return
            }

            let group = DispatchGroup()
            var images: [UIImage] = []
            let lock = NSLock()

            for r in results {
                let provider = r.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let img = object as? UIImage {
                            lock.lock()
                            images.append(img)
                            lock.unlock()
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                picker.dismiss(animated: true) {
                    self.onPick(images)
                }
            }
        }
    }
}
