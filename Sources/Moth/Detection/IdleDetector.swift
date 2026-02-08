import IOKit

struct IdleDetector {
    static func idleTimeSeconds() -> Double {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iterator
        ) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var unmanagedDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            entry, &unmanagedDict, kCFAllocatorDefault, 0
        ) == KERN_SUCCESS,
              let dict = unmanagedDict?.takeRetainedValue() as? [String: Any],
              let idleTime = dict["HIDIdleTime"] as? Int64
        else {
            return 0
        }

        // HIDIdleTime is in nanoseconds
        return Double(idleTime) / 1_000_000_000.0
    }
}
