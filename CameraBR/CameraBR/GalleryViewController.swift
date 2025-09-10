//
//  GalleryViewController.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/8.
//

import UIKit
import Photos

final class GalleryViewController: UIViewController {
    private var collectionView: UICollectionView!
    private var assets: [PHAsset] = []
    private var selectedAssets: [PHAsset] = []
    private var isDeleteMode = false

    private let backButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let topBar = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupTopBar()
        setupCollectionView()
        fetchAssets()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    override var prefersStatusBarHidden: Bool {
        return false   // ❌ 不要隱藏
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent   // ✅ 白色文字 (搭配黑色 bar)
    }
    
    // MARK: - UI
    private func setupTopBar() {

        topBar.backgroundColor = .black
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        
        let statusBarHeight = UIApplication.shared.statusBarFrame.height

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 33 + statusBarHeight)
        ])
        
        // Back Button
        backButton.setTitle("Back", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        topBar.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 20),
            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 15)
        ])

        // Action Button (選取/刪除)
        actionButton.setTitle("選取", for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(toggleDeleteMode), for: .touchUpInside)
        topBar.addSubview(actionButton)

        NSLayoutConstraint.activate([
            actionButton.topAnchor.constraint(equalTo: topBar.topAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16)
        ])
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 5
        layout.minimumLineSpacing = 5

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "GalleryCell")

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Data
    private func fetchAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        result.enumerateObjects { asset, _, _ in
            self.assets.append(asset)
        }

        collectionView.reloadData()
    }

    // MARK: - Actions
    @objc private func backTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func toggleDeleteMode() {
        isDeleteMode.toggle()
        actionButton.setTitle(isDeleteMode ? "刪除" : "選取", for: .normal)

        if !isDeleteMode {
            deleteSelectedAssets()
        } else {
            selectedAssets.removeAll()
        }

        collectionView.reloadData()
    }

    private func deleteSelectedAssets() {
        guard !selectedAssets.isEmpty else { return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.selectedAssets as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.assets.removeAll { self.selectedAssets.contains($0) }
                    self.selectedAssets.removeAll()
                    self.collectionView.reloadData()
                } else if let error = error {
                    print("刪除失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - CollectionView
extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as! GalleryCell
        let asset = assets[indexPath.item]
        let isSelected = selectedAssets.contains(asset)
        cell.configure(with: asset, deleteMode: isDeleteMode, isSelected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets[indexPath.item]

        if isDeleteMode {
            if let index = selectedAssets.firstIndex(of: asset) {
                // 已選取 → 取消
                selectedAssets.remove(at: index)
            } else {
                // 未選取 → 加入
                selectedAssets.append(asset)
            }
            // 更新紅框框顯示
            collectionView.reloadItems(at: [indexPath])
        } else {
            print("預覽照片：\(asset)")
        }
    }
}




