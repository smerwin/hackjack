/// The universal tell for a corrupted or hacked card (§5.2). `.visible` for
/// anything already on the table; `.hidden` for a dealer hack landing on a
/// card still in the shoe or face-down. Rendering must read this field
/// directly rather than re-deriving "is this hacked" from other state.
public enum SparkTell: Sendable {
    case visible
    case hidden
}

public enum MutationType: CaseIterable, Sendable {
    case volatileValue
    case overload
    case leech
    case twinner
}

extension MutationType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .volatileValue: return "Volatile Value"
        case .overload: return "Overload"
        case .leech: return "Leech"
        case .twinner: return "Twinner"
        }
    }
}
