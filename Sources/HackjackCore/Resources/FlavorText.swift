/// Centralized narrative copy (§9). Every call site picks a random line
/// from the relevant pool rather than a single fixed string — one canned
/// line per event read flat on repeat across a run; a pool keeps the same
/// beat from reading identical hand after hand.
public enum FlavorText {
    public static let loadingScreen: [String] = [
        "Compiling shoe... 52 packets found. Integrity: unverified.",
        "The house doesn't cheat. The house just has root access.",
        "Every card was a zero once. Some remember.",
        "You're not beating the dealer. You're beating dial-up.",
    ]

    public static func hackConfirm<G: RandomNumberGenerator>(_ type: PlayerHackType, using rng: inout G) -> String {
        let pool: [String]
        switch type {
        case .jack:
            pool = [
                "Value spoofed. Nobody downstream will notice. Probably.",
                "Rewrote the value in transit. The card won't remember this.",
                "One digit, shifted quietly. Nobody audits this layer.",
            ]
        case .spoof:
            pool = [
                "Suit reassigned at the socket. Nothing upstream complained.",
                "Wrong flag, right card. Close enough for the house's parser.",
                "Header rewritten mid-flight. The suit never knew.",
            ]
        case .crash:
            pool = [
                "Segfault induced. Card core dumped and reborn.",
                "Forced a crash. What comes back never remembers what it was.",
                "Fatal exception, caught and rethrown as something new.",
            ]
        case .patch:
            pool = [
                "Firewall up. For now.",
                "Patched. It'll hold — until something bigger tries the door.",
                "Integrity restored. Don't get used to it.",
            ]
        case .peek:
            pool = [
                "One frame. That's all root gets you.",
                "A glimpse through the hole card. Gone before it registers.",
                "Borrowed a frame of the house's buffer. Frame's over.",
            ]
        }
        return pool.randomElement(using: &rng)!
    }

    public static func dealerHackVisible<G: RandomNumberGenerator>(using rng: inout G) -> String {
        let pool = [
            "Found a way in. Rude of you to leave it open.",
            "Somebody left a port open. Not anymore.",
            "The house just walked right through your firewall.",
            "That was yours a second ago.",
        ]
        return pool.randomElement(using: &rng)!
    }

    public static func dealerHackHidden<G: RandomNumberGenerator>(using rng: inout G) -> String {
        let pool = [
            "A faint hum crawls at the edge of the screen. Something in the shoe just changed.",
            "A flicker, barely there. You'll find out what it cost you later.",
            "Static, low and brief. Whatever that was, it's already done.",
        ]
        return pool.randomElement(using: &rng)!
    }

    /// Leech drains integrity with no rank change, so it was the one
    /// mutation with zero visible output. Reports the drain directly
    /// instead of leaving the player staring at an unchanged card.
    public static func leechResolve<G: RandomNumberGenerator>(card: String, integrity: Int, using rng: inout G) -> String {
        let pool = [
            "Leech bites into \(card) — integrity down to \(integrity). Something on the table just got hungrier.",
            "Leech drains \(card) — integrity at \(integrity) and falling.",
            "Leech siphons \(card) dry — integrity \(integrity). It'll spread if you let it sit.",
        ]
        return pool.randomElement(using: &rng)!
    }

    public static func outcome<G: RandomNumberGenerator>(_ outcome: HandOutcome, using rng: inout G) -> String {
        let pool: [String]
        switch outcome {
        case .playerBlackjack:
            pool = [
                "21, unassisted. The old-fashioned kind of cheating: skill.",
                "Natural 21. Nothing sparked. Nothing needed to.",
            ]
        case .dealerBlackjack:
            pool = [
                "House hits 21 first. Root always wins ties it deals itself.",
                "Dealer's holding a natural. Some things don't need corrupting.",
            ]
        case .playerBust:
            pool = [
                "Overflow error. You know what that means here.",
                "Stack overflow. The house doesn't even have to try.",
                "Too many packets, not enough room. You know how this ends.",
            ]
        case .dealerBust:
            pool = [
                "The house overflowed. Doesn't happen twice, usually.",
                "Root just crashed its own process. Take the win.",
                "The dealer's node choked on its own hand. Rare. Take it.",
            ]
        case .playerWin:
            pool = [
                "You win the hand.",
                "Clean enough. The house logs it and moves on.",
                "Hand's yours. The dealer doesn't blink.",
            ]
        case .dealerWin:
            pool = [
                "The house wins the hand.",
                "Table holds. It usually does.",
                "Dealer takes it. No fanfare — the house doesn't need any.",
            ]
        case .push:
            pool = [
                "Push — nobody's integrity changes.",
                "Dead heat. Neither side's firmware budges.",
                "Push. The table stays exactly as compromised as before.",
            ]
        }
        return pool.randomElement(using: &rng)!
    }
}
