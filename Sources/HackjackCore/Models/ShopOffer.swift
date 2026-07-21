/// A single Patch Shop line item (§5.7). `apply` is the only place outside
/// GameEngine that's allowed to mutate RunState — everything else routes
/// through GameEngine's own methods.
public struct ShopOffer: Identifiable, Sendable {
    public let id: ShopOfferKind
    public let title: String
    public let description: String
    public let cost: Int

    public init(id: ShopOfferKind, title: String, description: String, cost: Int) {
        self.id = id
        self.title = title
        self.description = description
        self.cost = cost
    }
}

public enum ShopOfferKind: Sendable, Hashable {
    case extraCharge
    case favorableMutationToken
    case removeCorruptionType
    case extraFirmwareSlot
    case reroll
}
