/// Fixed-capacity buffer of recent samples, ordered oldest to newest.
/// Appending to a full buffer drops the oldest sample.
public struct History<Element> {
    public let capacity: Int
    private var storage: [Element] = []
    /// Index of the oldest sample once the buffer has wrapped.
    private var head = 0

    public init(capacity: Int) {
        precondition(capacity > 0, "History capacity must be positive")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    public mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }
}

extension History: RandomAccessCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { storage.count }

    public subscript(position: Int) -> Element {
        precondition(indices.contains(position), "History index out of range")
        return storage[(head + position) % storage.count]
    }
}

extension History: Sendable where Element: Sendable {}
extension History: Equatable where Element: Equatable {}
