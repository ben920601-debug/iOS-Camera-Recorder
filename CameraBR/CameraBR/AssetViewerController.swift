//
//  AssetViewerController.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/10.
//

import UIKit
import Photos
import AVKit

final class AssetViewerController: UIViewController {

    private let assets: [PHAsset]
    private var startIndex: Int
    private var collectionView: UICollectionView!
    private let pageControl = UIPageControl()
    private let imageManager = PHCachingImageManager()
    private var didSetInitialOffset = false

    init(assets: [PHAsset], startIndex: Int) {
        self.assets = assets
        self.startIndex = max(0, min(startIndex, assets.count - 1))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        view.backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        // CollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.itemSize = view.bounds.size

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(AssetPageCell.self, forCellWithReuseIdentifier: AssetPageCell.reuseId)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)

        // PageControl
        pageControl.numberOfPages = assets.count
        pageControl.currentPage = startIndex
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = .gray
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // 返回按鈕
        let backButton = UIButton(type: .system)
        backButton.setTitle("返回", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])

        // 上下滑關閉
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didSetInitialOffset && !assets.isEmpty {
            let start = CGPoint(x: CGFloat(startIndex) * view.bounds.width, y: 0)
            collectionView.setContentOffset(start, animated: false)
            pageControl.currentPage = startIndex
            didSetInitialOffset = true
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let v = g.velocity(in: view)
        let t = g.translation(in: view)
        if g.state == .ended {
            if abs(v.y) > 800 || abs(t.y) > view.bounds.height * 0.22 {
                dismiss(animated: true)
            }
        }
    }
}

// MARK: - DataSource
extension AssetViewerController: UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AssetPageCell.reuseId, for: indexPath) as! AssetPageCell
        let asset = assets[indexPath.item]

        if asset.mediaType == .video {
            cell.configureAsVideo()
            cell.onPlayTapped = { [weak self] in
                guard let self = self else { return }
                let opts = PHVideoRequestOptions()
                opts.isNetworkAccessAllowed = true
                PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                    guard let avAsset = avAsset else { return }
                    DispatchQueue.main.async {
                        let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                        let pvc = AVPlayerViewController()
                        pvc.player = player
                        self.present(pvc, animated: true) { player.play() }
                    }
                }
            }
        } else {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            PHImageManager.default().requestImage(for: asset,
                                                  targetSize: UIScreen.main.bounds.size,
                                                  contentMode: .aspectFit,
                                                  options: opts) { img, _ in
                cell.configureImage(img)
            }
        }
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = max(0, min(page, assets.count - 1))
    }
}

// MARK: - Cell
final class AssetPageCell: UICollectionViewCell {
    static let reuseId = "AssetPageCell"

    private let imageView = UIImageView()
    private let playOverlay = UILabel()
    var onPlayTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        playOverlay.text = "🎬 點擊播放"
        playOverlay.textAlignment = .center
        playOverlay.textColor = .white
        playOverlay.backgroundColor = UIColor(white: 0, alpha: 0.25)
        playOverlay.layer.cornerRadius = 10
        playOverlay.clipsToBounds = true
        playOverlay.isHidden = true
        playOverlay.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playOverlay)
        NSLayoutConstraint.activate([
            playOverlay.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playOverlay.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playOverlay.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),
            playOverlay.heightAnchor.constraint(equalToConstant: 44)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(playTapped))
        contentView.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureImage(_ image: UIImage?) {
        imageView.image = image
        playOverlay.isHidden = true
    }

    func configureAsVideo() {
        imageView.image = nil
        playOverlay.isHidden = false
    }

    @objc private func playTapped() {
        if !playOverlay.isHidden {
            onPlayTapped?()
        }
    }
  }

