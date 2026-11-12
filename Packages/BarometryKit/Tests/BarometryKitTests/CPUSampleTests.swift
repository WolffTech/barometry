// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Testing
@testable import BarometryKit

struct CPUSampleTests {
    @Test func splitsLoadIntoUserAndSystem() throws {
        let old = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0)]
        let new = [CPUTicks(user: 160, system: 70, idle: 870, nice: 0)]

        let sample = try #require(CPUSample(from: old, to: new, kinds: [.performance]))

        #expect(sample.total.user == Percent(0.6))
        #expect(sample.total.system == Percent(0.2))
        #expect(sample.total.total == Percent(0.8))
    }

    @Test func countsNiceTimeAsUser() throws {
        let old = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        let new = [CPUTicks(user: 10, system: 0, idle: 80, nice: 10)]

        let sample = try #require(CPUSample(from: old, to: new, kinds: [.performance]))

        #expect(sample.total.user == Percent(0.2))
    }

    @Test func handlesCounterWraparound() throws {
        let old = [CPUTicks(user: .max - 9, system: 0, idle: .max - 49, nice: 0)]
        let new = [CPUTicks(user: 40, system: 0, idle: 50, nice: 0)]

        let sample = try #require(CPUSample(from: old, to: new, kinds: [.performance]))

        // 50 user ticks and 100 idle ticks across the wrap.
        #expect(abs(sample.total.user.fraction - 50.0 / 150.0) < 1e-9)
    }

    @Test func weightsTotalByTicksAcrossCores() throws {
        let old = Array(repeating: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), count: 2)
        let new = [
            CPUTicks(user: 100, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 0, system: 0, idle: 100, nice: 0),
        ]

        let sample = try #require(CPUSample(from: old, to: new, kinds: [.efficiency, .performance]))

        #expect(sample.total.total == Percent(0.5))
        #expect(sample.cores.map(\.load.total) == [Percent(1), Percent(0)])
    }

    @Test func averagesEachCoreKind() throws {
        let old = Array(repeating: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), count: 3)
        let new = [
            CPUTicks(user: 50, system: 0, idle: 50, nice: 0),
            CPUTicks(user: 100, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 10, system: 0, idle: 90, nice: 0),
        ]

        let sample = try #require(CPUSample(from: old, to: new, kinds: [.efficiency, .efficiency, .performance]))

        #expect(sample.averageLoad(of: .efficiency) == Percent(0.75))
        #expect(sample.averageLoad(of: .performance) == Percent(0.1))
    }

    @Test func treatsUnmappedCoresAsPerformance() throws {
        let old = Array(repeating: CPUTicks(user: 0, system: 0, idle: 0, nice: 0), count: 2)
        let new = Array(repeating: CPUTicks(user: 1, system: 0, idle: 1, nice: 0), count: 2)

        let sample = try #require(CPUSample(from: old, to: new, kinds: [.efficiency]))

        #expect(sample.cores.map(\.kind) == [.efficiency, .performance])
    }

    @Test func rejectsChangedCoreCount() {
        let old = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        let new = Array(repeating: CPUTicks(user: 1, system: 0, idle: 1, nice: 0), count: 2)

        #expect(CPUSample(from: old, to: new, kinds: []) == nil)
    }

    @Test func reportsIdleWhenNoTicksElapsed() throws {
        let ticks = [CPUTicks(user: 5, system: 5, idle: 5, nice: 0)]

        let sample = try #require(CPUSample(from: ticks, to: ticks, kinds: [.performance]))

        #expect(sample.total == .idle)
    }

    @Test func perflevelTopologyListsSlowestCoresFirst() {
        let topology = CoreTopology(levels: [
            .init(kind: .super, logicalCPUs: 2),
            .init(kind: .performance, logicalCPUs: 3),
        ])

        #expect(topology.kinds == [.performance, .performance, .performance, .super, .super])
    }

    @Test func m4ClusterTypesMapToEfficiencyAndPerformance() throws {
        let topology = try #require(CoreTopology(
            cpus: [cpu(0, cluster: 0, "E"), cpu(1, cluster: 1, "P")],
            levels: [.init(kind: .performance, logicalCPUs: 1), .init(kind: .efficiency, logicalCPUs: 1)]
        ))

        #expect(topology.kinds == [.efficiency, .performance])
    }

    @Test func m5MaxClusterTypesMapToPerformanceAndSuper() throws {
        let topology = try #require(CoreTopology(
            cpus: [cpu(0, cluster: 0, "M"), cpu(1, cluster: 1, "M"), cpu(2, cluster: 2, "P")],
            levels: [.init(kind: .super, logicalCPUs: 1), .init(kind: .performance, logicalCPUs: 2)]
        ))

        #expect(topology.kinds == [.performance, .performance, .super])
        #expect(topology.clusters == [
            .init(id: 0, type: "M", kind: .performance),
            .init(id: 1, type: "M", kind: .performance),
            .init(id: 2, type: "P", kind: .super),
        ])
    }

    @Test func baseM5ClusterTypesMapToEfficiencyAndSuper() throws {
        let topology = try #require(CoreTopology(
            cpus: [cpu(0, cluster: 0, "E"), cpu(1, cluster: 1, "P")],
            levels: [.init(kind: .super, logicalCPUs: 1), .init(kind: .efficiency, logicalCPUs: 1)]
        ))

        #expect(topology.kinds == [.efficiency, .super])
    }

    @Test func clusterTypesFollowLogicalNumberingAcrossDies() throws {
        let topology = try #require(CoreTopology(
            cpus: [cpu(0, cluster: 0, "E"), cpu(1, cluster: 1, "P"), cpu(2, cluster: 2, "E"), cpu(3, cluster: 3, "P")],
            levels: [.init(kind: .performance, logicalCPUs: 2), .init(kind: .efficiency, logicalCPUs: 2)]
        ))

        #expect(topology.kinds == [.efficiency, .performance, .efficiency, .performance])
    }

    @Test func clusterTypesThatDisagreeWithPerflevelsAreRejected() {
        let topology = CoreTopology(
            cpus: [cpu(0, cluster: 0, "E"), cpu(1, cluster: 1, "P")],
            levels: [.init(kind: .performance, logicalCPUs: 2)]
        )

        #expect(topology == nil)
    }

    @Test func classifiesPerflevelNames() {
        #expect(CoreKind(perflevelName: "Efficiency") == .efficiency)
        #expect(CoreKind(perflevelName: "Performance") == .performance)
        #expect(CoreKind(perflevelName: "Super") == .super)
        #expect(CoreKind(perflevelName: "Turbo") == nil)
    }

    private func cpu(_ id: Int, cluster: Int, _ type: Character) -> CoreTopology.CPUNode {
        CoreTopology.CPUNode(logicalID: id, clusterID: cluster, clusterType: type)
    }
}
