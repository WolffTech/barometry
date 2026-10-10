import Observation
import os

/// One reading from every sampler. A nil field means the reading wasn't available this tick.
struct Snapshot: Sendable {
    var cpu: CPUSample?
    var memory: MemorySample?
    var network: NetworkSample?
    var disk: DiskSample?
    var battery: BatterySample?
}

/// Owns the samplers and runs them off the main actor.
actor SamplingEngine {
    private let logger = Logger(subsystem: "tech.wolff.barometry", category: "Sampling")
    private var cpu = CPUSampler()
    private let memory = MemorySampler()
    private var network = NetworkSampler()

    func sample() -> Snapshot {
        Snapshot(
            cpu: attempt("CPU") { try cpu.sample() },
            memory: attempt("memory") { try memory.sample() },
            network: network.sample(),
            disk: attempt("disk") { try DiskSampler.sample() },
            battery: BatterySampler.sample()
        )
    }

    private func attempt<Sample>(_ name: String, _ read: () throws -> Sample?) -> Sample? {
        do {
            return try read()
        } catch {
            logger.error("Reading \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

/// Latest system readings and recent history, refreshed on a fixed interval.
@MainActor
@Observable
public final class SystemMonitor {
    public static let historyCapacity = 120

    public private(set) var cpu: CPUSample?
    public private(set) var memory: MemorySample?
    public private(set) var network: NetworkSample?
    public private(set) var disk: DiskSample?
    public private(set) var battery: BatterySample?

    public private(set) var cpuHistory = History<CPULoad>(capacity: historyCapacity)
    public private(set) var networkHistory = History<NetworkSample>(capacity: historyCapacity)

    /// Time between readings. Changing it while running takes a reading immediately.
    public var interval: Duration {
        didSet {
            guard interval != oldValue, loop != nil else { return }
            stop()
            start()
        }
    }

    @ObservationIgnored private let engine = SamplingEngine()
    @ObservationIgnored private var loop: Task<Void, Never>?

    public init(interval: Duration = .seconds(2)) {
        self.interval = interval
    }

    public func start() {
        guard loop == nil else { return }
        loop = Task {
            while !Task.isCancelled {
                let snapshot = await engine.sample()
                guard !Task.isCancelled else { return }
                apply(snapshot)
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    private func apply(_ snapshot: Snapshot) {
        cpu = snapshot.cpu
        memory = snapshot.memory
        network = snapshot.network
        disk = snapshot.disk
        battery = snapshot.battery

        if let cpu = snapshot.cpu {
            cpuHistory.append(cpu.total)
        }
        if let network = snapshot.network {
            networkHistory.append(network)
        }
    }
}
