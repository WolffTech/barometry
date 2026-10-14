// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only

import Darwin

/// A failed Mach or IOKit call.
public struct KernelError: Error, CustomStringConvertible {
    public let call: String
    public let code: kern_return_t

    public var description: String {
        "\(call) failed: \(String(cString: mach_error_string(code))) (\(code))"
    }
}
