//
//  GalleryViewController.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/8.
//

import UIKit
import Photos
import AVKit

final class GalleryLastSaved {
    static let shared = GalleryLastSaved()
    var lastLocalIdentifier: String?
    private init() {}
}


final class GalleryViewController: UIViewController {

    private var collectionView: UICollectionView!
    private let imageManager = PHCachingImageManager()
    private var assets: [PHAsset] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "相簿影片"
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]

        setupCollectionView()
        setupCloseButton()
        checkPermissionAndLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAssets()
        scrollToLastSavedIfNeeded()
    }

    private func setupCloseButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "關閉", style: .done, target: self, action: #selector(close))
    }
    private func scrollToLastSavedIfNeeded() {
        guard let id = GalleryLastSaved.shared.lastLocalIdentifier else { return }
        let r = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let target = r.firstObject else { return }
        if let idx = assets.firstIndex(of: target) {
            let ip = IndexPath(item: idx, section: 0)
            collectionView.scrollToItem(at: ip, at: .centeredVertically, animated: true)
            // 清掉，避免每次都跳
            GalleryLastSaved.shared.lastLocalIdentifier = nil
        }
    }

    @objc private func close() { dismiss(animated: true) }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2
        let columns: CGFloat = 3
        let w = (view.bounds.width - (columns - 1) * spacing) / columns
        layout.itemSize = CGSize(width: w, height: w)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    

    private func checkPermissionAndLoad() {
        let s = PHPhotoLibrary.authorizationStatus()
        if s == .authorized {
            loadAssets()
        } else {
            PHPhotoLibrary.requestAuthorization { st in
                DispatchQueue.main.async {
                    st == .authorized ? self.loadAssets()
                    : self.showNoPermission()
                }
            }
        }
    }

    private func showNoPermission() {
        let lab = UILabel()
        lab.text = "沒有相簿讀取權限"
        lab.textColor = .white
        lab.textAlignment = .center
        lab.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lab)
        NSLayoutConstraint.activate([
            lab.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lab.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    

    private func loadAssets() {
        // 只抓影片，按建立時間由新到舊
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var tmp: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            tmp.append(asset)
        }
        self.assets = tmp

        self.collectionView.reloadData()
    }
}



// MARK: - DataSource & Delegate
extension GalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! GalleryCell
        let asset = assets[indexPath.item]

        let scale = UIScreen.main.scale
        let size = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize ?? CGSize(width: 120, height: 120)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        imageManager.requestImage(for: asset,
                                  targetSize: targetSize,
                                  contentMode: .aspectFill,
                                  options: options) { img, _ in
            cell.imageView.image = img
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets[indexPath.item]
        // 取得 AVPlayerItem 並播放
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.version = .original

        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
            guard let item = item else { return }
            DispatchQueue.main.async {
                let player = AVPlayer(playerItem: item)
                let vc = AVPlayerViewController()
                vc.player = player
                self.present(vc, animated: true) {
                    player.play()
                }
            }
        }
    }
}

// MARK: - Cell
final class GalleryCell: UICollectionViewCell {
    let imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
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
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}



