import SwiftUI

public extension Color {
    /// Initialize Color from hex string
    /// Supports formats: "#RGB", "#RRGGBB", "#RRGGBBAA", "RGB", "RRGGBB", "RRGGBBAA"
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var red: Double = 0.0
        var green: Double = 0.0
        var blue: Double = 0.0
        var alpha: Double = 1.0

        let length = hexSanitized.count
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        switch length {
        case 3: // RGB (12-bit)
            red = Double((rgb & 0xF00) >> 8) / 15.0
            green = Double((rgb & 0x0F0) >> 4) / 15.0
            blue = Double(rgb & 0x00F) / 15.0
        case 6: // RRGGBB (24-bit)
            red = Double((rgb & 0xFF0000) >> 16) / 255.0
            green = Double((rgb & 0x00FF00) >> 8) / 255.0
            blue = Double(rgb & 0x0000FF) / 255.0
        case 8: // RRGGBBAA (32-bit)
            red = Double((rgb & 0xFF000000) >> 24) / 255.0
            green = Double((rgb & 0x00FF0000) >> 16) / 255.0
            blue = Double((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = Double(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Convert Color to hex string
    var hexString: String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }

        let red = Int(components[0] * 255)
        let green = Int(components.count > 1 ? components[1] * 255 : components[0] * 255)
        let blue = Int(components.count > 2 ? components[2] * 255 : components[0] * 255)

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

/// Preset task colors
public enum TaskColor: String, CaseIterable {
    case blue = "#007AFF"
    case green = "#34C759"
    case red = "#FF3B30"
    case orange = "#FF9500"
    case yellow = "#FFCC00"
    case purple = "#AF52DE"
    case pink = "#FF2D55"
    case teal = "#5AC8FA"
    case indigo = "#5856D6"
    case mint = "#00C7BE"
    case brown = "#A2845E"
    case gray = "#8E8E93"

    public var color: Color {
        Color(hex: rawValue) ?? .blue
    }

    public var name: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .teal: return "Teal"
        case .indigo: return "Indigo"
        case .mint: return "Mint"
        case .brown: return "Brown"
        case .gray: return "Gray"
        }
    }
}
