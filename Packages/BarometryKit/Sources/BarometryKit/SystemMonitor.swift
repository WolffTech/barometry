import Observation
import os

/// One reading from every sampler. A nil field means the reading wasn't available this tick.
struct Snapshot: Sendable {
    var cpu: CPUSample?
    var memory: MemorySample?
    var network: NetworkSample?
    var disk: DiskSample?
    var battery: BatterySample?
    var gpu: GPUSample?
    var sensors: SensorSample?
    var frequencies: FrequencySample?
}

/// Owns the samplers and runs them off the main actor.
actor SamplingEngine {
    private let logger = Logger(subsystem: "tech.wolff.barometry", category: "Sampling")
    // Lazy so setup work (CPU topology, SMC key discovery, IOReport subscription) runs on
    // the first sample, off the main actor, rather than when the monitor is created.
    private lazy var cpu = CPUSampler()
    private lazy var memory = MemorySampler()
    private lazy var network = NetworkSampler()
    private lazy var sensors = SensorsSampler()
    private lazy var frequencies = FrequencySampler()

    /// Free space changes slowly, and reading it costs more than every other sampler
    /// combined (macOS validates volumes over IPC), so it's refreshed less often.
    private static let diskRefreshInterval = Duration.seconds(60)
    private var disk: (sample: DiskSample, readAt: ContinuousClock.Instant)?

    func sample(networkInterface: String?) -> Snapshot {
        Snapshot(
            cpu: attempt("CPU") { try cpu.sample() },
            memory: attempt("memory") { try memory.sample() },
            network: network.sample(interface: networkInterface),
            disk: diskSample(),
            battery: BatterySampler.sample(),
            gpu: GPUSampler.sample(),
            sensors: sensors.sample(),
            frequencies: frequencies.sample()
        )
    }

    private func diskSample() -> DiskSample? {
        let now = ContinuousClock.now
        if let disk, now - disk.readAt < Self.diskRefreshInterval {
            return disk.sample
        }
        let sample = attempt("disk") { try DiskSampler.sample() }
        disk = sample.map { ($0, now) }
        return sample
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
    public private(set) var gpu: GPUSample?
    public private(set) var sensors: SensorSample?
    public private(set) var frequencies: FrequencySample?

    public private(set) var cpuHistory = History<CPULoad>(capacity: historyCapacity)
    public private(set) var networkHistory = History<NetworkSample>(capacity: historyCapacity)
    public private(set) var gpuHistory = History<Percent>(capacity: historyCapacity)

    /// Time between readings. Changing it while running takes a reading immediately.
    public var interval: Duration {
        didSet {
            guard interval != oldValue, loop != nil else { return }
            stop()
            start()
        }
    }

    /// BSD name of the interface to measure, or nil for the primary interface.
    @ObservationIgnored public var networkInterface: String?

    @ObservationIgnored private let engine = SamplingEngine()
    @ObservationIgnored private var loop: Task<Void, Never>?

    public init(interval: Duration = .seconds(2)) {
        self.interval = interval
    }

    public func start() {
        guard loop == nil else { return }
        loop = Task {
            while !Task.isCancelled {
                let snapshot = await engine.sample(networkInterface: networkInterface)
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
        gpu = snapshot.gpu
        sensors = snapshot.sensors
        frequencies = snapshot.frequencies

        if let cpu = snapshot.cpu {
            cpuHistory.append(cpu.total)
        }
        if let network = snapshot.network {
            networkHistory.append(network)
        }
        if let gpu = snapshot.gpu {
            gpuHistory.append(gpu.utilization)
        }
    }
}
