import Testing
@testable import BarometryKit

struct HistoryTests {
    @Test func keepsInsertionOrderBelowCapacity() {
        var history = History<Int>(capacity: 3)
        history.append(1)
        history.append(2)

        #expect(Array(history) == [1, 2])
        #expect(history.last == 2)
    }

    @Test func dropsOldestWhenFull() {
        var history = History<Int>(capacity: 3)
        for value in 1...5 {
            history.append(value)
        }

        #expect(Array(history) == [3, 4, 5])
        #expect(history.first == 3)
        #expect(history.last == 5)
    }

    @Test func singleSlotKeepsLatest() {
        var history = History<Int>(capacity: 1)
        history.append(1)
        history.append(2)

        #expect(Array(history) == [2])
    }

    @Test func startsEmpty() {
        let history = History<Int>(capacity: 4)

        #expect(history.isEmpty)
        #expect(history.last == nil)
    }
}
