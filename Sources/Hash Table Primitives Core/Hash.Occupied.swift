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

extension Hash {
    /// A single occupied bucket from a hash table scan.
    ///
    /// `Source` is the phantom type matching the external element storage.
    /// Named `Source` (not `Element`) to avoid collision with `Sequence.Protocol`'s
    /// `associatedtype Element` when conforming sequence views.
    @safe
    public struct Occupied<Source: ~Copyable>: Copyable, Sendable {
        /// The bucket index in the hash table.
        public let bucket: Hash.Table<Source>.Bucket.Index

        /// The post-normalization hash stored in this bucket.
        public let hash: Int

        /// The typed position in external storage.
        public let position: Index<Source>

        @inlinable
        package init(bucket: Hash.Table<Source>.Bucket.Index, hash: Int, position: Index<Source>) {
            self.bucket = bucket
            self.hash = hash
            self.position = position
        }
    }
}
