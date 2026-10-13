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

    /// Mounted local volumes other than the startup disk, such as external drives.
    static func otherVolumes() -> [DiskSample] {
        let keys: [URLResourceKey] = [.volumeIsLocalKey, .volumeIsRootFileSystemKey, .volumeIsBrowsableKey]
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return volumes.compactMap { volume in
            guard let values = try? volume.resourceValues(forKeys: Set(keys)),
                  values.volumeIsLocal == true,
                  values.volumeIsRootFileSystem != true,
                  values.volumeIsBrowsable != false
            else { return nil }
            return try? sample(volume: volume)
        }
    }
}
