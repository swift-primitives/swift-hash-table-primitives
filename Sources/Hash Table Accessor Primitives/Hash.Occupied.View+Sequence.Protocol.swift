// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Sequence_Primitives_Core

// MARK: - Sequence.Protocol

extension Hash.Occupied.View: Sequence.`Protocol` {}

// MARK: - Swift.Sequence

extension Hash.Occupied.View: Swift.Sequence {
    /// Disambiguates `underestimatedCount` between the default provided by
    /// `Sequence.Protocol where Self: Copyable` and `Swift.Sequence`.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: _count) }
}
