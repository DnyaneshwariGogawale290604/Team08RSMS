import SwiftUI
import CoreImage
import UIKit

struct QRCodeView: View {
    let qrString: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Scan to Pay")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.luxuryPrimaryText)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.luxurySecondaryText)
                        .padding(8)
                        .background(Color.luxurySurface)
                        .clipShape(Circle())
                }
            }
            .padding(.top, 8)
            
            // QR Code Container
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
                
                if let qrImage = generateQRCode(from: qrString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.luxuryPrimary)
                        Text("Generating QR Code...")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 20)
            
            // Footer Info
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.luxuryPrimary)
                    
                    Text("Scan with GPay, PhonePe, or any UPI app")
                        .font(BrandFont.body(14, weight: .medium))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                
                Text("Waiting for payment confirmation...")
                    .font(BrandFont.body(12))
                    .foregroundStyle(Color.luxurySecondaryText)
                    .italic()
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(Color.luxuryBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel") // Medium error correction
            
            if let outputImage = filter.outputImage {
                // Scale up the image as it's generated at a small size
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = outputImage.transformed(by: transform)
                
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        return nil
    }
}

#Preview {
    QRCodeView(qrString: "upi://pay?pa=test@vpa&pn=TestMerchant&am=100&cu=INR")
}
