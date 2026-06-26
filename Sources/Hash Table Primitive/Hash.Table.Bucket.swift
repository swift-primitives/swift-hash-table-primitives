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

public import Hash_Primitives
public import Index_Primitives

extension Hash.Table where Element: ~Copyable {
    /// Marker type for bucket indices in hash table storage.
    public struct Bucket: ~Copyable {
        /// Typed index into the bucket array.
        public typealias Index = Index_Primitives.Index<Self>

        /// Tag type for bucket operations.
        public enum Ops {}
    }
}
