public enum PlayerHackType: String, CaseIterable, Sendable {
    case jack, spoof, crash, patch, peek
}

/// Dealer's mirrored, offense-only kit — no Patch (defense) or Peek
/// (information) equivalent, per §5.4.
public enum DealerHackType: String, CaseIterable, Sendable {
    case jack, spoof, crash
}

public struct HackChargePool: Sendable {
    public var current: Int
    public var max: Int

    public init(current: Int, max: Int) {
        self.current = current
        self.max = max
    }

    @discardableResult
    public mutating func spend(_ amount: Int) -> Bool {
        guard current >= amount else { return false }
        current -= amount
        return true
    }
}
