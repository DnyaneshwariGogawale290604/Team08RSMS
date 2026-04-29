import SwiftUI
import MessageUI

// MARK: - UIKit wrapper for MFMessageComposeViewController

struct MessageComposerView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinished: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinished: (MessageComposeResult) -> Void
        init(onFinished: @escaping (MessageComposeResult) -> Void) { self.onFinished = onFinished }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
            onFinished(result)
        }
    }
}

// MARK: - Helpers

/// Formats a purchase order notification message for a vendor.
/// `acceptLink` is a URL (or instruction string) the vendor can reply to accept.
func buildVendorPOMessage(
    poNumber: String,
    productName: String,
    quantity: Int,
    brandName: String,
    notes: String
) -> String {
    var msg = """
    📦 New Purchase Order from RSMS – \(brandName)

    PO Ref : \(poNumber)
    Product: \(productName)
    Qty    : \(quantity) units
    """
    if !notes.isEmpty {
        msg += "\nNotes  : \(notes)"
    }
    msg += """

    
    Please reply "ACCEPT \(poNumber)" to confirm the order and we will mark it In Transit.

    – RSMS Inventory
    """
    return msg
}

/// Extracts a plausible phone number from a vendor's contact_info string.
/// Falls back to `defaultPhone` when the contact string doesn't look like a number.
func extractPhone(from contactInfo: String?, defaultPhone: String) -> String {
    guard let info = contactInfo else { return defaultPhone }
    // Strip common separators and spaces
    let stripped = info.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    // Must be at least 10 digits to be a phone number
    if stripped.count >= 10 && stripped.allSatisfy({ $0.isNumber }) {
        return stripped
    }
    return defaultPhone
}
