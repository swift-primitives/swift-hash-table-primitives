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

extension Hash.Table where Element: ~Copyable {
    /// Bucket capacity derived from the buffer.
    @inlinable
    package var bucketCapacity: Index<Bucket>.Count {
        _buffer.capacity.retag(Bucket.self)
    }

    /// Hash value at a bucket.
    @inlinable
    package subscript(hash bucket: Bucket.Index) -> Int {
        get { _buffer[metadata: bucket.retag(Int.self)] }
        set { _buffer[metadata: bucket.retag(Int.self)] = newValue }
    }

    /// Element position at a bucket.
    @inlinable
    package subscript(position bucket: Bucket.Index) -> Index<Element> {
        get {
            let raw = _buffer[payload: bucket.retag(Int.self)]
            return Index<Element>(__unchecked: (), Ordinal(UInt(bitPattern: raw)))
        }
        set {
            _buffer[payload: bucket.retag(Int.self)] = Int(bitPattern: newValue)
        }
    }
}
