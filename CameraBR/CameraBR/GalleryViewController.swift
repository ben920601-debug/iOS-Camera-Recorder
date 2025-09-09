//
//  GalleryViewController.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/8.
//

import UIKit
import Photos

final class GalleryViewController: UIViewController {

    private var assets: [PHAsset] = []
    private var collectionView: UICollectionView!
    private var selectedAssets: Set<IndexPath> = []
    private var deleteButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCollectionView()
        setupLongPressGesture()
        checkPhotoPermission()
    }

    // MARK: - CollectionView
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let itemSize = (UIScreen.main.bounds.width - 3) / 4
        layout.itemSize = CGSize(width: itemSize, height: itemSize)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
    }

    // MARK: - 權限
    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized {
            loadAssets()
        } else {
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    self.loadAssets()
                }
            }
        }
    }

    private func loadAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let results = PHAsset.fetchAssets(with: fetchOptions)
        assets.removeAll()
        results.enumerateObjects { asset, _, _ in
            self.assets.append(asset)
        }
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    // MARK: - 長按觸發多選模式
    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            if deleteButton == nil {
                addDeleteButton()
            }
        }
    }

    // MARK: - 刪除按鈕
    private func addDeleteButton() {
        deleteButton = UIButton(type: .system)
        deleteButton?.setTitle("刪除", for: .normal)
        deleteButton?.setTitleColor(.red, for: .normal)
        deleteButton?.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
        deleteButton?.layer.cornerRadius = 8
        deleteButton?.translatesAutoresizingMaskIntoConstraints = false
        deleteButton?.addTarget(self, action: #selector(deleteSelectedAssets), for: .touchUpInside)

        if let btn = deleteButton {
            view.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                btn.widthAnchor.constraint(equalToConstant: 60),
                btn.heightAnchor.constraint(equalToConstant: 35)
            ])
        }
        
        let backButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            backButton.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
            backButton.tintColor = .white
        } else {
            backButton.setTitle("Back", for: .normal)
            backButton.setTitleColor(.white, for: .normal)
        }
        backButton.backgroundColor = UIColor(white: 0.15, alpha: 1)
        backButton.layer.cornerRadius = 8
        backButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
        backButton.heightAnchor.constraint(equalToConstant: 36),
        backButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }

    @objc private func deleteSelectedAssets() {
        guard !selectedAssets.isEmpty else { return }
        let assetsToDelete = selectedAssets.map { assets[$0.item] }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { success, error in
            if success {
                self.selectedAssets.removeAll()
                self.loadAssets()
                DispatchQueue.main.async {
                    self.deleteButton?.removeFromSuperview()
                    self.deleteButton = nil
                }
            } else {
                print("❌ 刪除失敗: \(String(describing: error))")
            }
        }
    }
}

// MARK: - UICollectionView
extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as! GalleryCell
        let asset = assets[indexPath.item]

        let manager = PHImageManager.default()
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 200, height: 200),
                             contentMode: .aspectFill,
                             options: nil) { image, _ in
            cell.imageView.image = image
        }

        cell.layer.borderWidth = selectedAssets.contains(indexPath) ? 3 : 0
        cell.layer.borderColor = UIColor.red.cgColor

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if deleteButton != nil {
            // 多選模式
            if selectedAssets.contains(indexPath) {
                selectedAssets.remove(indexPath)
            } else {
                selectedAssets.insert(indexPath)
            }
            collectionView.reloadItems(at: [indexPath])
        } else {
            // ✅ 正常模式 → 打開檢視器
            let vc = AssetViewerController(assets: assets, startIndex: indexPath.item)
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
}

// MARK: - Cell
final class GalleryCell: UICollectionViewCell {
    let imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}



