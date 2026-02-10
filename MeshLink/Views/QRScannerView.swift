import SwiftUI
import AVFoundation

// MARK: - QR Scanner View (Fix #5)
struct QRScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onKeyScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onKeyScanned = { key in
            onKeyScanned(key)
            isPresented = false
        }
        vc.onDismiss = { isPresented = false }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - Scanner ViewController
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onKeyScanned: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupCamera()
        setupOverlay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showError("Camera not available")
            return
        }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }
    
    private func setupOverlay() {
        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeBtn)
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Scan MeshLink QR Code"
        titleLabel.textColor = .white
        titleLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Scan frame
        let frameView = UIView()
        frameView.layer.borderColor = UIColor(red: 0.2, green: 0.83, blue: 0.6, alpha: 0.8).cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 14
        frameView.backgroundColor = .clear
        frameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)
        
        // Hint label
        let hintLabel = UILabel()
        hintLabel.text = "Point camera at a MeshLink QR code"
        hintLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        hintLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            frameView.widthAnchor.constraint(equalToConstant: 240),
            frameView.heightAnchor.constraint(equalToConstant: 240),
            
            hintLabel.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 20),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    @objc private func closeTapped() {
        onDismiss?()
    }
    
    private func showError(_ text: String) {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let raw = metadata.stringValue else { return }
        
        // Parse meshlink://key/... URI
        if raw.hasPrefix("meshlink://key/") {
            let key = String(raw.dropFirst("meshlink://key/".count))
            if !key.isEmpty {
                hasScanned = true
                captureSession?.stopRunning()
                HapticService.shared.connect()
                onKeyScanned?(key)
            }
        }
    }
}
