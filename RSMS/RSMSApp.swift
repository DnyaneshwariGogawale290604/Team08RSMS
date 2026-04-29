import SwiftUI

@main
struct RSMSApp: App {
    init() {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif)?.withSymbolicTraits(.traitBold)
        let largeDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif)?.withSymbolicTraits(.traitBold)
        
        let font = descriptor.map { UIFont(descriptor: $0, size: 17) } ?? UIFont.boldSystemFont(ofSize: 17)
        let largeFont = largeDescriptor.map { UIFont(descriptor: $0, size: 34) } ?? UIFont.boldSystemFont(ofSize: 34)
        
        UINavigationBar.appearance().titleTextAttributes = [.font: font]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeFont]
        
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
