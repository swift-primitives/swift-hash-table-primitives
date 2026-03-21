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

public import Hash_Table_Primitives_Core

// MARK: - Copy-on-Write Support

extension Hash.Table where Element: Copyable {
    /// Ensures the hash table's internal storage is uniquely owned.
    ///
    /// If storage is shared (e.g., after a value copy of a container that
    /// embeds this hash table), creates a fresh copy of the bucket array.
    /// Delegates to `Buffer.Slots.ensureUnique()` which performs a bulk
    /// memory copy of both metadata and payload arrays.
    ///
    /// - Returns: `true` if a copy was made, `false` if already unique.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        _buffer.ensureUnique()
    }
}
