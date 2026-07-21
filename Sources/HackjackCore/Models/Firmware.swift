import Foundation

/// A permanent, run-long effect (§5.6). Implemented as a fixed catalog of
/// concrete effects rather than an open-ended closure-based system — four
/// effects is enough to demonstrate "kept mutations shape the rest of the
/// run" without inventing a scripting layer this guide never asked for.
public enum FirmwareEffect: String, CaseIterable, Sendable {
    /// The first spark encountered each hand resolves as a free Patch
    /// instead of a real mutation.
    case guardDaemon
    /// Shoe generation is biased toward Aces after the normal build.
    case aceStorm
    /// When a pending pair contains Twinner or Volatile Value, resolution
    /// is biased toward that outcome instead of a 50/50 coin flip.
    case twinnerLoop
    /// Leech can never drain a card's integrity below 50.
    case leechWard

    public var displayName: String {
        switch self {
        case .guardDaemon: return "Guard Daemon"
        case .aceStorm: return "Ace Storm"
        case .twinnerLoop: return "Twinner Loop"
        case .leechWard: return "Leech Ward"
        }
    }

    public var flavorDescription: String {
        switch self {
        case .guardDaemon: return "The first spark each hand patches itself. Habit, at this point."
        case .aceStorm: return "The shoe leans toward aces now. Ask it why and it won't answer."
        case .twinnerLoop: return "Volatile sparks remember which way they fell last time."
        case .leechWard: return "Leech still bites. It just can't finish the job anymore."
        }
    }
}

public struct FirmwareMutation: Identifiable, Sendable {
    public let id: UUID
    public let effect: FirmwareEffect

    public init(effect: FirmwareEffect, id: UUID = UUID()) {
        self.id = id
        self.effect = effect
    }
}

public struct FirmwareSlots: Sendable {
    public var capacity: Int
    public var equipped: [FirmwareMutation]

    public init(capacity: Int = 3, equipped: [FirmwareMutation] = []) {
        self.capacity = capacity
        self.equipped = equipped
    }

    public var isFull: Bool { equipped.count >= capacity }
    public func has(_ effect: FirmwareEffect) -> Bool { equipped.contains { $0.effect == effect } }
}
