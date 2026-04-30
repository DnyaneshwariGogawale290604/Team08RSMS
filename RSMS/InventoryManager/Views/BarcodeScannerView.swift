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
            
            // Allow another scan after 1.5 seconds cooldown
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.hasScanned = false
            }
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
    
    // Tracking for animations
    @State private var lastScannedItem: InventoryItem? = nil
    @State private var showDuplicateError = false
    @State private var duplicateRFID: String? = nil
    
    let availableCategories = ["Ring", "Necklace", "Bracelet", "Watch", "Handbag", "Earring", "Pendant", "Other"]
    
    enum ScanPhase {
        case scanning
        case scanned
        case details
    }
    
    public var body: some View {
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
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                }
                .buttonStyle(.plain)
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
    
    // MARK: - Phase 1: Camera Scanning
    
    private var scanningPhaseView: some View {
        ZStack {
            BarcodeScannerRepresentable { code, type in
                scannedCode = code
                scannedType = type
                parseScannedCode(code)
                if selectedProduct == nil {
                    selectedProduct = viewModel.products.first
                }
                addItemFromScan()
            }
            .ignoresSafeArea()
            
            // Viewfinder overlay
            VStack {
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appAccent.opacity(0.6), lineWidth: 2)
                        .frame(width: 280, height: 180)
                    
                    ViewfinderCornersView()
                        .frame(width: 280, height: 180)
                    
                    ScanLineView()
                        .frame(width: 260, height: 160)
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Position barcode within the frame")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Text("Supports EAN, UPC, QR, Code128, DataMatrix")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Button(action: toggleTorch) {
                        HStack(spacing: 12) {
                            Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            Text(isTorchOn ? "Torch On" : "Torch Off")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isTorchOn ? Color.appAccent : Color.white.opacity(0.15))
                        .background(Blur(style: .systemThinMaterialDark))
                        .cornerRadius(100)
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Success Overlay
            if showSuccess, let item = lastScannedItem {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("Item Added!")
                            .font(.title3.bold())
                            .foregroundColor(.appPrimaryText)
                        
                        VStack(spacing: 12) {
                            detailRow(label: "Product", value: item.productName)
                            Divider().overlay(Color.black.opacity(0.08))
                            detailRow(label: "ID", value: item.id)
                            Divider().overlay(Color.black.opacity(0.08))
                            detailRow(label: "Location", value: item.location)
                        }
                        .padding()
                        .background(Color.appBackground)
                        .cornerRadius(16)
                    }
                    .padding(32)
                    .background(Color.appSurface)
                    .cornerRadius(24)
                    .shadow(radius: 20)
                    .padding(.horizontal, 40)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Phase 2: Code Scanned Confirmation
    
    private var scannedConfirmView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                    }
                    
                    Text("Barcode Detected!")
                        .font(.title2.bold())
                        .foregroundColor(.appPrimaryText)
                }
                .padding(.top, 40)
                
                ReusableCardView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scanned Value")
                                .font(.caption.bold())
                                .foregroundColor(.appSecondaryText)
                            Text(scannedCode ?? "—")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(.appAccent)
                        }
                        
                        Divider().overlay(Color.black.opacity(0.08))
                        
                        HStack {
                            Label(friendlyCodeType(scannedType), systemImage: "info.circle")
                                .font(.caption.bold())
                                .foregroundColor(.appSecondaryText)
                            Spacer()
                            Text("Auto-generated RFID")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 16) {
                    Button(action: quickAddItem) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Quick Add (Auto-Fill)")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: { withAnimation { scanPhase = .details } }) {
                        HStack {
                            Image(systemName: "pencil.and.list.clipboard")
                            Text("Customize Details")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.appPrimaryText)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
                    }
                    
                    Button(action: {
                        scannedCode = nil
                        scannedType = ""
                        selectedProduct = nil
                        withAnimation { scanPhase = .scanning }
                    }) {
                        Label("Scan Another", systemImage: "camera.viewfinder")
                            .font(.subheadline.bold())
                            .foregroundColor(.appSecondaryText)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Phase 3: Detail Entry Form
    
    private var detailsFormView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scanned Barcode").headingStyle()
                        .padding(.horizontal, 4)
                    
                    ReusableCardView {
                        VStack(spacing: 0) {
                            detailRow(label: "Code", value: scannedCode ?? "—")
                            Divider().overlay(Color.black.opacity(0.08))
                            detailRow(label: "Type", value: friendlyCodeType(scannedType))
                        }
                    }
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Product Information").headingStyle()
                        .padding(.horizontal, 4)
                    
                    ReusableCardView {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Product")
                                    .font(.caption.bold())
                                    .foregroundColor(.appSecondaryText)
                                Picker("Product", selection: $selectedProduct) {
                                    Text("Choose...").tag(nil as Product?)
                                    ForEach(viewModel.products, id: \.id) { product in
                                        Text(product.name).tag(product as Product?)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appBackground)
                                .cornerRadius(10)
                            }
                            
                            if let product = selectedProduct {
                                Divider().overlay(Color.black.opacity(0.08))
                                detailRow(label: "Category", value: product.category.isEmpty ? "General" : product.category)
                            }
                            
                            Divider().overlay(Color.black.opacity(0.08))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Batch Number")
                                    .font(.caption.bold())
                                    .foregroundColor(.appSecondaryText)
                                TextField("e.g. B-SCAN", text: $batchNo)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(12)
                                    .background(Color.appBackground)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Location").headingStyle()
                        .padding(.horizontal, 4)
                    
                    ReusableCardView {
                        HStack {
                            Text("Storage Location")
                                .font(.subheadline)
                                .foregroundColor(.appSecondaryText)
                            Spacer()
                            Picker("Location", selection: $location) {
                                ForEach(viewModel.locations, id: \.self) { loc in
                                    Text(loc).tag(loc)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button(action: addItemFromScan) {
                    HStack {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Inventory")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(selectedProduct == nil ? CatalogTheme.inactiveBadge : Color.appAccent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedProduct == nil)
                .padding(.horizontal, 20)

                if let err = errorText {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err).font(.caption.bold())
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                Button { withAnimation { scanPhase = .scanned } } label: {
                    Label("Back to Scan Summary", systemImage: "arrow.uturn.backward")
                        .font(.caption.bold())
                        .foregroundColor(.appSecondaryText)
                }
                .padding(.bottom, 20)
            }
            .padding(.vertical, 24)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.appPrimaryText)
        }
        .padding(.vertical, 12)
    }

    struct Blur: UIViewRepresentable {
        var style: UIBlurEffect.Style
        func makeUIView(context: Context) -> UIVisualEffectView {
            UIVisualEffectView(effect: UIBlurEffect(style: style))
        }
        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
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
        let rfid = code // Use exact barcode as unique ID
        
        Task {
            do {
                // First check if this exact RFID already exists
                if let existingItem = try? await DataService.shared.fetchInventoryItemByRFID(rfid), existingItem != nil {
                    // It's a duplicate!
                    await MainActor.run {
                        duplicateRFID = rfid
                        withAnimation { showDuplicateError = true }
                        
                        // Reset duplicate error overlay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showDuplicateError = false }
                            scannedCode = nil
                            scannedType = ""
                            selectedProduct = nil
                            duplicateRFID = nil
                        }
                    }
                    return
                }
                
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
                    lastScannedItem = newItem
                    withAnimation { showSuccess = true }
                    
                    // Reset for next scan without changing phase
                    // Give it a slightly longer delay so the user can read the details
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showSuccess = false }
                        scannedCode = nil
                        scannedType = ""
                        selectedProduct = nil
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
