import SwiftUI
import HackjackCore

/// Presentation-only metadata for the hack tools menu — deliberately kept
/// in the App layer, not HackjackCore, since names/icons/copy are a
/// rendering concern (§3). Exists specifically to answer "what does this
/// button do," which nothing in the UI explained before this.
extension PlayerHackType {
    var displayName: String {
        switch self {
        case .jack: return "JACK"
        case .spoof: return "SPOOF"
        case .crash: return "CRASH"
        case .patch: return "PATCH"
        case .peek: return "PEEK"
        }
    }

    var symbolName: String {
        switch self {
        case .jack: return "arrow.up.arrow.down"
        case .spoof: return "arrow.left.arrow.right"
        case .crash: return "bolt.trianglebadge.exclamationmark"
        case .patch: return "bandage"
        case .peek: return "eye"
        }
    }

    /// One line, fits a menu row.
    var menuSubtitle: String {
        switch self {
        case .jack: return "shift a card's rank ±1-3"
        case .spoof: return "swap a card's suit"
        case .crash: return "reroll a card completely"
        case .patch: return "immunize a card this hand"
        case .peek: return "reveal the dealer's hole card"
        }
    }

    /// Longer form, shown in the armed-hack hint banner once selected.
    var fullDescription: String {
        switch self {
        case .jack: return "Shifts the target card's rank up or down by 1-3."
        case .spoof: return "Changes the target card's suit only — no value change."
        case .crash: return "Fully rerolls the target card into a new rank and suit."
        case .patch: return "Immunizes one of your own cards from corruption for the rest of this hand."
        case .peek: return "Reveals the dealer's hidden card for a moment. Fires immediately — no target needed."
        }
    }

    var needsTarget: Bool { self != .peek }
}
