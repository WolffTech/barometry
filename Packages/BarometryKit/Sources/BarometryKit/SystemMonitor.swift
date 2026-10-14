// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Observation
import os

/// One reading from every sampler. A nil field means the reading wasn't available this tick.
struct Snapshot: Sendable {
    var cpu: CPUSample?
    var memory: MemorySample?
    var network: NetworkSample?
    var disk: DiskSample?
    var otherVolumes: [DiskSample] = []
    var diskActivity: DiskActivity?
    var battery: BatterySample?
    var gpu: GPUSample?
    var sensors: SensorSample?
    var frequencies: FrequencySample?
    var processes: TopProcesses?
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
    private lazy var diskActivity = DiskActivitySampler()
    private lazy var processes = ProcessSampler()

    /// Free space and battery health change slowly, and reading free space costs more than
    /// every other sampler combined (macOS validates volumes over IPC), so they're refreshed less often.
    private static let slowRefreshInterval = Duration.seconds(60)
    private var slow: (readings: SlowReadings, readAt: ContinuousClock.Instant)?

    private struct SlowReadings {
        let disk: DiskSample?
        let otherVolumes: [DiskSample]
        let batteryHealth: BatteryHealth?
    }

    func sample(networkInterface: String?, includingProcesses: Bool) -> Snapshot {
        let slow = slowReadings()
        var battery = BatterySampler.sample()
        battery?.health = slow.batteryHealth
        return Snapshot(
            cpu: attempt("CPU") { try cpu.sample() },
            memory: attempt("memory") { try memory.sample() },
            network: network.sample(interface: networkInterface),
            disk: slow.disk,
            otherVolumes: slow.otherVolumes,
            diskActivity: diskActivity.sample(),
            battery: battery,
            gpu: GPUSampler.sample(),
            sensors: sensors.sample(),
            frequencies: frequencies.sample(),
            processes: includingProcesses ? sampleProcesses() : stopSamplingProcesses()
        )
    }

    func sampleProcesses() -> TopProcesses? {
        processes.sample()
    }

    /// Forgets the last reading, so usage restarts cleanly rather than averaging over the gap.
    private func stopSamplingProcesses() -> TopProcesses? {
        processes.reset()
        return nil
    }

    private func slowReadings() -> SlowReadings {
        let now = ContinuousClock.now
        if let slow, now - slow.readAt < Self.slowRefreshInterval {
            return slow.readings
        }
        let readings = SlowReadings(
            disk: attempt("disk") { try DiskSampler.sample() },
            otherVolumes: DiskSampler.otherVolumes(),
            batteryHealth: BatterySampler.health()
        )
        slow = (readings, now)
        return readings
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
    /// Mounted local volumes other than the startup disk.
    public private(set) var otherVolumes: [DiskSample] = []
    public private(set) var diskActivity: DiskActivity?
    public private(set) var battery: BatterySample?
    public private(set) var gpu: GPUSample?
    public private(set) var sensors: SensorSample?
    public private(set) var frequencies: FrequencySample?
    /// Nil unless `samplesProcesses` is on, and for the first reading after it turns on.
    public private(set) var processes: TopProcesses?

    public private(set) var cpuHistory = History<CPULoad>(capacity: historyCapacity)
    public private(set) var networkHistory = History<NetworkSample>(capacity: historyCapacity)
    public private(set) var gpuHistory = History<Percent>(capacity: historyCapacity)
    public private(set) var memoryHistory = History<Percent>(capacity: historyCapacity)
    public private(set) var powerHistory = History<Power>(capacity: historyCapacity)
    public private(set) var diskActivityHistory = History<DiskActivity>(capacity: historyCapacity)

    /// Time between readings. Changing it while running takes a reading immediately.
    public var interval: Duration {
        didSet {
            guard interval != oldValue, loop != nil else { return }
            stop()
            start()
        }
    }

    /// Whether to rank processes, which costs a few milliseconds per reading. Turning it on
    /// takes a first reading immediately, so usage is ready by the next tick.
    public var samplesProcesses = false {
        didSet {
            guard samplesProcesses != oldValue else { return }
            guard samplesProcesses, loop != nil else {
                processes = nil
                return
            }
            Task {
                let processes = await engine.sampleProcesses()
                if samplesProcesses, processes != nil {
                    self.processes = processes
                }
            }
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
                let snapshot = await engine.sample(networkInterface: networkInterface, includingProcesses: samplesProcesses)
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
        otherVolumes = snapshot.otherVolumes
        diskActivity = snapshot.diskActivity
        battery = snapshot.battery
        gpu = snapshot.gpu
        sensors = snapshot.sensors
        frequencies = snapshot.frequencies
        // A tick that started before sampling turned off still carries processes.
        processes = samplesProcesses ? snapshot.processes : nil

        if let cpu = snapshot.cpu {
            cpuHistory.append(cpu.total)
        }
        if let network = snapshot.network {
            networkHistory.append(network)
        }
        if let gpu = snapshot.gpu {
            gpuHistory.append(gpu.utilization)
        }
        if let memory = snapshot.memory {
            memoryHistory.append(memory.usage)
        }
        if let power = snapshot.sensors?.systemPower {
            powerHistory.append(power)
        }
        if let activity = snapshot.diskActivity {
            diskActivityHistory.append(activity)
        }
    }
}
