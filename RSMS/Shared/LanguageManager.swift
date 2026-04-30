import SwiftUI
import Combine

/// Manages in-app language switching between English and Hindi.
/// Uses UserDefaults + `appleLanguages` so the system picks it up on next launch,
/// and triggers an immediate full-app refresh via `@Published` + re-render trick.
class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            applyLanguage(currentLanguage)
        }
    }

    enum AppLanguage: String, CaseIterable, Identifiable {
        case english = "en"
        case hindi   = "hi"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .english: return "English"
            case .hindi:   return "हिन्दी"
            }
        }

        var flag: String {
            switch self {
            case .english: return "🇬🇧"
            case .hindi:   return "🇮🇳"
            }
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: "RSMSAppLanguage") ?? "en"
        currentLanguage = stored == "hi" ? .hindi : .english
    }

    private func applyLanguage(_ lang: AppLanguage) {
        UserDefaults.standard.set(lang.rawValue, forKey: "RSMSAppLanguage")
        // Tell iOS to use this language on next launch
        UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}

/// A reusable language picker row for profile / account sheets.
struct LanguageSwitcherRow: View {
    @ObservedObject private var lm = LanguageManager.shared
    @State private var showRestartAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Language / भाषा")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Select your preferred language")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $lm.currentLanguage) {
                    ForEach(LanguageManager.AppLanguage.allCases) { lang in
                        Text("\(lang.flag) \(lang.displayName)").tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: lm.currentLanguage) { _ in
                    showRestartAlert = true
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .alert("Restart Required / पुनः आरंभ करें", isPresented: $showRestartAlert) {
            Button("OK") { }
        } message: {
            Text("Please restart the app to apply the language change.\nभाषा परिवर्तन लागू करने के लिए ऐप को पुनः आरंभ करें।")
        }
    }
}
