import Foundation
import SwiftData

/// A diary/journal entry with optional mood and energy tracking
@Model
public final class DiaryEntry {
    public var id: UUID = UUID()
    public var content: String = ""

    /// Mood level 1-5 (1 = very low, 5 = very high)
    public var moodLevel: Int = 3

    /// Energy level 1-5 (1 = very low, 5 = very high)
    public var energyLevel: Int = 3

    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

    /// Optional task association
    public var task: TrackedTask? = nil

    /// Optional place ID association
    public var placeID: UUID? = nil

    public init(content: String = "", moodLevel: Int = 3, energyLevel: Int = 3) {
        self.id = UUID()
        self.content = content
        self.moodLevel = max(1, min(5, moodLevel))
        self.energyLevel = max(1, min(5, energyLevel))
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Emoji representation of mood level
    public var moodEmoji: String {
        switch moodLevel {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }

    /// Emoji representation of energy level
    public var energyEmoji: String {
        switch energyLevel {
        case 1: return "🪫"
        case 2: return "🔋"
        case 3: return "🔋"
        case 4: return "⚡"
        case 5: return "⚡⚡"
        default: return "🔋"
        }
    }
}
