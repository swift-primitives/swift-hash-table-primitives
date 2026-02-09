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
    /// Uses O(capacity) bulk memcpy for metadata — much faster than
    /// rehashing every entry.
    ///
    /// - Returns: `true` if a copy was made, `false` if already unique.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        if !_buffer.isStorageUnique() {
            let cap = bucketCapacity
            let capInt = Int(bitPattern: cap)
            var newBuffer = Buffer<Int>.Slots<Int>(
                capacity: cap.retag(Int.self),
                metadataInitial: Self.empty
            )
            // Bulk-copy metadata (hash values) via pointer
            unsafe newBuffer.withMutableMetadataPointer { dst in
                unsafe _buffer.withMetadataPointer { src in
                    unsafe dst.update(from: src, count: capInt)
                }
            }
            // Copy payload (element positions) via subscript
            var slot: Index<Int> = .zero
            let end = cap.map(Ordinal.init).retag(Int.self)
            while slot < end {
                newBuffer[payload: slot] = _buffer[payload: slot]
                slot += .one
            }
            _buffer = newBuffer
            return true
        }
        return false
    }
}
