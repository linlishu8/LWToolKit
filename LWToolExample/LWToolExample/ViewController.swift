//
//  ViewController.swift
//  LWToolExample
//
//  Created by June on 2025/9/9.
//

import UIKit

final class ViewController: UIViewController {

    private lazy var networkButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Network Demos", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.backgroundColor = .systemYellow
        btn.setTitleColor(.black, for: .normal)
        btn.layer.cornerRadius = 10
        btn.addTarget(self, action: #selector(openNetworkDemo), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(networkButton)
        NSLayoutConstraint.activate([
            networkButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            networkButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            networkButton.widthAnchor.constraint(equalToConstant: 160),
            networkButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func openNetworkDemo() {
        let demo = DemoHomeViewController()
        if let nav = self.navigationController {
            nav.pushViewController(demo, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: demo)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}

