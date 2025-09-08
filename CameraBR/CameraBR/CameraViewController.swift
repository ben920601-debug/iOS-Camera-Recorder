//
//  CameraViewController.swift
//  CameraBR
//
//  Created by ㄓㄨㄥˋ誠 on 2025/9/8.
//

import UIKit
import AVFoundation
import Photos

final class CameraViewController: UIViewController {

    // MARK: - Capture
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDevice: AVCaptureDevice?
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var assets: [PHAsset] = []
    private var collectionView: UICollectionView!


    // MARK: - UI
    private let recordButton = UIButton(type: .system)
    private let switchButton = UIButton(type: .system)
    private let albumButton  = UIButton(type: .system)
    private let timerLabel   = UILabel()
    private var timer: Timer?
    private var startTime: Date?
    private let topBar = UIView()
    private let bottomBar = UIView()
    private let previewContainer = UIView()   // ← 新增：相機預覽的容器
    
    // Shield / Lock
    private let lockButton = UIButton(type: .system)
    private let shieldView = UIView()
    private let unlockTrack = UIView()
    private let unlockThumb = UIView()
    private var panStartX: CGFloat = 0
    private var wasStatusBarHidden = false
    private var savedBrightness: CGFloat = UIScreen.main.brightness
    private var isShieldOn = false
    
    private var hideStatusBar = false { didSet { setNeedsStatusBarAppearanceUpdate() } }
    override var prefersStatusBarHidden: Bool { hideStatusBar }
    
    // 相簿縮圖
    private let imageManager = PHCachingImageManager()
    private let albumThumbSide: CGFloat = 44 // Album 按鈕為正方形縮圖
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAlbumThumbnail()
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPreview()
        setupControls()
        requestPermissionsAndConfigure()

        // iOS 12：用通知監聽裝置方向
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deviceOrientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewContainer.bounds
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait, .landscapeLeft, .landscapeRight]
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateVideoOrientations()
            self.applyMirroring()
            self.previewLayer.frame = CGRect(origin: .zero, size: size)

            // 可選：橫向時降低 bar 高度
            let isLandscape = size.width > size.height
            let topH: CGFloat = isLandscape ? 44 : 60
            let bottomH: CGFloat = isLandscape ? 80 : 100
            // 找到對應的高度約束並更新（或改成把高度做成屬性記住再修改）
            for c in self.topBar.constraints where c.firstAttribute == .height { c.constant = topH }
            for c in self.bottomBar.constraints where c.firstAttribute == .height { c.constant = bottomH }
            self.view.layoutIfNeeded()
        })
    }
    
    final class GalleryLastSaved {
        static let shared = GalleryLastSaved()
        var lastLocalIdentifier: String?
        private init() {}
    }
    

    // MARK: - Permissions
    private func requestPermissionsAndConfigure() {
        let group = DispatchGroup()
        var camOK = false, micOK = false

        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { granted in camOK = granted; group.leave() }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { granted in micOK = granted; group.leave() }

        group.notify(queue: .main) {
            guard camOK && micOK else {
                self.presentAlert(title: "權限不足", message: "請在設定中允許相機與麥克風權限")
                return
            }
            self.configureSession()
        }
    }

    // MARK: - Setup capture session
    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // 後鏡頭
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoDevice = device
            }

            // 麥克風
            if let mic = AVCaptureDevice.default(for: .audio),
               let micIn = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(micIn) {
                self.session.addInput(micIn)
            }

            // 錄影輸出
            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()

            // 回主緒列更新方向/鏡像
            DispatchQueue.main.async {
                self.updateVideoOrientations()
                self.applyMirroring()
            }
        }
    }

    // MARK: - Preview layer
    private func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewContainer.layer.addSublayer(previewLayer)
       }

    // MARK: - Controls
    private func setupControls() {
        // === Bars ===
        topBar.backgroundColor = .black
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        bottomBar.backgroundColor = .black
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        let topH: CGFloat = 65
        let bottomH: CGFloat = 80

        NSLayoutConstraint.activate([
            // 上黑框延伸到狀態列底下
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: topH),

            // 下黑框貼安全區底部
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: bottomH)
        ])

        // === 中間相機預覽容器（夾在上下黑框之間） ===
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewContainer)
        view.bringSubviewToFront(topBar)
        view.bringSubviewToFront(bottomBar)
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // === 上黑框：計時器 + Lock ===
        // 計時器
        timerLabel.textColor = .white
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        timerLabel.text = "00:00"
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(timerLabel)
        
        NSLayoutConstraint.activate([
            // 貼齊 topBar 的下緣，避免與狀態列重疊
            timerLabel.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            timerLabel.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8)
            ])

        // Lock（右上角，圖示）
        let lockIcon = makeLockIcon(size: 20, lineWidth: 2, color: .white) // ↓ 第3步有方法
        lockButton.setImage(lockIcon, for: .normal)
        lockButton.tintColor = .white
        lockButton.backgroundColor = UIColor(white: 0.15, alpha: 1)
        lockButton.layer.cornerRadius = 8
        lockButton.translatesAutoresizingMaskIntoConstraints = false
        lockButton.addTarget(self, action: #selector(toggleShield), for: .touchUpInside)
        topBar.addSubview(lockButton)

        NSLayoutConstraint.activate([
            lockButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            lockButton.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8), // ✅ 貼齊上黑框下緣
            lockButton.widthAnchor.constraint(equalToConstant: 44),
            lockButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // === 下黑框：Album（左下） / REC（正下） / Flip（右下） ===
        // REC（大圓）
        recordButton.setTitle("REC", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = UIColor.red.withAlphaComponent(0.85)
        recordButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        recordButton.layer.cornerRadius = 30
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(toggleRecord), for: .touchUpInside)
        bottomBar.addSubview(recordButton)

        // Album（左下，顯示最新影片縮圖）
        // Album（左下，顯示最新影片縮圖）
        let albumBtn = albumButton // 只是取個短名
        albumBtn.setTitle(nil, for: .normal)
        albumBtn.backgroundColor = UIColor(white: 0.15, alpha: 1)
        albumBtn.layer.cornerRadius = 6
        albumBtn.clipsToBounds = true
        albumBtn.translatesAutoresizingMaskIntoConstraints = false
        albumBtn.addTarget(self, action: #selector(openAlbum), for: .touchUpInside)
        // 讓縮圖填滿按鈕
        albumBtn.imageView?.contentMode = .scaleAspectFill
        bottomBar.addSubview(albumBtn)
            
        // Flip（右）
        switchButton.setTitle("Flip", for: .normal)
        switchButton.setTitleColor(.white, for: .normal)
        switchButton.backgroundColor = UIColor(white: 0.15, alpha: 1)
        switchButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        switchButton.layer.cornerRadius = 8
        switchButton.translatesAutoresizingMaskIntoConstraints = false
        switchButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        bottomBar.addSubview(switchButton)

        NSLayoutConstraint.activate([
            // REC：正中間
            recordButton.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 60),
            recordButton.heightAnchor.constraint(equalToConstant: 60),

            // Album：左下
            albumBtn.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            albumBtn.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -8), // ✅ 貼齊下黑框下緣
            albumBtn.widthAnchor.constraint(equalToConstant: albumThumbSide),
            albumBtn.heightAnchor.constraint(equalToConstant: albumThumbSide),

            // Flip：右下
            switchButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            switchButton.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
            switchButton.widthAnchor.constraint(equalToConstant: 72),
            switchButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    // 3-1 程式畫「鎖」圖示
    private func makeLockIcon(size: CGFloat, lineWidth: CGFloat, color: UIColor) -> UIImage {
        let scale = UIScreen.main.scale
        let sz = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(sz, false, scale)
        let ctx = UIGraphicsGetCurrentContext()!

        color.setStroke()
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // 鎖體（方形）
        let bodyRect = CGRect(x: lineWidth,
                              y: size*0.45,
                              width: size - lineWidth*2,
                              height: size*0.45)
        let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: 3)
        bodyPath.stroke()

        // 鎖弓（上方半圓）
        let arcCenter = CGPoint(x: size/2, y: size*0.45)
        let radius = (size/2 - lineWidth*1.5)
        let arc = UIBezierPath(arcCenter: arcCenter,
                               radius: radius,
                               startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
        ctx.addPath(arc.cgPath)
        ctx.strokePath()

        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img.withRenderingMode(.alwaysTemplate)
    }

    // 讀取相簿權限後更新縮圖（iOS 12：.authorized / .denied / .restricted / .notDetermined）
    private func updateAlbumThumbnail() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized {
            loadLatestVideoThumb()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { s in
                DispatchQueue.main.async {
                    s == .authorized ? self.loadLatestVideoThumb() : self.albumButton.setImage(nil, for: .normal)
                }
            }
        } else {
            // 沒授權：顯示空白/預設
            albumButton.setImage(nil, for: .normal)
        }
    }

    private func loadLatestVideoThumb() {
        // 優先顯示剛剛存入的
        if let id = GalleryLastSaved.shared.lastLocalIdentifier {
            let r = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            if let a = r.firstObject {
                requestThumb(for: a) { [weak self] img in
                    self?.albumButton.setImage(img?.withRenderingMode(.alwaysOriginal), for: .normal)
                }
                return
            }
        }

        // 取“最新影片”
        let opt = PHFetchOptions()
        opt.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opt.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let result = PHAsset.fetchAssets(with: opt)
        guard let asset = result.firstObject else {
            albumButton.setImage(nil, for: .normal)
            return
        }
        requestThumb(for: asset) { [weak self] img in
            self?.albumButton.setImage(img?.withRenderingMode(.alwaysOriginal), for: .normal)
        }
    }

    private func requestThumb(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let scale = UIScreen.main.scale
        let size = CGSize(width: albumThumbSide * scale, height: albumThumbSide * scale)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat
        opts.resizeMode = .fast
        opts.isSynchronous = false
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
            completion(img)
        }
    }
    // MARK: - Orientation (iOS 12 相容)
    @objc private func deviceOrientationDidChange() {
        updateVideoOrientations()
        applyMirroring()
    }

    private func updateVideoOrientations() {
        let o = UIApplication.shared.statusBarOrientation
        let vo: AVCaptureVideoOrientation
        switch o {
        case .portrait:            vo = .portrait
        case .portraitUpsideDown:  vo = .portraitUpsideDown
        case .landscapeLeft:       vo = .landscapeLeft
        case .landscapeRight:      vo = .landscapeRight
        default:                   vo = .portrait
        }
        previewLayer.connection?.videoOrientation = vo
        movieOutput.connection(with: .video)?.videoOrientation = vo
    }

    private func applyMirroring() {
        let isFront = (videoDevice?.position == .front)
        if let c = previewLayer.connection, c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = isFront
        }
        if let vc = movieOutput.connection(with: .video), vc.isVideoMirroringSupported {
            vc.automaticallyAdjustsVideoMirroring = false
            vc.isVideoMirrored = isFront
        }
    }

    // MARK: - Actions
    @objc private func toggleRecord() {
        movieOutput.isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        UIApplication.shared.isIdleTimerDisabled = true

        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let st = self?.startTime else { return }
            let sec = Int(Date().timeIntervalSince(st))
            self?.timerLabel.text = String(format: "%02d:%02d", sec/60, sec%60)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mov")

        updateVideoOrientations()
        applyMirroring()
        movieOutput.startRecording(to: url, recordingDelegate: self)

        recordButton.setTitle("STOP", for: .normal)
        recordButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.9)
    }

    private func stopRecording() {
        movieOutput.stopRecording()
        UIApplication.shared.isIdleTimerDisabled = false

        timer?.invalidate(); timer = nil
        timerLabel.text = "00:00"

        recordButton.setTitle("REC", for: .normal)
        recordButton.backgroundColor = UIColor.red.withAlphaComponent(0.85)
    }

    @objc private func switchCamera() {
        sessionQueue.async {
            guard let currentInput = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput })
                    .first(where: { $0.device.hasMediaType(.video) }) else { return }

            let newPos: AVCaptureDevice.Position = (currentInput.device.position == .back) ? .front : .back

            // ✅ iOS 12 用小寫 .builtInWideAngleCamera
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPos),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDevice = newDevice
            } else {
                self.session.addInput(currentInput)
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.updateVideoOrientations()
                self.applyMirroring()
            }
        }
    }

    @objc private func openAlbum() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized {
            let vc = GalleryViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        } else {
            PHPhotoLibrary.requestAuthorization { s in
                DispatchQueue.main.async {
                    if s == .authorized {
                        let vc = GalleryViewController()
                        let nav = UINavigationController(rootViewController: vc)
                        nav.modalPresentationStyle = .fullScreen
                        self.present(nav, animated: true)
                    } else {
                        self.presentAlert(title: "無法開啟相簿", message: "請到設定 > 隱私權 > 照片，允許存取")
                    }
                }
            }
        }
    }

    // MARK: - Save to Photos
    private func saveToPhotos(_ fileURL: URL) {
        let doSave = {
            var createdId: String?

            PHPhotoLibrary.shared().performChanges({
                if let req = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL),
                   let ph = req.placeholderForCreatedAsset {
                    createdId = ph.localIdentifier
                }
            }) { success, err in
                // 清暫存
                try? FileManager.default.removeItem(at: fileURL)

                DispatchQueue.main.async {
                    GalleryLastSaved.shared.lastLocalIdentifier = createdId
                    self.updateAlbumThumbnail()
                }
            }
        }

        let status = PHPhotoLibrary.authorizationStatus() // iOS 12
        if status == .authorized {
            doSave()
        } else {
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        doSave()
                    } else {
                        self.presentAlert(title: "無相簿權限", message: "請到設定開啟「照片」存取權限")
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func presentAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

// MARK: - Delegate
extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        saveToPhotos(outputFileURL)
    }
    
    // 進入/離開 Shield
    @objc private func toggleShield() {
        isShieldOn ? hideShield() : showShield()
    }
    
    private func showShield() {
        guard !isShieldOn else { return }
        isShieldOn = true
        // 記住狀態列與亮度
        wasStatusBarHidden = prefersStatusBarHidden
        savedBrightness = UIScreen.main.brightness
        
        // 調暗螢幕（你可調到 0.0 ~ 0.1 之間）
        UIScreen.main.brightness = 0.01
        
        // 黑幕
        shieldView.frame = view.bounds
        shieldView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shieldView.backgroundColor = .black
        shieldView.isUserInteractionEnabled = true
        view.addSubview(shieldView)
        
        // 上方顯示提示
        let lab = UILabel()
        lab.text = "滑動解鎖 ▶︎"
        lab.textColor = UIColor(white: 1, alpha: 0.8)
        lab.font = .systemFont(ofSize: 16, weight: .medium)
        lab.translatesAutoresizingMaskIntoConstraints = false
        shieldView.addSubview(lab)
        NSLayoutConstraint.activate([
            lab.centerXAnchor.constraint(equalTo: shieldView.centerXAnchor),
            lab.topAnchor.constraint(equalTo: shieldView.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
        
        // 解鎖滑塊（下方水平滑動）
        unlockTrack.backgroundColor = UIColor(white: 1, alpha: 0.12)
        unlockTrack.layer.cornerRadius = 24
        unlockTrack.translatesAutoresizingMaskIntoConstraints = false
        shieldView.addSubview(unlockTrack)
        
        unlockThumb.backgroundColor = UIColor(white: 1, alpha: 0.9)
        unlockThumb.layer.cornerRadius = 20
        unlockThumb.translatesAutoresizingMaskIntoConstraints = true // 用 frame 方便拖曳
        unlockTrack.addSubview(unlockThumb)
        
        // 佈局滑道
        NSLayoutConstraint.activate([
            unlockTrack.leadingAnchor.constraint(equalTo: shieldView.leadingAnchor, constant: 24),
            unlockTrack.trailingAnchor.constraint(equalTo: shieldView.trailingAnchor, constant: -24),
            unlockTrack.bottomAnchor.constraint(equalTo: shieldView.safeAreaLayoutGuide.bottomAnchor, constant: -36),
            unlockTrack.heightAnchor.constraint(equalToConstant: 48)
        ])
        shieldView.layoutIfNeeded()
        unlockThumb.frame = CGRect(x: 4, y: 4, width: 40, height: 40)
        
        // 手勢：拖曳解鎖
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleUnlockPan(_:)))
        unlockThumb.addGestureRecognizer(pan)
        unlockThumb.isUserInteractionEnabled = true
        
        // 緊急解鎖：三擊任意處
        let tripleTap = UITapGestureRecognizer(target: self, action: #selector(emergencyUnlock))
        tripleTap.numberOfTapsRequired = 3
        shieldView.addGestureRecognizer(tripleTap)
        
        // 關閉狀態列（可選）
        hideStatusBar = true
    }
    
    private func hideShield() {
        guard isShieldOn else { return }
        isShieldOn = false
        
        // 還原亮度與狀態列
        UIScreen.main.brightness = savedBrightness
        hideStatusBar = wasStatusBarHidden
        
        // 清除黑幕
        unlockThumb.gestureRecognizers?.forEach { unlockThumb.removeGestureRecognizer($0) }
        shieldView.gestureRecognizers?.forEach { shieldView.removeGestureRecognizer($0) }
        shieldView.removeFromSuperview()
    }
    @objc private func handleUnlockPan(_ pan: UIPanGestureRecognizer) {
        guard let track = unlockThumb.superview else { return }
        let trans = pan.translation(in: track)
        
        switch pan.state {
        case .began:
            panStartX = unlockThumb.frame.origin.x
        case .changed:
            var x = panStartX + trans.x
            let minX: CGFloat = 4
            let maxX: CGFloat = track.bounds.width - unlockThumb.bounds.width - 4
            x = max(minX, min(maxX, x))
            unlockThumb.frame.origin.x = x
        case .ended, .cancelled:
            let maxX: CGFloat = track.bounds.width - unlockThumb.bounds.width - 4
            if unlockThumb.frame.origin.x >= maxX - 4 {
                // 抵達右端：解鎖
                hideShield()
            } else {
                // 彈回起點
                UIView.animate(withDuration: 0.2) {
                    self.unlockThumb.frame.origin.x = 4
                }
            }
        default: break
        }
    }
    
    @objc private func emergencyUnlock() {
        hideShield()
    }
}
