import Foundation

/// Interface preferences are independent of the languages sent to the transcription API.
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    static let defaultsKey = "interfaceLanguage"
    var id: String { rawValue }
    var nativeName: String { self == .chinese ? "简体中文" : "English" }
    var locale: Locale { Locale(identifier: self == .chinese ? "zh_CN" : "en_US") }

    static func resolve(savedValue: String?, preferredLanguages: [String]) -> AppLanguage {
        if let savedValue, let language = AppLanguage(rawValue: savedValue) { return language }
        return preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? .chinese : .english
    }
}

/// Matches application-generated messages containing values such as progress or error codes.
/// Capture groups are inserted as values, never interpreted as format strings.
struct LocalizedMessagePattern {
    let expression: NSRegularExpression
    let englishTemplate: String
    let translatedArguments: Set<Int>

    init(_ regex: String, _ englishTemplate: String, translatedArguments: Set<Int> = []) {
        precondition(regex.hasPrefix("^") && regex.hasSuffix("$"), "Localization patterns must match a whole message")
        expression = try! NSRegularExpression(pattern: regex, options: [.dotMatchesLineSeparators])
        self.englishTemplate = englishTemplate
        self.translatedArguments = translatedArguments
    }
}

/// Keep canonical application messages in state and localize at the presentation boundary.
/// This updates already-visible warnings on a language change without rewriting user data.
enum AppLocalization {
    static let strings = serviceStrings.merging(modelStrings) { _, new in new }
        .merging(uiStrings) { _, new in new }
    static let patterns = modelPatterns + servicePatterns

    static func text(_ message: String, language: AppLanguage) -> String {
        translated(message, language: language, remainingDepth: 6)
    }

    static func formatted(_ key: String, language: AppLanguage, arguments: [CVarArg]) -> String {
        String(format: text(key, language: language), locale: language.locale, arguments: arguments)
    }

    private static func translated(_ message: String, language: AppLanguage, remainingDepth: Int) -> String {
        guard language == .english else { return message }
        if let result = strings[message] { return result }
        guard remainingDepth > 0 else { return message }
        let fullRange = NSRange(message.startIndex..<message.endIndex, in: message)
        for pattern in patterns {
            guard let match = pattern.expression.firstMatch(in: message, range: fullRange),
                  match.range == fullRange else { continue }
            let values: [CVarArg] = (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: message) else { return "" }
                let value = String(message[range])
                return pattern.translatedArguments.contains(index - 1)
                    ? translated(value, language: language, remainingDepth: remainingDepth - 1)
                    : value
            }
            return String(format: pattern.englishTemplate, locale: language.locale, arguments: values)
        }
        // Unknown system error descriptions retain the text supplied by macOS.
        return message
    }
}
