import Foundation
import SwiftUI

enum ActivityCategory: String, CaseIterable, Identifiable {
    case youtube = "youtube"
    case youtubeShorts = "youtube_shorts"
    case working = "working"
    case idle = "idle"

    var id: String { rawValue }

    /// Whether this category counts as YouTube watching (for budget/reminders)
    var isYouTube: Bool {
        self == .youtube || self == .youtubeShorts
    }

    var label: String {
        switch self {
        case .youtube: return "YouTube"
        case .youtubeShorts: return "Shorts"
        case .working: return "Working"
        case .idle: return "Idle"
        }
    }

    var colorHex: String {
        switch self {
        case .youtube: return "#FF0000"
        case .youtubeShorts: return "#FF6600"
        case .working: return "#4CAF50"
        case .idle: return "#9E9E9E"
        }
    }

    var color: Color {
        switch self {
        case .youtube: return Color(red: 1.0, green: 0.0, blue: 0.0)
        case .youtubeShorts: return Color(red: 1.0, green: 0.4, blue: 0.0)
        case .working: return Color(red: 0.30, green: 0.69, blue: 0.31)
        case .idle: return Color(red: 0.62, green: 0.62, blue: 0.62)
        }
    }
}
