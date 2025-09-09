
//
//  UIHelpers.swift
//
/*
 作用：
   提供 Demo 页面常用 UI 组件（滚动日志视图、按钮栈等）以减少重复代码。
 使用示例：
   let log = LogView()
   log.append("Hello")
   let btn = makeActionButton("触发") { ... }
*/

import UIKit
import SnapKit

final class LogView: UIView {
    private let textView = UITextView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8
        addSubview(textView)
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(6)
        }
        set(height: 180)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(height: CGFloat) {
        snp.remakeConstraints { make in
            make.height.equalTo(height)
        }
    }

    func setText(_ s: String) {
        textView.text = s
        textView.scrollRangeToVisible(NSRange(location: max(textView.text.count-1, 0), length: 1))
    }

    func append(_ s: String) {
        let prefix = textView.text.isEmpty ? "" : "\n"
        setText(textView.text + prefix + s)
    }
}

func makeActionButton(_ title: String, primary: Bool = true, action: @escaping () -> Void) -> UIButton {
    let btn = UIButton(type: .system)
    btn.setTitle(title, for: .normal)
    if primary {
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
    } else {
        btn.backgroundColor = .systemGray6
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.layer.borderColor = UIColor.systemBlue.cgColor
        btn.layer.borderWidth = 1
    }
    btn.layer.cornerRadius = 10
    btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    btn.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return btn
}
