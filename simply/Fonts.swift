import AppKit
import CoreText
import SwiftUI

enum AppFonts {
    static func registerBundledFonts() {
        let fm = FileManager.default
        var urls: [URL] = []

        for ext in ["otf", "ttf"] {
            if let found = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                urls.append(contentsOf: found)
            }
            if let found = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") {
                urls.append(contentsOf: found)
            }
        }

        if let fontsDir = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true),
           let files = try? fm.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)
        {
            urls.append(contentsOf: files.filter { ["otf", "ttf"].contains($0.pathExtension.lowercased()) })
        }

        for url in Set(urls) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// PostScript / family name for the wordmark. Frunchy Sage is a commercial face;
    /// drop the .otf/.ttf into simply/Fonts and rebuild, or install it in Font Book.
    static var wordmarkName: String {
        let candidates = [
            "Frunchy Sage",
            "Frunchy Sage Regular",
            "Frunchy Sage Light",
            "FrunchySage-Regular",
            "FrunchySage-Light",
            "Frunchy Serif",
            "Frunchy Serif Regular",
            "Frunchy Serif Light",
            "FrunchySerif-Regular",
            "FrunchySerif-Light",
        ]
        for name in candidates {
            if NSFont(name: name, size: 12) != nil {
                return name
            }
        }
        for family in NSFontManager.shared.availableFontFamilies {
            if family.localizedCaseInsensitiveContains("Frunchy") {
                if let members = NSFontManager.shared.availableMembers(ofFontFamily: family),
                   let postScript = members.first?.first as? String
                {
                    return postScript
                }
                return family
            }
        }
        return "Frunchy Sage"
    }

    static func wordmark(_ size: CGFloat) -> Font {
        .custom(wordmarkName, size: size)
    }
}
