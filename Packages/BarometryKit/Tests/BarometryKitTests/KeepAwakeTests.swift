import Foundation
import IOKit.pwr_mgt
import Testing
@testable import BarometryKit

@MainActor
struct KeepAwakeTests {
    /// Names of the assertions this process holds of `KeepAwake`'s type, as macOS reports them.
    private func heldAssertionNames() -> [String] {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let processes = byProcess?.takeRetainedValue() as? [Int: [[String: Any]]]
        else { return [] }
        return (processes[Int(ProcessInfo.processInfo.processIdentifier)] ?? [])
            .filter { $0[kIOPMAssertionTypeKey] as? String == KeepAwake.assertionType }
            .compactMap { $0[kIOPMAssertionNameKey] as? String }
    }

    @Test func holdsDisplayAssertionOnlyWhileEnabled() {
        let keepAwake = KeepAwake()
        #expect(!heldAssertionNames().contains(KeepAwake.assertionName))

        keepAwake.toggle()
        #expect(keepAwake.isEnabled)
        #expect(heldAssertionNames().filter { $0 == KeepAwake.assertionName }.count == 1)

        // Enabling again must not stack a second assertion.
        keepAwake.setEnabled(true)
        #expect(heldAssertionNames().filter { $0 == KeepAwake.assertionName }.count == 1)

        keepAwake.toggle()
        #expect(!keepAwake.isEnabled)
        #expect(!heldAssertionNames().contains(KeepAwake.assertionName))
    }
}
