//
//  GalleryCell.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/11.
//

import UIKit
import Photos

final class GalleryCell: UICollectionViewCell {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // 照片顯示
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 預設邊框樣式
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = UIColor.clear.cgColor
    }

    func configure(with asset: PHAsset, deleteMode: Bool, isSelected: Bool) {
        // 載入縮圖
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false

        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 200, height: 200),
                             contentMode: .aspectFill,
                             options: options) { [weak self] image, _ in
            self?.imageView.image = image
        }

        // 更新紅色框框提示
        if deleteMode {
            if isSelected {
                contentView.layer.borderWidth = 3
                contentView.layer.borderColor = UIColor.red.cgColor
            } else {
                contentView.layer.borderWidth = 0
                contentView.layer.borderColor = UIColor.clear.cgColor
            }
        } else {
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = UIColor.clear.cgColor
        }
    }
}
