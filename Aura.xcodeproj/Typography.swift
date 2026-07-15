import SwiftUI

public enum AppFont {
    // Primary brand font name
    public static let brandName = "MarkerFelt-Thin"
}

public extension Font {
    // Brand font helpers with sensible defaults
    static func brand(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // MarkerFelt-Thin has limited weights; we ignore weight and rely on size
        return .custom(AppFont.brandName, size: size)
    }

    static var brandLargeTitle: Font { .custom(AppFont.brandName, size: 34) }
    static var brandTitle: Font { .custom(AppFont.brandName, size: 28) }
    static var brandHeadline: Font { .custom(AppFont.brandName, size: 17) }
    static var brandCaption: Font { .custom(AppFont.brandName, size: 11) }
}

// A ViewModifier to apply brand font to any text hierarchy
public struct BrandFont: ViewModifier {
    let size: CGFloat
    public init(_ size: CGFloat) { self.size = size }
    public func body(content: Content) -> some View {
        content.font(.custom(AppFont.brandName, size: size))
    }
}

public extension View {
    func brandFont(_ size: CGFloat) -> some View { self.modifier(BrandFont(size)) }
}

// Convenience modifiers for system default and bold when needed remain via .font(.body) and .bold().
