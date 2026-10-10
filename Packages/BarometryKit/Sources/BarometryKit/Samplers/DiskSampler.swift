import Foundation

enum DiskSampler {
    static func sample(volume: URL = URL(filePath: "/")) throws -> DiskSample {
        let values = try volume.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        return DiskSample(
            name: values.volumeName ?? volume.lastPathComponent,
            total: ByteCount(bytes: Int64(values.volumeTotalCapacity ?? 0)),
            available: ByteCount(bytes: values.volumeAvailableCapacityForImportantUsage ?? 0)
        )
    }
}
