/// SplitMix64-based deterministic RNG. Every engine and generation path
/// takes its randomness through a generic `RandomNumberGenerator`, and
/// tests/Daily Breach always supply one of these seeded — never
/// `SystemRandomNumberGenerator` — so a run is fully reproducible from its
/// seed (§5.10, §10).
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
