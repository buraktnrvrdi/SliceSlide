import Foundation

/// Yerelleştirilmiş metin. Anahtar Türkçe kaynak metindir; çeviriler `Localizable.xcstrings` içindedir.
/// Biçim belirteçleri: `%lld` (Int), `%@` (String), yüzde işareti için `%%`.
/// Desteklenmeyen diller geliştirme diline (İngilizce) düşer.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, locale: Locale.current, arguments: args)
}

enum Lang {
    /// Uygulamanın kullandığı dil Türkçe mi?
    static let isTurkish = Bundle.main.preferredLocalizations.first == "tr"
}

/// Yüzde gösterimi: Türkçe "%40", diğer diller "40%".
func pctText(_ n: Int) -> String { Lang.isTurkish ? "%\(n)" : "\(n)%" }
