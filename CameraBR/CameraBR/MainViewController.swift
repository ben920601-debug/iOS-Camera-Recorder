//
//  MainViewController.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/10.
//

import UIKit

final class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupMenu()
    }

    private func setupMenu() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // 相機按鈕
        let cameraButton = makeButton(title: "📷 相機")
        cameraButton.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        stack.addArrangedSubview(cameraButton)

        // 相簿按鈕
        let galleryButton = makeButton(title: "🖼 相簿")
        galleryButton.addTarget(self, action: #selector(openGallery), for: .touchUpInside)
        stack.addArrangedSubview(galleryButton)

        // 設定按鈕
        let settingsButton = makeButton(title: "⚙️ 設定")
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        stack.addArrangedSubview(settingsButton)
    }

    private func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.backgroundColor = UIColor.darkGray
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    // MARK: - Actions
    @objc private func openCamera() {
        // 🚧 TODO: 這裡接你的相機邏輯
        let galleryVC = CameraViewController()
        galleryVC.modalPresentationStyle = .fullScreen
        present(galleryVC, animated: true)
    }

    @objc private func openGallery() {
        let galleryVC = GalleryViewController()
        galleryVC.modalPresentationStyle = .fullScreen
        present(galleryVC, animated: true)
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen
        present(settingsVC, animated: true)
    }
}
