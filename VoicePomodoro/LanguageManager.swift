import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("language") private var languageCode: String = "en"
    
    var isEnglish: Bool {
        get { languageCode == "en" }
        set { languageCode = newValue ? "en" : "zh" }
    }
    
    func localized(_ key: String) -> String {
        return LocalizedStrings.shared.string(for: key, language: languageCode)
    }
    
    func toggleLanguage() {
        isEnglish.toggle()
    }
} 