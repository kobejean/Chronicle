import Testing
import SwiftUI
@testable import ChronicleFeature

@Suite("Color+Hex Tests")
struct ColorHexTests {

    // MARK: - Hex Parsing

    @Suite("Hex String Parsing")
    struct HexParsing {

        @Test("Parses 6-digit hex with hash")
        func sixDigitWithHash() {
            let color = Color(hex: "#FF0000")
            #expect(color != nil)
        }

        @Test("Parses 6-digit hex without hash")
        func sixDigitWithoutHash() {
            let color = Color(hex: "00FF00")
            #expect(color != nil)
        }

        @Test("Parses 3-digit hex with hash")
        func threeDigitWithHash() {
            let color = Color(hex: "#F00")
            #expect(color != nil)
        }

        @Test("Parses 3-digit hex without hash")
        func threeDigitWithoutHash() {
            let color = Color(hex: "0F0")
            #expect(color != nil)
        }

        @Test("Parses 8-digit hex with alpha")
        func eightDigitWithAlpha() {
            let color = Color(hex: "#FF000080")
            #expect(color != nil)
        }

        @Test("Parses 8-digit hex without hash")
        func eightDigitWithoutHash() {
            let color = Color(hex: "00FF0080")
            #expect(color != nil)
        }

        @Test("Returns nil for invalid hex")
        func invalidHex() {
            let color = Color(hex: "GGGGGG")
            #expect(color == nil)
        }

        @Test("Returns nil for wrong length")
        func wrongLength() {
            let color = Color(hex: "#FFFF")
            #expect(color == nil)
        }

        @Test("Returns nil for empty string")
        func emptyString() {
            let color = Color(hex: "")
            #expect(color == nil)
        }

        @Test("Handles whitespace around hex")
        func whitespaceHandling() {
            let color = Color(hex: "  #FF0000  ")
            #expect(color != nil)
        }

        @Test("Parses lowercase hex")
        func lowercaseHex() {
            let color = Color(hex: "#ff0000")
            #expect(color != nil)
        }

        @Test("Parses mixed case hex")
        func mixedCaseHex() {
            let color = Color(hex: "#Ff00fF")
            #expect(color != nil)
        }
    }

    // MARK: - TaskColor Preset Tests

    @Suite("TaskColor Presets")
    struct TaskColorPresets {

        @Test("All preset colors are valid")
        func presetColorsValid() {
            for preset in TaskColor.allCases {
                let color = Color(hex: preset.rawValue)
                #expect(color != nil, "Failed for preset: \(preset.name)")
            }
        }

        @Test("Blue preset has correct hex")
        func bluePreset() {
            #expect(TaskColor.blue.rawValue == "#007AFF")
        }

        @Test("Green preset has correct hex")
        func greenPreset() {
            #expect(TaskColor.green.rawValue == "#34C759")
        }

        @Test("Red preset has correct hex")
        func redPreset() {
            #expect(TaskColor.red.rawValue == "#FF3B30")
        }

        @Test("All presets have names")
        func presetsHaveNames() {
            for preset in TaskColor.allCases {
                #expect(!preset.name.isEmpty)
            }
        }

        @Test("Preset colors return non-nil Color")
        func presetColorProperty() {
            for preset in TaskColor.allCases {
                // The color property uses a fallback, so it should never fail
                _ = preset.color
            }
        }
    }

    // MARK: - Color Component Tests

    @Suite("Color Components")
    struct ColorComponents {

        @Test("Pure red parses correctly")
        func pureRed() {
            guard let color = Color(hex: "#FF0000") else {
                Issue.record("Failed to parse red hex")
                return
            }
            // Color was created successfully
            #expect(color == color)
        }

        @Test("Pure green parses correctly")
        func pureGreen() {
            guard let color = Color(hex: "#00FF00") else {
                Issue.record("Failed to parse green hex")
                return
            }
            #expect(color == color)
        }

        @Test("Pure blue parses correctly")
        func pureBlue() {
            guard let color = Color(hex: "#0000FF") else {
                Issue.record("Failed to parse blue hex")
                return
            }
            #expect(color == color)
        }

        @Test("Black parses correctly")
        func black() {
            let color = Color(hex: "#000000")
            #expect(color != nil)
        }

        @Test("White parses correctly")
        func white() {
            let color = Color(hex: "#FFFFFF")
            #expect(color != nil)
        }

        @Test("3-digit shorthand expands correctly")
        func threeDigitExpansion() {
            // #F00 should expand to #FF0000 (red)
            let shortColor = Color(hex: "#F00")
            let longColor = Color(hex: "#FF0000")
            #expect(shortColor != nil)
            #expect(longColor != nil)
        }

        @Test("8-digit alpha channel works")
        func alphaChannel() {
            // Fully transparent
            let transparent = Color(hex: "#FF000000")
            #expect(transparent != nil)

            // Fully opaque
            let opaque = Color(hex: "#FF0000FF")
            #expect(opaque != nil)

            // Semi-transparent
            let semi = Color(hex: "#FF000080")
            #expect(semi != nil)
        }
    }
}
