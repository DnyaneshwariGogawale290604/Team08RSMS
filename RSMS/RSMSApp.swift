import SwiftUI

@main
struct RSMSApp: App {
    init() {
        let titleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        let boldTitleDescriptor = titleDescriptor.withSymbolicTraits(.traitBold) ?? titleDescriptor
        let titleFont = UIFont(descriptor: boldTitleDescriptor, size: 18)
        
        let largeTitleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let boldLargeTitleDescriptor = largeTitleDescriptor.withSymbolicTraits(.traitBold) ?? largeTitleDescriptor
        let largeTitleFont = UIFont(descriptor: boldLargeTitleDescriptor, size: 34)
        
        UINavigationBar.appearance().titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor(hex: "#1A1A1A")
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor(hex: "#1A1A1A")
        ]
        
        UISegmentedControl.appearance().selectedSegmentTintColor = .white
        UISegmentedControl.appearance().backgroundColor = .white
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.darkGray], for: .normal)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
