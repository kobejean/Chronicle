import Foundation

public extension TimeInterval {
    /// Format as "Xh Ym" or "Xm Ys" depending on duration
    var shortFormatted: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    /// Format as "X hours Y minutes" or "X minutes Y seconds"
    var longFormatted: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            let hourText = hours == 1 ? "hour" : "hours"
            let minuteText = minutes == 1 ? "minute" : "minutes"
            return "\(hours) \(hourText) \(minutes) \(minuteText)"
        } else if minutes > 0 {
            let minuteText = minutes == 1 ? "minute" : "minutes"
            let secondText = seconds == 1 ? "second" : "seconds"
            return "\(minutes) \(minuteText) \(seconds) \(secondText)"
        } else {
            let secondText = seconds == 1 ? "second" : "seconds"
            return "\(seconds) \(secondText)"
        }
    }

    /// Format as "HH:MM:SS" for timer display
    var timerFormatted: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Format as percentage of a goal
    func percentageOf(_ goal: TimeInterval) -> String {
        guard goal > 0 else { return "0%" }
        let percentage = (self / goal) * 100
        return String(format: "%.0f%%", min(percentage, 999))
    }
}
