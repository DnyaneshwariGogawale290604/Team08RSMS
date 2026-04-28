import SwiftUI
import UIKit
import AVFoundation

// MARK: - Barcode Scanner Coordinator (AVFoundation Camera)

public struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String, String) -> Void  // (code, symbology)
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }
    
    public func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    public func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
    
    public class Coordinator: NSObject, BarcodeScannerDelegate {
        let onCodeScanned: (String, String) -> Void
        
        init(onCodeScanned: @escaping (String, String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }
        
        func didScanCode(_ code: String, type: String) {
            onCodeScanned(code, type)
        }
    }
}

// MARK: - Scanner Delegate Protocol

@MainActor
protocol BarcodeScannerDelegate: AnyObject {
    func didScanCode(_ code: String, type: String)
}

// MARK: - Scanner UIViewController

public class BarcodeScannerViewController: UIViewController {
    
    weak var delegate: BarcodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraAuthAndSetup()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reset so the scanner can detect again when returning
        hasScanned = false
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func checkCameraAuthAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showFallbackLabel("Camera access was denied.\nPlease enable it in Settings > Privacy > Camera.")
                    }
                }
            }
        case .denied, .restricted:
            showFallbackLabel("Camera access is required to scan barcodes.\nPlease enable it in Settings > Privacy > Camera.")
        @unknown default:
            showFallbackLabel("Camera not available")
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showFallbackLabel("Camera not available on this device")
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .upce,
                .code128, .code39, .code93,
                .qr, .dataMatrix, .pdf417,
                .interleaved2of5, .itf14
            ]
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func showFallbackLabel(_ text: String) {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    /// Allow re-scanning after processing
    func resetScanner() {
        hasScanned = false
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate (separated for Swift 6 concurrency)

extension BarcodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        let typeString = readableObject.type.rawValue
        
        Task { @MainActor in
            guard !self.hasScanned else { return }
            self.hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            self.delegate?.didScanCode(stringValue, type: typeString)
        }
    }
}

// MARK: - Full-featured Scan View with camera overlay

public struct AddItemScanView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: InventoryDashboardViewModel
    
    public init(viewModel: InventoryDashboardViewModel) {
        self.viewModel = viewModel
        self._location = State(initialValue: viewModel.locations.first ?? "Warehouse")
    }
    
    // Scan state
    @State private var scannedCode: String? = nil
    @State private var scannedType: String = ""
    @State private var scanPhase: ScanPhase = .scanning
    
    // Item details (populated from scan or manually entered)
    @State private var selectedProduct: Product? = nil
    @State private var batchNo: String = "B-SCAN"
    @State private var location: String = "Warehouse"
    @State private var isTorchOn = false
    @State private var showSuccess = false
    @State private var scanCount = 0
    @State private var errorText: String?
    
    let availableCategories = ["Ring", "Necklace", "Bracelet", "Watch", "Handbag", "Earring", "Pendant", "Other"]
    
    enum ScanPhase {
        case scanning
        case scanned
        case details
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                switch scanPhase {
                case .scanning:
                    scanningPhaseView
                case .scanned:
                    scannedConfirmView
                case .details:
                    detailsFormView
                }
            }
            .navigationTitle(scanPhase == .scanning ? "Scan Barcode" : (scanPhase == .scanned ? "Code Detected" : "Item Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
                if scanCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(scanCount) added")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    // MARK: - Phase 1: Camera Scanning
    
    private var scanningPhaseView: some View {
        ZStack {
            BarcodeScannerRepresentable { code, type in
                scannedCode = code
                scannedType = type
                
                // Auto-parse: try to extract product info from code
                parseScannedCode(code)
                
                withAnimation(.spring()) {
                    scanPhase = .scanned
                }
            }
            .ignoresSafeArea()
            
            // Viewfinder overlay
            VStack {
                Spacer()
                
                ZStack {
                    // Scanning frame
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.appAccent, lineWidth: 3)
                        .frame(width: 280, height: 180)
                    
                    // Corner accents
                    ViewfinderCornersView()
                        .frame(width: 280, height: 180)
                    
                    // Animated scan line
                    ScanLineView()
                        .frame(width: 260, height: 160)
                }
                
                Spacer()
                
                // Bottom info bar
                VStack(spacing: 12) {
                    Text("Position barcode within the frame")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text("Supports EAN, UPC, QR, Code128, DataMatrix")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Torch toggle
                    Button(action: toggleTorch) {
                        HStack {
                            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            Text(isTorchOn ? "Torch On" : "Torch Off")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isTorchOn ? Color.yellow.opacity(0.8) : Color.white.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Phase 2: Code Scanned Confirmation
    
    private var scannedConfirmView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                }
                .padding(.top, 30)
                
                Text("Barcode Detected!")
                    .font(.title2.bold())
                    .foregroundColor(.appPrimaryText)
                
                // Scanned code card
                ReusableCardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "barcode")
                                .foregroundColor(.appAccent)
                            Text("Scanned Code")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        Text(scannedCode ?? "—")
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundColor(.appPrimaryText)
                            .textSelection(.enabled)
                        
                        HStack {
                            Text("Type: \(friendlyCodeType(scannedType))")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appBorder.opacity(0.5))
                                .cornerRadius(6)
                            
                            Spacer()
                            
                            Text("RFID: RFID-\(scannedCode?.prefix(8) ?? "0000")")
                                .font(.caption)
                                .foregroundColor(.appAccent)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        withAnimation { scanPhase = .details }
                    }) {
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                            Text("Fill Details & Add to Inventory")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    
                    Button(action: {
                        // Quick add with auto-parsed info
                        quickAddItem()
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Quick Add (Auto-Fill)")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    
                    Button(action: {
                        // Re-scan
                        scannedCode = nil
                        scannedType = ""
                        selectedProduct = nil
                        withAnimation { scanPhase = .scanning }
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Another")
                        }
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Phase 3: Detail Entry Form
    
    private var detailsFormView: some View {
        Form {
            Section(header: Text("Scanned Barcode")) {
                HStack {
                    Image(systemName: "barcode")
                        .foregroundColor(.appAccent)
                    Text(scannedCode ?? "—")
                        .font(.system(.body, design: .monospaced))
                }
                
                HStack {
                    Text("Code Type")
                        .foregroundColor(.appSecondaryText)
                    Spacer()
                    Text(friendlyCodeType(scannedType))
                        .foregroundColor(.appPrimaryText)
                }
            }
            
            Section(header: Text("Product Information")) {
                Picker("Select Product", selection: $selectedProduct) {
                    Text("Choose a product...").tag(nil as Product?)
                    ForEach(viewModel.products, id: \.id) { product in
                        Text(product.name).tag(product as Product?)
                    }
                }
                
                if let product = selectedProduct {
                    LabeledContent("Category", value: product.category.isEmpty ? "General" : product.category)
                        .foregroundColor(.appSecondaryText)
                }
                
                TextField("Batch Number", text: $batchNo)
            }
            
            Section(header: Text("Location")) {
                Picker("Storage Location", selection: $location) {
                    ForEach(viewModel.locations, id: \.self) { loc in
                        Text(loc).tag(loc)
                    }
                }
            }
            
            Section {
                Button(action: addItemFromScan) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Inventory")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(selectedProduct == nil ? Color.gray : Color.appAccent)
                    .cornerRadius(12)
                }
                .disabled(selectedProduct == nil)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            if let err = errorText {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Back to Scan") {
                    withAnimation { scanPhase = .scanned }
                }
                .foregroundColor(CatalogTheme.primaryText)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func parseScannedCode(_ code: String) {
        // Attempt to find product by SKU or name
        let cleanSKU = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = viewModel.products.first(where: { $0.sku?.localizedCaseInsensitiveContains(cleanSKU) == true || $0.name.localizedCaseInsensitiveContains(cleanSKU) }) {
            selectedProduct = match
        } else {
            selectedProduct = nil
        }
    }
    
    private func quickAddItem() {
        guard let _ = scannedCode else { return }
        
        // If we found a match automatically, add it immediately
        if selectedProduct != nil {
            addItemFromScan()
        } else {
            // Force user to pick a product
            withAnimation { scanPhase = .details }
        }
    }
    
    private func addItemFromScan() {
        guard let code = scannedCode, let product = selectedProduct else { return }
        let rfid = "RFID-\(code.prefix(8))-\(Int.random(in: 1000...9999))"
        
        Task {
            do {
                try await DataService.shared.incrementWarehouseInventoryForCurrentManager(
                    productId: product.id,
                    quantity: 1
                )
                
                let newItem = InventoryItem(
                    id: rfid,
                    serialId: "SN-\(Int.random(in: 1000...9999))",
                    productId: product.id,
                    batchNo: batchNo,
                    productName: product.name,
                    category: product.category.isEmpty ? "General" : product.category,
                    location: location,
                    status: .available
                )
                
                try await DataService.shared.insertInventoryItem(item: newItem)
                
                await MainActor.run {
                    scanCount += 1
                    showSuccess = true
                    
                    // Reset for next scan
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scannedCode = nil
                        scannedType = ""
                        selectedProduct = nil
                        batchNo = "B-SCAN"
                        withAnimation { scanPhase = .scanning }
                    }
                }
                await viewModel.loadDashboardData()
            } catch {
                await MainActor.run {
                    errorText = "Failed to save to Supabase: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isTorchOn.toggle()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
    
    private func friendlyCodeType(_ type: String) -> String {
        switch type {
        case "org.iso.QRCode": return "QR Code"
        case "org.iso.Code128": return "Code 128"
        case "org.gs1.EAN-13": return "EAN-13"
        case "org.gs1.EAN-8": return "EAN-8"
        case "org.gs1.UPC-E": return "UPC-E"
        case "org.iso.Code39": return "Code 39"
        case "org.iso.DataMatrix": return "Data Matrix"
        case "org.iso.PDF417": return "PDF417"
        default: return type.components(separatedBy: ".").last ?? type
        }
    }
}

// MARK: - Viewfinder Corner Accents

struct ViewfinderCornersView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cornerLen: CGFloat = 30
            let lineWidth: CGFloat = 4
            
            // Top-left
            Path { p in
                p.move(to: CGPoint(x: 0, y: cornerLen))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: cornerLen, y: 0))
            }
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Top-right
            Path { p in
                p.move(to: CGPoint(x: w - cornerLen, y: 0))
                p.addLine(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: cornerLen))
            }
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Bottom-left
            Path { p in
                p.move(to: CGPoint(x: 0, y: h - cornerLen))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: cornerLen, y: h))
            }
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Bottom-right
            Path { p in
                p.move(to: CGPoint(x: w - cornerLen, y: h))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w, y: h - cornerLen))
            }
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// MARK: - Animated Scan Line

struct ScanLineView: View {
    @State private var position: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.appAccent.opacity(0), Color.appAccent.opacity(0.8), Color.appAccent.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .offset(y: position)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        position = geo.size.height - 2
                    }
                }
        }
    }
}
