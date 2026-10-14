<!-- SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech> -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

# Obtaining corresponding source

Each official release on the [GitHub Releases](https://github.com/WolffTech/barometry/releases)
page is built from the `vX.Y.Z` tag of the same version in the
[Barometry repository](https://github.com/WolffTech/barometry). GitHub offers
the source at that tag as a zip or tarball on the release page. It contains
the Barometry source, the XcodeGen project spec, and the build and release
scripts used for that release. Xcode, XcodeGen, and Apple system frameworks
are standard build tools or system libraries and are not included. Private
signing credentials are not required for a local build.

The Sparkle update framework embedded in binary releases is a separate,
MIT-licensed work consumed as the prebuilt framework published by the Sparkle
project at the version pinned in `project.yml`; its source is available from
<https://github.com/sparkle-project/Sparkle> at the matching tag.

Anyone who redistributes a Barometry binary is responsible for satisfying
the source-distribution requirements in section 6 of GPLv3.
