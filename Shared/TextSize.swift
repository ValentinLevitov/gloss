import SwiftUI
import UIKit

/// User-selected text size, applied on top of the system Dynamic Type setting.
enum TextSize: String, CaseIterable, Identifiable {
    case system, small, medium, large, xLarge, xxLarge

    static let key = "textSize"
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xLarge: return "Extra large"
        case .xxLarge: return "Huge"
        }
    }

    /// `nil` keeps whatever the system provides.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system: return nil
        case .small: return .small
        case .medium: return .large
        case .large: return .xLarge
        case .xLarge: return .xxxLarge
        case .xxLarge: return .accessibility2
        }
    }

    static var current: TextSize {
        TextSize(rawValue: AppGroup.defaults.string(forKey: key) ?? "") ?? .system
    }
}

extension View {
    /// Applies the stored text size; falls through to the system size when "System" is selected.
    @ViewBuilder
    func appTextSize(_ size: TextSize) -> some View {
        if let dynamic = size.dynamicTypeSize {
            dynamicTypeSize(dynamic)
        } else {
            self
        }
    }
}

extension DynamicTypeSize {
    /// UIKit equivalent, for the UITextView-backed text.
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}
